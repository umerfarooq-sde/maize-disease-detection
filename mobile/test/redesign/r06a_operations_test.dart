import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:maizedoctor/core/theme/app_theme.dart';
import 'package:maizedoctor/core/widgets/app_cards.dart';
import 'package:maizedoctor/data/models/ai_operations.dart';
import 'package:maizedoctor/features/admin/view_models/admin_dashboard_view_model.dart';
import 'package:maizedoctor/features/admin/views/ai_operations_view.dart';
import 'package:maizedoctor/features/admin/widgets/ai_operations_panel.dart';
import 'package:maizedoctor/features/admin/widgets/ai_operation_chart.dart';
import 'package:maizedoctor/features/admin/widgets/admin_metric_grid.dart';
import '../support/design_fonts.dart';
import 'r06a_fixtures.dart';

void main() {
  setUpAll(loadDesignFonts);
  testWidgets(
    'preview and Operations reuse one report, preserve filter and issue only explicit refreshes',
    (tester) async {
      final fixture = R06Fixture();
      await fixture.mount(tester);
      expect(
        fixture.requests.where((r) => r.url.path.endsWith('/dashboard')).length,
        1,
      );
      await r06Tap(tester, find.byKey(const Key('view-ai-operations')));
      final model = tester
          .element(find.byType(AiOperationsView))
          .read<AdminDashboardViewModel>();
      expect(model.data!.operations!.rows.first.requests, 8);
      expect(
        fixture.requests
            .where((r) => r.url.path.endsWith('/ai-operations'))
            .length,
        1,
      );
      await r06Tap(tester, find.widgetWithText(ChoiceChip, '7 days'));
      expect(model.range.days, 7);
      expect(
        fixture.requests
            .where((r) => r.url.path.endsWith('/ai-operations'))
            .length,
        2,
      );
      await fixture.go(tester, '/admin');
      expect(find.widgetWithText(ChoiceChip, '7 days'), findsOneWidget);
      expect(
        fixture.requests.where((r) => r.url.path.endsWith('/dashboard')).length,
        2,
      );
      await fixture.go(tester, '/admin/ai-operations');
      await r06Tap(tester, find.byTooltip('Refresh AI Operations'));
      expect(
        fixture.requests
            .where((r) => r.url.path.endsWith('/ai-operations'))
            .length,
        3,
      );
      expect(
        fixture.requests
            .where((r) => r.url.path.contains('/admin/'))
            .every((r) => r.method == 'GET'),
        isTrue,
      );
      expect(
        fixture.requests
            .where((r) => r.url.path.contains('/admin/'))
            .every(
              (r) => r.url.queryParameters.keys.every(['from', 'to'].contains),
            ),
        isTrue,
      );
    },
  );

  testWidgets(
    'scopes, abstention, latency and best-effort collection are kept separate',
    (tester) async {
      final fixture = R06Fixture();
      await fixture.mount(tester, location: '/admin/ai-operations');
      expect(find.text('NODE · INFERENCE'), findsOneWidget);
      expect(
        find.text('8 attempts · 6 successful · 2 failed · 0 abstained'),
        findsOneWidget,
      );
      expect(find.text('Failure rate: 25.0%'), findsNWidgets(2));
      expect(find.text('Mean 125.5 ms'), findsNWidgets(4));
      expect(find.text('p50 100.0 ms · p95 250.3 ms'), findsNWidgets(4));
      expect(find.textContaining('not persisted counts'), findsOneWidget);
      expect(find.textContaining('dropped 2 telemetry events'), findsOneWidget);
      await r06Tap(tester, find.text('Provider calls'));
      expect(find.text('PROVIDER · GEMINI'), findsOneWidget);
      expect(find.text('PROVIDER · EMBEDDING'), findsOneWidget);
      expect(
        find.text('4 attempts · 3 successful · 1 failed · 0 abstained'),
        findsWidgets,
      );
      expect(find.text('Unique requests'), findsNothing);
      expect(find.textContaining('accuracy: '), findsNothing);
    },
  );

  for (final malformed in [false, true]) {
    testWidgets(
      'unavailable operations do not erase valid dashboard counts or fabricate zeros (malformed=$malformed)',
      (tester) async {
        final fixture = R06Fixture()..operationsUnavailable = true;
        if (malformed) {
          fixture.malformedOperations = {
            'status': 'COLLECTED',
            'totals': 'broken',
          };
        }
        await fixture.mount(tester);
        final cards = tester
            .widgetList<AdminMetricCard>(find.byType(AdminMetricCard))
            .toList();
        expect(
          cards.singleWhere((card) => card.label == 'Registered farmers').value,
          '3',
        );
        expect(
          cards.singleWhere((card) => card.label == 'Saved scans').value,
          '8',
        );
        expect(
          find.textContaining('unknown counts are not zero'),
          findsOneWidget,
        );
        await fixture.go(tester, '/admin/ai-operations');
        expect(find.byType(AiOperationChart), findsNothing);
        expect(find.text('0 attempts'), findsNothing);
        fixture.operationsUnavailable = false;
        fixture.malformedOperations = null;
        await r06Tap(tester, find.byTooltip('Refresh AI Operations'));
        expect(find.text('NODE · INFERENCE'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'actual empty report is distinct from unavailable data and preserves true zero metrics',
    (tester) async {
      final fixture = R06Fixture()..empty = true;
      await fixture.mount(tester);
      expect(
        tester
            .widgetList<AdminMetricCard>(find.byType(AdminMetricCard))
            .singleWhere((card) => card.label == 'Saved scans')
            .value,
        '0',
      );
      expect(find.textContaining('No recorded operations'), findsOneWidget);
      expect(find.text('No scans in this period'), findsOneWidget);
      expect(find.text('Scan trends and model labels'), findsNothing);
    },
  );

  testWidgets(
    'daily chart is paged, accessible, and zero-count data cannot divide by zero',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AiOperationsPanel(
                data: AiOperations.fromJson(
                  r06Operations(days: 5, zeroDaily: true),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('Showing 1–9 of 15'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('0 recorded attempts, 0 failed')),
        findsNWidgets(9),
      );
      expect(
        tester
            .widgetList<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .every((bar) => bar.value == 0),
        isTrue,
      );
      await r06Tap(tester, find.text('Next entries'));
      expect(find.textContaining('Showing 10–15 of 15'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('0 recorded attempts, 0 failed')),
        findsNWidgets(6),
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'zero-sample latency is unavailable, while shared null metrics never display zero',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const AiOperationsPanel(
                    data: AiOperations(
                      'COLLECTED',
                      [
                        AiOperationSummary(
                          'NODE',
                          'INFERENCE',
                          0,
                          0,
                          0,
                          0,
                          0,
                          0,
                          0,
                        ),
                      ],
                      [],
                      0,
                    ),
                  ),
                  const SizedBox(
                    height: 500,
                    child: AdminMetricGrid(
                      children: [
                        AdminMetricCard(
                          label: 'Unknown metric',
                          value: null,
                          icon: Icons.info_outline,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(
        find.text('Latency unavailable: no recorded samples.'),
        findsOneWidget,
      );
      expect(find.text('Mean 0.0 ms'), findsNothing);
      expect(find.widgetWithText(AppMetricCard, 'Unavailable'), findsOneWidget);
    },
  );

  testWidgets(
    'loading, required-report failure and manual retry retain meaningful states',
    (tester) async {
      final fixture = R06Fixture()..reportGate = Completer<void>();
      await fixture.mount(tester, signedIn: false);
      unawaited(
        fixture.admin.signIn('admin@example.test', 'synthetic-password'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Loading system overview…'), findsOneWidget);
      fixture.dashboardStatus = 503;
      fixture.reportGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Something needs attention'), findsOneWidget);
      expect(find.byType(AdminMetricCard), findsNothing);
      fixture.dashboardStatus = 200;
      fixture.reportGate = null;
      await r06Tap(tester, find.text('Try again'));
      expect(find.byType(AdminMetricCard), findsNWidgets(4));
    },
  );

  testWidgets(
    'switching during a pending report shares its request and logout rejects its late response',
    (tester) async {
      final fixture = R06Fixture()..reportGate = Completer<void>();
      await fixture.mount(tester, signedIn: false);
      await tester.runAsync(
        () => fixture.admin.signIn('admin@example.test', 'synthetic-password'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Loading system overview…'), findsOneWidget);
      fixture.router.go('/admin/ai-operations');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Loading AI Operations…'), findsOneWidget);
      expect(
        fixture.requests
            .where((r) => r.url.path.endsWith('/ai-operations'))
            .length,
        1,
      );
      expect(
        fixture.requests.where((r) => r.url.path.endsWith('/dashboard')).length,
        1,
      );
      await tester.runAsync(fixture.admin.signOut);
      await tester.pumpAndSettle();
      fixture.reportGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Administrator sign-in'), findsOneWidget);
      expect(find.byType(AiOperationsView), findsNothing);
      expect(find.byType(AdminMetricCard), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
