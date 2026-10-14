import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:maizedoctor/app.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/theme/app_theme.dart';
import 'package:maizedoctor/data/models/yield_models.dart';
import 'package:maizedoctor/features/yield_calculator/view_models/yield_view_model.dart';
import 'package:maizedoctor/features/yield_calculator/views/yield_view.dart';
import 'helpers.dart';

Widget page(
  YieldViewModel model, {
  double scale = 1,
  EdgeInsets insets = EdgeInsets.zero,
}) => MaterialApp(
  theme: AppTheme.light,
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale), viewInsets: insets),
      child: Scaffold(
        body: ChangeNotifierProvider.value(
          value: model,
          child: const YieldView(),
        ),
      ),
    ),
  ),
);
Future<YieldViewModel> ready(FakeYieldRepository repository) async {
  final model = YieldViewModel(repository);
  addTearDown(model.dispose);
  await model.load();
  model.setArea('2');
  model.selectConfiguration(fixtureId);
  return model;
}

Future<void> calculate(WidgetTester tester) async {
  final button = find.byKey(const Key('yield-calculate'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
}

void main() {
  testWidgets(
    'pending configuration allows editing units/area but never generates a yield',
    (tester) async {
      final repository = FakeYieldRepository()
        ..onConfigurations = () async =>
            YieldCatalogue.fromJson(catalogueJson(pending: true));
      final model = await ready(repository);
      await tester.pumpWidget(page(model));
      expect(find.text('Yield configuration pending'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('yield-calculate')))
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.byKey(const Key('yield-area')));
      await tester.enterText(find.byKey(const Key('yield-area')), '3.5');
      await tester.pump();
      expect(model.area, '3.5');
      expect(repository.requests, isEmpty);
      expect(find.byKey(const Key('yield-result-quantity')), findsNothing);
    },
  );
  testWidgets(
    'conditional result displays unchanged exact amount, assumptions, source and versions',
    (tester) async {
      final model = await ready(FakeYieldRepository());
      await tester.pumpWidget(page(model));
      await calculate(tester);
      await tester.pumpAndSettle();
      expect(find.text('25.000 kg'), findsOneWidget);
      expect(find.text('Expected yield · planning estimate'), findsOneWidget);
      expect(find.textContaining('version 1'), findsOneWidget);
      expect(find.textContaining(yieldFormulaVersion), findsOneWidget);
      expect(find.text('Synthetic source fixture'), findsOneWidget);
      expect(
        find.text('https://example.invalid/synthetic-yield'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Fixture only; no weather or soil adjustment is inferred.',
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(const Key('yield-area')));
      await tester.enterText(find.byKey(const Key('yield-area')), '3');
      await tester.pump();
      expect(find.byKey(const Key('yield-result-quantity')), findsNothing);
    },
  );
  testWidgets(
    'loading blocks duplicate submission and network errors offer retry',
    (tester) async {
      final repository = FakeYieldRepository();
      final model = await ready(repository);
      final pending = Completer<YieldResult>();
      repository.onCalculate = (_) => pending.future;
      await tester.pumpWidget(page(model));
      await calculate(tester);
      expect(find.text('Calculating your planning estimate…'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('yield-calculate')))
            .onPressed,
        isNull,
      );
      pending.completeError(const AppException(AppErrorKind.network));
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);
      repository.onCalculate = (input) async =>
          YieldResult.fromJson(resultJson(input: input));
      final retry = find.text('Try again');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(find.text('25.000 kg'), findsOneWidget);
    },
  );
  testWidgets(
    'stale versions refresh only and require explicit new configuration selection',
    (tester) async {
      final repository = FakeYieldRepository()
        ..onCalculate = (_) async =>
            throw const AppException(AppErrorKind.conflict);
      final model = await ready(repository);
      await tester.pumpWidget(page(model));
      await calculate(tester);
      await tester.pumpAndSettle();
      expect(find.text('Refresh configurations'), findsOneWidget);
      repository.onConfigurations = () async => YieldCatalogue.fromJson(
        catalogueJson(
          items: [
            configurationJson(
              id: '00000000-0000-4000-8000-000000000002',
              version: 2,
            ),
          ],
        ),
      );
      final refresh = find.text('Refresh configurations');
      await tester.ensureVisible(refresh);
      await tester.tap(refresh);
      await tester.pumpAndSettle();
      expect(repository.requests.length, 1);
      expect(model.selected, isNull);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('yield-calculate')))
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets(
    '320px, large text, keyboard and long references remain scrollable without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeYieldRepository();
      final config = configurationJson()
        ..['title'] = List.filled(8, 'Long reviewed title').join(' ');
      repository.onConfigurations = () async =>
          YieldCatalogue.fromJson(catalogueJson(items: [config]));
      repository.onCalculate = (input) async =>
          YieldResult.fromJson(resultJson(input: input, configuration: config));
      final model = await ready(repository);
      await model.calculate();
      await tester.pumpWidget(
        page(model, scale: 2, insets: const EdgeInsets.only(bottom: 260)),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Synthetic source fixture'));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'real router supplies scoped yield state and public Node repository',
    (tester) async {
      final paths = <String>[];
      final client = MockClient((request) async {
        paths.add(request.url.path);
        return http.Response(
          jsonEncode({
            'success': true,
            'data': catalogueJson(pending: true),
            'requestId': fixtureId,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      await tester.pumpWidget(
        MainApp(
          config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
          httpClient: client,
          initialLocation: '/tools/yield',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Yield configuration pending'), findsOneWidget);
      expect(paths, ['/api/v1/calculators/yield/configurations']);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
