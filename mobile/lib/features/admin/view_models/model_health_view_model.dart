import 'package:flutter/foundation.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../data/models/model_health.dart';
import '../../../data/repositories/model_health_repository.dart';

class ModelHealthViewModel extends ChangeNotifier {
  ModelHealthViewModel(this._repository);
  final ModelHealthRepository _repository;
  AdminModelHealth? _data;
  int? _revision;
  int _generation = 0;
  bool _disposed = false;
  bool loading = false;
  AppException? error;
  AdminModelHealth? get data =>
      _repository.hasSession && _revision == _repository.revision
      ? _data
      : null;
  Future<void> load() async {
    if (_disposed) return;
    final generation = ++_generation;
    final revision = _repository.revision;
    _revision = revision;
    _data = null;
    error = null;
    loading = _repository.hasSession;
    notifyListeners();
    if (!loading) return;
    try {
      final value = await _repository.load();
      if (_current(generation, revision)) _data = value;
    } on AppException catch (failure) {
      if (_current(generation, revision)) error = failure;
    } catch (_) {
      if (_current(generation, revision)) {
        error = const AppException(AppErrorKind.server);
      }
    } finally {
      if (_current(generation, revision)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  bool _current(int generation, int? revision) =>
      !_disposed &&
      generation == _generation &&
      _repository.hasSession &&
      revision == _repository.revision;
  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _data = null;
    super.dispose();
  }
}
