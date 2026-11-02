import 'package:flutter/foundation.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../data/models/backend_health.dart';
import '../../../data/repositories/backend_repository.dart';
import '../../../data/models/scan_record.dart';
import '../../../data/repositories/scan_records_repository.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel(this._repository, {ScanRecordsRepository? records})
    : _records = records;
  final BackendRepository _repository;
  final ScanRecordsRepository? _records;
  bool _disposed = false;
  bool _isLoading = false;
  BackendHealth? _health;
  AppException? _error;
  bool get isLoading => _isLoading;
  BackendHealth? get health => _health;
  AppException? get error => _error;
  List<ScanRecord> _recentScans = const [];
  bool recentLoading = false;
  AppException? recentError;
  bool get hasHistoryAccess => _records?.hasAuthenticatedSession ?? false;
  List<ScanRecord> get recentScans =>
      hasHistoryAccess ? _recentScans : const [];

  /// A bounded dashboard projection, independent of paginated History state.
  /// The router scopes this model to the Farmer identity revision.
  Future<void> loadRecentScans() async {
    final records = _records;
    if (_disposed || recentLoading || records == null || !hasHistoryAccess) {
      return;
    }
    recentLoading = true;
    recentError = null;
    _recentScans = const [];
    notifyListeners();
    try {
      final page = await records.history(limit: 3);
      if (!_disposed && hasHistoryAccess) {
        _recentScans = List.unmodifiable(page.items.take(3));
      }
    } on AppException catch (failure) {
      if (!_disposed && hasHistoryAccess) {
        recentError = failure;
      }
    } catch (_) {
      if (!_disposed && hasHistoryAccess) {
        recentError = const AppException(AppErrorKind.network);
      }
    } finally {
      if (!_disposed) {
        recentLoading = false;
        notifyListeners();
      }
    }
  }

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
    _recentScans = const [];
    super.dispose();
  }
}
