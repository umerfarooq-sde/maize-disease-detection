import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/data/models/yield_models.dart';
import 'package:maizedoctor/features/yield_calculator/view_models/yield_view_model.dart';
import 'helpers.dart';

Future<YieldViewModel> ready(FakeYieldRepository repository) async {
  final model = YieldViewModel(repository);
  addTearDown(model.dispose);
  await model.load();
  model.setArea('2');
  model.selectConfiguration(fixtureId);
  return model;
}

void main() {
  test(
    'pending configuration never enables calculation or invents a fallback',
    () async {
      final repository = FakeYieldRepository()
        ..onConfigurations = () async =>
            YieldCatalogue.fromJson(catalogueJson(pending: true));
      final model = await ready(repository);
      expect(model.canCalculate, false);
      await model.calculate();
      expect(repository.requests, isEmpty);
    },
  );
  test(
    'explicit choice/input drives deterministic result and edits clear prior result',
    () async {
      final repository = FakeYieldRepository();
      final model = await ready(repository);
      expect(model.canCalculate, true);
      await model.calculate();
      expect(model.result!.value, '25.000');
      model.selectOutputUnit(YieldMassUnit.tonnes);
      expect(model.result, isNull);
      expect(model.outputUnit, YieldMassUnit.tonnes);
      model.setArea('-1');
      expect(model.canCalculate, false);
      expect(model.areaError, isNotNull);
    },
  );
  test(
    'network/timeout retry keeps explicit input while stale pins only refresh configuration',
    () async {
      final repository = FakeYieldRepository();
      final model = await ready(repository);
      for (final kind in [
        AppErrorKind.network,
        AppErrorKind.timeout,
        AppErrorKind.server,
      ]) {
        repository.onCalculate = (_) async => throw AppException(kind);
        await model.calculate();
        expect(model.calculationError!.kind, kind);
        expect(model.canRetry, true);
        repository.onCalculate = (input) async =>
            YieldResult.fromJson(resultJson(input: input));
        await model.retry();
        expect(model.result, isNotNull);
      }
      repository.onCalculate = (_) async =>
          throw const AppException(AppErrorKind.conflict);
      await model.calculate();
      final count = repository.requests.length;
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
      await model.retry();
      expect(repository.requests.length, count);
      expect(model.selected, isNull);
      expect(model.canCalculate, false);
      expect(model.area, '2');
    },
  );
  test(
    'editing, reload and dispose discard late calculation responses',
    () async {
      for (final action in ['edit', 'reload', 'dispose']) {
        final repository = FakeYieldRepository();
        final model = YieldViewModel(repository);
        await model.load();
        model.setArea('2');
        model.selectConfiguration(fixtureId);
        final pending = Completer<YieldResult>();
        repository.onCalculate = (_) => pending.future;
        final result = model.calculate();
        expect(model.submitting, true);
        if (action == 'edit') model.setArea('3');
        if (action == 'reload') await model.load();
        if (action == 'dispose') model.dispose();
        pending.complete(YieldResult.fromJson(resultJson()));
        await result;
        expect(model.result, isNull);
        if (action != 'dispose') model.dispose();
      }
    },
  );
  test(
    'editing during catalogue load retains edited input and accepts the independent catalogue',
    () async {
      final repository = FakeYieldRepository();
      final pending = Completer<YieldCatalogue>();
      repository.onConfigurations = () => pending.future;
      final model = YieldViewModel(repository);
      addTearDown(model.dispose);
      final load = model.load();
      model.setArea('3');
      model.selectAreaUnit(CalculatorAreaUnit.acre);
      pending.complete(YieldCatalogue.fromJson(catalogueJson()));
      await load;
      expect(model.catalogue, isNotNull);
      expect(model.area, '3');
      expect(model.areaUnit, CalculatorAreaUnit.acre);
    },
  );
  test('catalogue failures are safe and retryable', () async {
    final repository = FakeYieldRepository()
      ..onConfigurations = () async =>
          throw const AppException(AppErrorKind.network);
    final model = YieldViewModel(repository);
    addTearDown(model.dispose);
    await model.load();
    expect(model.error!.kind, AppErrorKind.network);
    repository.onConfigurations = () async =>
        YieldCatalogue.fromJson(catalogueJson());
    await model.retry();
    expect(model.error, isNull);
    expect(model.catalogue!.items.length, 1);
  });
}
