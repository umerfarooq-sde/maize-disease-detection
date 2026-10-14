import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/data/models/fertilizer_models.dart';
import 'package:maizedoctor/features/fertilizer_calculator/view_models/fertilizer_view_model.dart';
import 'helpers.dart';

Future<FertilizerViewModel> ready(FakeFertilizerRepository repository) async {
  final model = FertilizerViewModel(repository);
  addTearDown(model.dispose);
  await model.load();
  model.setArea('2');
  model.selectRule(fixtureRuleId);
  return model;
}

void main() {
  test(
    'pending recommendations allow editing but never fabricated calculations',
    () async {
      final repository = FakeFertilizerRepository(pending: true);
      final model = FertilizerViewModel(repository);
      addTearDown(model.dispose);
      await model.load();
      model.setArea('3.125');
      model.selectAreaUnit(FertilizerAreaUnit.acre);
      model.selectOutputUnit(FertilizerMassUnit.grams);
      model.selectRule(fixtureRuleId);
      await model.calculate();
      expect(model.catalogue!.status, FertilizerCatalogueStatus.pendingRules);
      expect(model.selectedRule, isNull);
      expect(model.canCalculate, false);
      expect(model.result, isNull);
      expect(repository.inputs, isEmpty);
      expect(model.area, '3.125');
    },
  );

  test(
    'rules and versions require explicit selection; calculation stays remote',
    () async {
      final repository = FakeFertilizerRepository();
      final model = FertilizerViewModel(repository);
      addTearDown(model.dispose);
      await model.load();
      model.setArea('2');
      expect(model.selectedRule, isNull);
      expect(model.canCalculate, false);
      model.selectRule(fixtureRuleId);
      await model.calculate();
      expect(repository.inputs.single.toJson(), fixtureInput().toJson());
      expect(model.result!.quantity.value, '25.000');
      expect(model.result!.explanation, contains('Synthetic'));
    },
  );

  test(
    'invalid area prevents requests with a useful validation message',
    () async {
      final repository = FakeFertilizerRepository();
      final model = await ready(repository);
      for (final area in [
        '',
        '-1',
        '0',
        '1e5',
        'NaN',
        '1000000.000001',
        '0.0000001',
        '1,5',
      ]) {
        model.setArea(area);
        await model.calculate();
        expect(model.areaError, isNotNull);
        expect(model.canCalculate, false);
      }
      expect(repository.inputs, isEmpty);
      model.setArea('0.000001');
      expect(model.areaError, isNull);
      expect(model.canCalculate, true);
    },
  );

  test(
    'duplicate submissions are blocked and successful loading is observable',
    () async {
      final repository = FakeFertilizerRepository();
      final model = await ready(repository);
      final pending = Completer<FertilizerResult>();
      repository.calculations.add(pending.future);
      final states = <bool>[];
      model.addListener(() => states.add(model.submitting));
      final request = model.calculate();
      await model.calculate();
      expect(model.submitting, true);
      expect(repository.inputs, hasLength(1));
      pending.complete(fertilizerResult());
      await request;
      expect(states, [true, false]);
      expect(model.result, isNotNull);
    },
  );

  test(
    'area or unit edits discard prior results and fence delayed responses',
    () async {
      final repository = FakeFertilizerRepository();
      final model = await ready(repository);
      await model.calculate();
      model.selectOutputUnit(FertilizerMassUnit.grams);
      expect(model.result, isNull);
      model.selectOutputUnit(FertilizerMassUnit.kg);
      final old = Completer<FertilizerResult>();
      repository.calculations.add(old.future);
      final request = model.calculate();
      model.setArea('3');
      model.selectAreaUnit(FertilizerAreaUnit.acre);
      expect(model.submitting, false);
      old.complete(fertilizerResult());
      await request;
      expect(model.result, isNull);
      expect(model.calculationError, isNull);
      expect(model.area, '3');
    },
  );

  test(
    'rule changes cannot retain a result for an unrelated recommendation',
    () async {
      final repository = FakeFertilizerRepository();
      final model = await ready(repository);
      await model.calculate();
      model.selectRule('unknown-rule');
      expect(model.selectedRule, isNull);
      expect(model.result, isNull);
      expect(model.canCalculate, false);
      model.selectRule(fixtureRuleId);
      expect(model.canCalculate, true);
    },
  );

  test(
    'network retry preserves the original selected versions and decimal input',
    () async {
      final repository = FakeFertilizerRepository();
      final model = await ready(repository);
      repository.calculations.add(
        Future.error(const AppException(AppErrorKind.network)),
      );
      await model.calculate();
      expect(model.calculationError!.kind, AppErrorKind.network);
      expect(model.canRetryCalculation, true);
      await model.retry();
      expect(repository.inputs, hasLength(2));
      expect(repository.inputs.first.toJson(), repository.inputs.last.toJson());
      expect(model.result, isNotNull);
      expect(model.canRetryCalculation, false);
    },
  );

  test(
    'stale version retry refreshes rules and requires a new calculation',
    () async {
      final repository = FakeFertilizerRepository();
      final model = await ready(repository);
      for (final kind in [AppErrorKind.conflict, AppErrorKind.notFound]) {
        repository.calculations.add(Future.error(AppException(kind)));
        await model.calculate();
        repository.catalogues.add(
          Future.value(catalogue(items: [ruleJson(version: 2)])),
        );
        final calculationsBeforeRefresh = repository.inputs.length;
        await model.retry();
        expect(repository.inputs.length, calculationsBeforeRefresh);
        expect(model.selectedRule!.version, 2);
        expect(model.result, isNull);
        expect(model.calculationError, isNull);
        expect(model.canCalculate, true);
      }
    },
  );

  test(
    'refreshing an unavailable catalogue retains input and does not guess rates',
    () async {
      final repository = FakeFertilizerRepository();
      repository.catalogues.add(
        Future.error(const AppException(AppErrorKind.network)),
      );
      final model = FertilizerViewModel(repository);
      addTearDown(model.dispose);
      model.setArea('4.25');
      await model.load();
      expect(model.error!.kind, AppErrorKind.network);
      expect(model.catalogue, isNull);
      expect(model.canCalculate, false);
      await model.retry();
      expect(repository.ruleCalls, 2);
      expect(model.error, isNull);
      expect(model.area, '4.25');
      expect(model.selectedRule, isNull);
    },
  );

  test(
    'malformed or wrong-input repository result becomes a safe failure',
    () async {
      final repository = FakeFertilizerRepository();
      final model = await ready(repository);
      repository.calculations.add(
        Future.value(fertilizerResult(input: fixtureInput(area: '3'))),
      );
      await model.calculate();
      expect(model.result, isNull);
      expect(model.calculationError!.kind, AppErrorKind.invalidResponse);
      repository.calculations.add(
        Future.error(StateError('private source data')),
      );
      await model.retry();
      expect(model.calculationError!.kind, AppErrorKind.server);
      expect(model.calculationError!.message, isNot(contains('private')));
    },
  );

  test(
    'reload during a calculation fences old response and clears old selection if absent',
    () async {
      final repository = FakeFertilizerRepository();
      final model = await ready(repository);
      final pending = Completer<FertilizerResult>();
      repository.calculations.add(pending.future);
      final old = model.calculate();
      repository.pending = true;
      await model.load();
      pending.complete(fertilizerResult());
      await old;
      expect(model.result, isNull);
      expect(model.submitting, false);
      expect(model.selectedRule, isNull);
    },
  );

  test(
    'disposed ViewModel ignores delayed results and starts no more work',
    () async {
      final repository = FakeFertilizerRepository();
      final model = FertilizerViewModel(repository);
      final pending = Completer<FertilizerCatalogue>();
      repository.catalogues.add(pending.future);
      var notifications = 0;
      model.addListener(() => notifications++);
      final loading = model.load();
      model.dispose();
      pending.complete(catalogue());
      await loading;
      await model.load();
      await model.calculate();
      model.setArea('2');
      expect(repository.ruleCalls, 1);
      expect(repository.inputs, isEmpty);
      expect(notifications, 1);
    },
  );
}
