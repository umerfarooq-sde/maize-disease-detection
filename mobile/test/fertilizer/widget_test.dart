import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/theme/app_theme.dart';
import 'package:maizedoctor/data/models/fertilizer_models.dart';
import 'package:maizedoctor/features/fertilizer_calculator/view_models/fertilizer_view_model.dart';
import 'package:maizedoctor/features/fertilizer_calculator/views/fertilizer_view.dart';
import 'helpers.dart';

Widget page(
  FertilizerViewModel model, {
  double textScale = 1,
  EdgeInsets viewInsets = EdgeInsets.zero,
}) => MaterialApp(
  theme: AppTheme.light,
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        viewInsets: viewInsets,
      ),
      child: Scaffold(
        body: ChangeNotifierProvider.value(
          value: model,
          child: const FertilizerView(),
        ),
      ),
    ),
  ),
);

Future<void> enterArea(WidgetTester tester, String value) async {
  final field = find.byKey(const Key('fertilizer-area'));
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pump();
}

Future<void> selectOption(
  WidgetTester tester,
  String field,
  String option,
) async {
  final selection = find.byKey(Key(field));
  await tester.ensureVisible(selection);
  await tester.tap(selection);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> calculate(WidgetTester tester) async {
  final action = find.byKey(const Key('fertilizer-calculate'));
  await tester.ensureVisible(action);
  await tester.tap(action);
  await tester.pump();
}

Future<FertilizerViewModel> readyModel(
  FakeFertilizerRepository repository,
) async {
  final model = FertilizerViewModel(repository);
  addTearDown(model.dispose);
  await model.load();
  model.selectRule(fixtureRuleId);
  model.setArea('2');
  return model;
}

void main() {
  testWidgets('pending rules allow field editing but no invented calculation', (
    tester,
  ) async {
    final repository = FakeFertilizerRepository(pending: true);
    final model = FertilizerViewModel(repository);
    addTearDown(model.dispose);
    await model.load();
    await tester.pumpWidget(page(model));
    expect(find.text('Approved fertilizer rules are pending'), findsOneWidget);
    expect(find.byKey(const Key('fertilizer-rule')), findsNothing);
    expect(find.text('Calculated fertilizer amount'), findsNothing);
    await enterArea(tester, '1.25');
    await selectOption(tester, 'fertilizer-area-unit', 'Acres');
    await selectOption(tester, 'fertilizer-output-unit', 'Grams (g)');
    expect(model.area, '1.25');
    expect(model.areaUnit, FertilizerAreaUnit.acre);
    expect(model.outputUnit, FertilizerMassUnit.grams);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('fertilizer-calculate')))
          .onPressed,
      null,
    );
    expect(repository.inputs, isEmpty);
    final refresh = find.byKey(const Key('fertilizer-reload-rules'));
    await tester.ensureVisible(refresh);
    await tester.tap(refresh);
    await tester.pumpAndSettle();
    expect(repository.ruleCalls, 2);
    expect(model.area, '1.25');
    expect(find.byKey(const Key('fertilizer-result-quantity')), findsNothing);
  });

  testWidgets(
    'selected synthetic rule shows assumptions and cited exact result',
    (tester) async {
      final repository = FakeFertilizerRepository();
      final model = FertilizerViewModel(repository);
      addTearDown(model.dispose);
      await model.load();
      await tester.pumpWidget(page(model));
      await enterArea(tester, '2');
      await selectOption(
        tester,
        'fertilizer-rule',
        'Synthetic arithmetic fixture — not agricultural advice',
      );
      expect(find.text('When this rule applies'), findsOneWidget);
      expect(find.text('Assumptions'), findsOneWidget);
      expect(find.text('Rule synthetic-test-only · version 1'), findsOneWidget);
      expect(
        find.text('Calculator maize-area-rate · version 1'),
        findsOneWidget,
      );
      expect(
        find.text('https://example.test/synthetic-fixture'),
        findsOneWidget,
      );
      await calculate(tester);
      await tester.pumpAndSettle();
      expect(repository.inputs.single.area, '2');
      expect(repository.inputs.single.ruleVersion, 1);
      expect(repository.inputs.single.configVersion, 1);
      expect(find.text('25.000 kg'), findsOneWidget);
      expect(find.text('Before rounding: 25 kg'), findsOneWidget);
      expect(find.text('Calculation assumptions'), findsOneWidget);
      expect(
        find.textContaining('Rounded to 3 decimal places'),
        findsOneWidget,
      );
      expect(find.text('Unit conversion reference'), findsOneWidget);
      expect(tester.takeException(), null);
    },
  );

  testWidgets('editing an input removes the previous result', (tester) async {
    final repository = FakeFertilizerRepository();
    final model = await readyModel(repository);
    await model.calculate();
    await tester.pumpWidget(page(model));
    expect(find.text('25.000 kg'), findsOneWidget);
    await enterArea(tester, '2.125');
    expect(model.result, null);
    expect(find.byKey(const Key('fertilizer-result-quantity')), findsNothing);
    expect(repository.inputs, hasLength(1));
    expect(model.canCalculate, isTrue);
  });

  testWidgets('catalogue loading and network retry preserve editable input', (
    tester,
  ) async {
    final pending = Completer<FertilizerCatalogue>();
    final repository = FakeFertilizerRepository()
      ..catalogues.add(pending.future);
    final model = FertilizerViewModel(repository);
    addTearDown(model.dispose);
    final loading = model.load();
    await tester.pumpWidget(page(model));
    expect(find.text('Checking approved rules…'), findsOneWidget);
    await enterArea(tester, '0.125');
    pending.completeError(const AppException(AppErrorKind.network));
    await loading;
    await tester.pumpAndSettle();
    expect(
      find.text(const AppException(AppErrorKind.network).message),
      findsOneWidget,
    );
    final retry = find.text('Try again');
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(repository.ruleCalls, 2);
    expect(model.area, '0.125');
    expect(find.byKey(const Key('fertilizer-rule')), findsOneWidget);
    expect(repository.inputs, isEmpty);
  });

  testWidgets('calculation loading prevents duplicate submission', (
    tester,
  ) async {
    final pending = Completer<FertilizerResult>();
    final repository = FakeFertilizerRepository()
      ..calculations.add(pending.future);
    final model = await readyModel(repository);
    await tester.pumpWidget(page(model));
    await calculate(tester);
    expect(find.text('Calculating from the selected rule…'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('fertilizer-calculate')))
          .onPressed,
      null,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('fertilizer-area')))
          .enabled,
      false,
    );
    expect(repository.inputs, hasLength(1));
    pending.complete(fertilizerResult(input: repository.inputs.single));
    await tester.pumpAndSettle();
    expect(find.text('25.000 kg'), findsOneWidget);
  });

  for (final kind in [
    AppErrorKind.network,
    AppErrorKind.timeout,
    AppErrorKind.server,
  ]) {
    testWidgets('${kind.name} calculation failure supports a bounded retry', (
      tester,
    ) async {
      final repository = FakeFertilizerRepository();
      final model = await readyModel(repository);
      repository.calculations.add(Future.error(AppException(kind)));
      await model.calculate();
      await tester.pumpWidget(page(model));
      expect(
        find.text('The calculation could not be completed'),
        findsOneWidget,
      );
      expect(find.text(AppException(kind).message), findsOneWidget);
      expect(find.byKey(const Key('fertilizer-result-quantity')), findsNothing);
      final retry = find.byKey(const Key('fertilizer-calculation-retry'));
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(repository.inputs, hasLength(2));
      expect(find.text('25.000 kg'), findsOneWidget);
      expect(
        find.byKey(const Key('fertilizer-calculation-retry')),
        findsNothing,
      );
    });
  }

  testWidgets('stale rule response refreshes without recalculating silently', (
    tester,
  ) async {
    final repository = FakeFertilizerRepository();
    final model = await readyModel(repository);
    repository.calculations.add(
      Future.error(const AppException(AppErrorKind.conflict, statusCode: 409)),
    );
    await model.calculate();
    const replacementId = '00000000-0000-4000-8000-000000000004';
    const replacementTitle =
        'Synthetic replacement arithmetic fixture — test only';
    repository.catalogues.add(
      Future.value(
        catalogue(
          items: [
            ruleJson(
              id: replacementId,
              version: 2,
              configVersion: 3,
              title: replacementTitle,
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(page(model));
    expect(find.text('Review the approved rule'), findsOneWidget);
    final refresh = find.text('Refresh approved rules');
    await tester.ensureVisible(refresh);
    await tester.tap(refresh);
    await tester.pumpAndSettle();
    expect(repository.ruleCalls, 2);
    expect(repository.inputs, hasLength(1));
    expect(model.result, null);
    expect(model.selectedRule, null);
    expect(model.canCalculate, false);
    await selectOption(tester, 'fertilizer-rule', replacementTitle);
    expect(find.text('Rule synthetic-test-only · version 2'), findsOneWidget);
    expect(find.text('Calculator maize-area-rate · version 3'), findsOneWidget);
    await calculate(tester);
    await tester.pumpAndSettle();
    expect(repository.inputs.last.ruleVersion, 2);
    expect(repository.inputs.last.configVersion, 3);
    expect(find.text('25.000 kg'), findsOneWidget);
  });

  testWidgets('invalid edited values remain visible without a request', (
    tester,
  ) async {
    final repository = FakeFertilizerRepository();
    final model = await readyModel(repository);
    await tester.pumpWidget(page(model));
    for (final value in [
      '',
      '-1',
      '0',
      '1,25',
      '1e3',
      '0.0000001',
      '1000000.000001',
    ]) {
      await enterArea(tester, value);
      expect(model.areaError, isNotNull);
      expect(find.text(model.areaError!), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('fertilizer-area')))
            .controller!
            .text,
        value,
      );
      expect(repository.inputs, isEmpty);
      expect(model.canCalculate, false);
    }
    await enterArea(tester, '0.125');
    expect(model.areaError, null);
    expect(model.canCalculate, true);
  });

  testWidgets('server grams and rounded zero retain exact display precision', (
    tester,
  ) async {
    final tinyRateRule = ruleJson(rate: '0.000001');
    final repository = FakeFertilizerRepository()
      ..catalogues.add(Future.value(catalogue(items: [tinyRateRule])));
    final model = await readyModel(repository);
    model.setArea('0.000001');
    model.selectOutputUnit(FertilizerMassUnit.grams);
    final input = fixtureInput(
      area: '0.000001',
      outputUnit: FertilizerMassUnit.grams,
    );
    repository.calculations.add(
      Future.value(
        FertilizerResult.fromJson(
          resultJson(
            input: input,
            quantity: '0.000',
            unrounded: '0.000000001',
            normalizedArea: '0.000001',
            rule: tinyRateRule,
          ),
        ),
      ),
    );
    await model.calculate();
    await tester.pumpWidget(page(model));
    expect(find.text('0.000 g'), findsOneWidget);
    expect(find.text('Before rounding: 0.000000001 g'), findsOneWidget);
    expect(
      find.textContaining('A displayed zero can result from rounding'),
      findsOneWidget,
    );
    expect(tester.takeException(), null);
  });

  testWidgets(
    '320px large text with keyboard and long references stays scrollable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final longTitle = List.filled(
        3,
        'Synthetic lengthy maize fertilizer fixture only',
      ).join(' ');
      final longRule = ruleJson(title: longTitle);
      final source = (longRule['source']! as Map<String, Object?>);
      source['citation'] = List.filled(
        15,
        'Synthetic source citation for layout testing only.',
      ).join(' ');
      source['url'] =
          'https://example.test/${List.filled(80, 'reference').join()}';
      final repository = FakeFertilizerRepository()
        ..catalogues.add(Future.value(catalogue(items: [longRule])));
      final model = await readyModel(repository);
      repository.calculations.add(
        Future.value(FertilizerResult.fromJson(resultJson(rule: longRule))),
      );
      await model.calculate();
      await tester.pumpWidget(
        page(
          model,
          textScale: 2,
          viewInsets: const EdgeInsets.only(bottom: 180),
        ),
      );
      await tester.pumpAndSettle();
      final area = find.byKey(const Key('fertilizer-area'));
      await tester.ensureVisible(area);
      await tester.tap(area);
      await tester.enterText(area, '2.125');
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('fertilizer-calculate')));
      expect(tester.takeException(), null);
      expect(find.byKey(const Key('fertilizer-result-quantity')), findsNothing);
    },
  );
}
