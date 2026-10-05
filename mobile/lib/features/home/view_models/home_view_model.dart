import 'package:flutter/foundation.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../data/models/backend_health.dart';
import '../../../data/repositories/backend_repository.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel(this._repository);
  final BackendRepository _repository;
  bool _disposed = false;
  bool _isLoading = false;
  BackendHealth? _health;
  AppException? _error;
  bool get isLoading => _isLoading;
  BackendHealth? get health => _health;
  AppException? get error => _error;

  Future<void> checkConnection() async {
    if (_isLoading || _disposed) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _health = await _repository.checkConnection();
    } on AppException catch (error) {
      _health = null;
      _error = error;
    } catch (_) {
      _health = null;
      _error = const AppException(AppErrorKind.server);
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
