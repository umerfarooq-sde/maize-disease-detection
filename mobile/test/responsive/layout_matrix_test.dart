import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/core/theme/app_theme.dart';
import 'package:maizedoctor/core/utils/responsive.dart';
import 'package:maizedoctor/core/widgets/app_page.dart';
import 'package:maizedoctor/core/widgets/feature_card.dart';
import 'package:maizedoctor/core/widgets/horizontal_data_scroll.dart';
import 'package:maizedoctor/data/models/analytics_period.dart';
import 'package:maizedoctor/features/analytics/widgets/analytics_charts.dart';

Future<void> setViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}

Widget host(Widget child, {double scale = 1}) => MaterialApp(
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Scaffold(body: child),
  ),
);

void main() {
  test('responsive page margins respect available width', () {
    expect(Responsive.paddingForWidth(320), 12);
    expect(Responsive.paddingForWidth(360), 16);
    expect(Responsive.paddingForWidth(480), 16);
    expect(Responsive.paddingForWidth(768), 24);
    expect(Responsive.paddingForWidth(1280), 32);
  });

  for (final width in [320.0, 360.0, 480.0, 768.0, 840.0, 1280.0]) {
    testWidgets('page scroll surface at ${width.toInt()}dp', (tester) async {
      await setViewport(tester, Size(width, 800));
      await tester.pumpWidget(
        host(
          AppPage(
            child: SizedBox(
              key: const Key('page-payload'),
              height: 64,
              child: Text('Full-width content at $width'),
            ),
          ),
        ),
      );
      await tester.pump();
      final actual = tester.getSize(find.byKey(const Key('page-payload')));
      final expected = (width - 2 * Responsive.paddingForWidth(width))
          .clamp(0.0, 1120.0)
          .toDouble();
      expect(actual.width, closeTo(expected, 0.1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('two-column layout uses pane width, not window width', (
    tester,
  ) async {
    await setViewport(tester, const Size(1280, 900));
    final first = find.byKey(const Key('first'));
    final second = find.byKey(const Key('second'));
    Widget pair(double width, double scale) => host(
      Center(
        child: SizedBox(
          width: width,
          child: ResponsivePair(
            first: const SizedBox(key: Key('first'), height: 64),
            second: const SizedBox(key: Key('second'), height: 64),
          ),
        ),
      ),
      scale: scale,
    );
    await tester.pumpWidget(pair(440, 1));
    expect(
      tester.getTopLeft(second).dy,
      greaterThan(tester.getTopLeft(first).dy),
    );
    await tester.pumpWidget(pair(800, 1));
    expect(tester.getTopLeft(second).dy, tester.getTopLeft(first).dy);
    await tester.pumpWidget(pair(800, 2));
    expect(
      tester.getTopLeft(second).dy,
      greaterThan(tester.getTopLeft(first).dy),
    );
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('feature card remains readable at 320dp with ${scale}x text', (
      tester,
    ) async {
      await setViewport(tester, const Size(320, 740));
      var taps = 0;
      await tester.pumpWidget(
        host(
          AppPage(
            child: FeatureCard(
              title: 'Northern Corn Leaf Blight',
              description:
                  'Information and guidance for identifying possible maize leaf conditions without declaring a certain diagnosis.',
              icon: Icons.grass_outlined,
              onTap: () => taps++,
            ),
          ),
          scale: scale,
        ),
      );
      expect(find.text('Northern Corn Leaf Blight'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(FeatureCard));
      expect(taps, 1);
    });
  }

  testWidgets('wide data table is scrollable without viewport overflow', (
    tester,
  ) async {
    await setViewport(tester, const Size(320, 640));
    await tester.pumpWidget(
      host(
        AppPage(
          child: HorizontalDataScroll(
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Class')),
                DataColumn(label: Text('Precision')),
                DataColumn(label: Text('Recall')),
                DataColumn(label: Text('F1')),
                DataColumn(label: Text('Specificity')),
              ],
              rows: const [
                DataRow(
                  cells: [
                    DataCell(Text('Northern corn leaf blight')),
                    DataCell(Text('0.10')),
                    DataCell(Text('0.20')),
                    DataCell(Text('0.30')),
                    DataCell(Text('0.40')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(-420, 0),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('six activity bars remain scrollable with doubled text', (
    tester,
  ) async {
    await setViewport(tester, const Size(320, 740));
    final periods = [
      for (var i = 1; i <= 6; i++)
        AnalyticsPeriod(
          DateTime.utc(2026, 10, i),
          DateTime.utc(2026, 10, i),
          i,
        ),
    ];
    await tester.pumpWidget(
      host(AppPage(child: ScanActivityChart(periods: periods)), scale: 2),
    );
    expect(find.text('Scans over time'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byType(SingleChildScrollView).last);
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
