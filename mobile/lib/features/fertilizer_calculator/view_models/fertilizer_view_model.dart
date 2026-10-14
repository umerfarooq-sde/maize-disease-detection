import 'package:flutter/foundation.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../data/models/fertilizer_models.dart';
import '../../../data/repositories/fertilizer_repository.dart';

class FertilizerViewModel extends ChangeNotifier {
  FertilizerViewModel(this._repository);
  final FertilizerRepository _repository;
  FertilizerCatalogue? _catalogue;
  FertilizerRule? _selectedRule;
  FertilizerResult? _result;
  String _area = '';
  FertilizerAreaUnit _areaUnit = FertilizerAreaUnit.hectare;
  FertilizerMassUnit _outputUnit = FertilizerMassUnit.kg;
  String? _areaError;
  AppException? _error;
  AppException? _calculationError;
  bool _loading = false;
  bool _submitting = false;
  bool _disposed = false;
  int _loadGeneration = 0;
  int _inputGeneration = 0;
  FertilizerInput? _retryInput;

  FertilizerCatalogue? get catalogue => _catalogue;
  FertilizerRule? get selectedRule => _selectedRule;
  FertilizerResult? get result => _result;
  String get area => _area;
  FertilizerAreaUnit get areaUnit => _areaUnit;
  FertilizerMassUnit get outputUnit => _outputUnit;
  String? get areaError => _areaError;
  AppException? get error => _error;
  AppException? get calculationError => _calculationError;
  bool get loading => _loading;
  bool get submitting => _submitting;
  bool get canCalculate =>
      !_disposed &&
      !_loading &&
      !_submitting &&
      _catalogue?.status == FertilizerCatalogueStatus.ready &&
      _selectedRule != null &&
      _validArea;
  bool get canRetryCalculation =>
      !_disposed &&
      !_loading &&
      !_submitting &&
      _retryInput != null &&
      _calculationError != null;

  bool get _validArea {
    try {
      normalizeFertilizerArea(_area);
      return true;
    } on AppException {
      return false;
    }
  }

  Future<void> load() async {
    if (_disposed || _loading) return;
    final generation = ++_loadGeneration;
    _invalidateResult();
    final oldId = _selectedRule?.id;
    _catalogue = null;
    _selectedRule = null;
    _loading = true;
    _error = null;
    _notify();
    bool current() => !_disposed && generation == _loadGeneration;
    try {
      final catalogue = await _repository.rules();
      if (!current()) return;
      _catalogue = catalogue;
      // A refreshed catalogue supplies the current immutable versions. The user
      // still confirms a new calculation instead of reusing a prior result.
      for (final rule in catalogue.items) {
        if (rule.id == oldId) _selectedRule = rule;
      }
    } on AppException catch (failure) {
      if (current()) _error = failure;
    } catch (_) {
      if (current()) _error = const AppException(AppErrorKind.server);
    } finally {
      if (current()) {
        _loading = false;
        _notify();
      }
    }
  }

  void setArea(String value) {
    if (_disposed || value == _area) return;
    _area = value;
    _invalidateResult();
    _areaError = _validArea
        ? null
        : 'Enter an area greater than zero, up to 1,000,000, with at most 6 decimal places.';
    _notify();
  }

  void selectAreaUnit(FertilizerAreaUnit unit) {
    if (_disposed || unit == _areaUnit) return;
    _areaUnit = unit;
    _invalidateResult();
    _notify();
  }

  void selectOutputUnit(FertilizerMassUnit unit) {
    if (_disposed || unit == _outputUnit) return;
    _outputUnit = unit;
    _invalidateResult();
    _notify();
  }

  void selectRule(String? id) {
    if (_disposed) return;
    FertilizerRule? selected;
    for (final rule in _catalogue?.items ?? <FertilizerRule>[]) {
      if (rule.id == id) selected = rule;
    }
    if (selected == _selectedRule) return;
    _selectedRule = selected;
    _invalidateResult();
    _notify();
  }

  Future<void> calculate() async {
    if (!canCalculate) return;
    final rule = _selectedRule!;
    final input = FertilizerInput(
      area: _area,
      areaUnit: _areaUnit,
      ruleId: rule.id,
      ruleVersion: rule.version,
      configVersion: rule.config.version,
      outputUnit: _outputUnit,
    );
    await _run(input);
  }

  Future<void> retry() async {
    if (_disposed) return;
    if (_error != null ||
        _calculationError?.kind == AppErrorKind.conflict ||
        _calculationError?.kind == AppErrorKind.notFound) {
      await load();
    } else if (canRetryCalculation) {
      await _run(_retryInput!);
    }
  }

  Future<void> _run(FertilizerInput input) async {
    final generation = ++_inputGeneration;
    bool current() => !_disposed && generation == _inputGeneration;
    _result = null;
    _calculationError = null;
    _retryInput = null;
    _submitting = true;
    _notify();
    try {
      final result = await _repository.calculate(input);
      if (!current()) return;
      if (!result.matches(input)) {
        throw const AppException(AppErrorKind.invalidResponse);
      }
      _result = result;
    } on AppException catch (failure) {
      if (!current()) return;
      _calculationError = failure;
      // Refresh stale rule/config versions rather than automatically calculating
      // against a different recommendation under the original submission.
      if (failure.kind != AppErrorKind.conflict &&
          failure.kind != AppErrorKind.notFound &&
          failure.kind != AppErrorKind.validation) {
        _retryInput = input;
      }
    } catch (_) {
      if (current()) {
        _calculationError = const AppException(AppErrorKind.server);
        _retryInput = input;
      }
    } finally {
      if (current()) {
        _submitting = false;
        _notify();
      }
    }
  }

  void _invalidateResult() {
    _inputGeneration++;
    _result = null;
    _calculationError = null;
    _retryInput = null;
    _submitting = false;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _loadGeneration++;
    _invalidateResult();
    _catalogue = null;
    _selectedRule = null;
    super.dispose();
  }
}
