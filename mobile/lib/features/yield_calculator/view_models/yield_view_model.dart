import 'package:flutter/foundation.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../data/models/calculator_input.dart';
import '../../../data/models/yield_models.dart';
import '../../../data/repositories/yield_repository.dart';

class YieldViewModel extends ChangeNotifier {
  YieldViewModel(this._repository);
  final YieldRepository _repository;
  YieldCatalogue? catalogue;
  YieldConfiguration? selected;
  YieldResult? result;
  AppException? error;
  AppException? calculationError;
  String area = '';
  String? areaError;
  CalculatorAreaUnit areaUnit = CalculatorAreaUnit.hectare;
  YieldMassUnit outputUnit = YieldMassUnit.kg;
  bool loading = false;
  bool submitting = false;
  bool _disposed = false;
  int _generation = 0;
  YieldInput? _retryInput;
  bool get _validArea {
    try {
      normalizeCalculatorArea(area);
      return true;
    } on AppException {
      return false;
    }
  }

  bool get canCalculate =>
      !_disposed &&
      !loading &&
      !submitting &&
      catalogue?.status == YieldCatalogueStatus.ready &&
      selected != null &&
      _validArea;
  bool get canRetry =>
      !_disposed && !loading && !submitting && _retryInput != null;
  bool get needsRefresh =>
      calculationError?.kind == AppErrorKind.conflict ||
      calculationError?.kind == AppErrorKind.notFound;

  Future<void> load() async {
    if (_disposed || loading) return;
    final generation = ++_generation;
    final previous = selected?.id;
    loading = true;
    submitting = false;
    catalogue = null;
    selected = null;
    result = null;
    calculationError = null;
    _retryInput = null;
    error = null;
    notifyListeners();
    bool current() => !_disposed && generation == _generation;
    try {
      final loaded = await _repository.configurations();
      if (!current()) return;
      catalogue = loaded;
      for (final item in loaded.items) {
        if (item.id == previous) selected = item;
      }
    } on AppException catch (failure) {
      if (current()) error = failure;
    } catch (_) {
      if (current()) error = const AppException(AppErrorKind.server);
    } finally {
      if (current()) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void setArea(String value) {
    if (_disposed || value == area) return;
    area = value;
    areaError = _validArea
        ? null
        : 'Enter an area greater than zero, up to 1,000,000, with at most 6 decimal places.';
    _edited();
  }

  void selectAreaUnit(CalculatorAreaUnit value) {
    if (_disposed || value == areaUnit) return;
    areaUnit = value;
    _edited();
  }

  void selectOutputUnit(YieldMassUnit value) {
    if (_disposed || value == outputUnit) return;
    outputUnit = value;
    _edited();
  }

  void selectConfiguration(String? id) {
    if (_disposed) return;
    YieldConfiguration? next;
    for (final item in catalogue?.items ?? <YieldConfiguration>[]) {
      if (item.id == id) next = item;
    }
    if (next == selected) return;
    selected = next;
    _edited();
  }

  void _edited() {
    // Editing can occur while a catalogue is loading. Its response is independent
    // of area/units, so only fence a pending calculation, not the catalogue load.
    if (!loading) _generation++;
    submitting = false;
    result = null;
    calculationError = null;
    _retryInput = null;
    notifyListeners();
  }

  Future<void> calculate() async {
    if (!canCalculate) return;
    await _run(
      YieldInput(
        area: area,
        areaUnit: areaUnit,
        outputUnit: outputUnit,
        configId: selected!.id,
        configVersion: selected!.version,
      ),
    );
  }

  Future<void> retry() async {
    if (_disposed || loading || submitting) return;
    if (error != null || needsRefresh) {
      await load();
    } else if (canRetry) {
      await _run(_retryInput!);
    }
  }

  Future<void> _run(YieldInput input) async {
    final generation = ++_generation;
    bool current() => !_disposed && generation == _generation;
    result = null;
    calculationError = null;
    _retryInput = null;
    submitting = true;
    notifyListeners();
    try {
      final answer = await _repository.calculate(input);
      if (!current()) return;
      if (!answer.matches(input)) {
        throw const AppException(AppErrorKind.invalidResponse);
      }
      result = answer;
    } on AppException catch (failure) {
      if (!current()) return;
      calculationError = failure;
      if (!needsRefresh && failure.kind != AppErrorKind.validation) {
        _retryInput = input;
      }
    } catch (_) {
      if (current()) {
        calculationError = const AppException(AppErrorKind.server);
        _retryInput = input;
      }
    } finally {
      if (current()) {
        submitting = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _retryInput = null;
    result = null;
    super.dispose();
  }
}
