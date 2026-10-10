import 'package:flutter/foundation.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../data/models/scan_record.dart';
import '../../../data/repositories/scan_records_repository.dart';

class ScanHistoryViewModel extends ChangeNotifier {
  ScanHistoryViewModel(this._repository);
  final ScanRecordsRepository _repository;
  final List<ScanRecord> _items = [];
  String? _nextCursor;
  AppException? _error;
  AppException? _loadMoreError;
  bool _loading = false;
  bool _loadingMore = false;
  bool _disposed = false;
  bool _requiresSignIn = false;
  int _generation = 0;

  bool get hasAuthenticatedSession =>
      _repository.hasAuthenticatedSession && !_requiresSignIn;
  List<ScanRecord> get items =>
      hasAuthenticatedSession ? List.unmodifiable(_items) : const [];
  bool get isLoading => _loading;
  bool get isLoadingMore => _loadingMore;
  bool get hasMore => hasAuthenticatedSession && _nextCursor != null;
  AppException? get error => _error;
  AppException? get loadMoreError => _loadMoreError;

  Future<void> load() => _loadFirstPage();
  Future<void> refresh() => _loadFirstPage(refresh: true);

  Future<void> _loadFirstPage({bool refresh = false}) async {
    if (_disposed || (!refresh && (_loading || _loadingMore))) return;
    if (!_repository.hasAuthenticatedSession) {
      _clearSession();
      notifyListeners();
      return;
    }
    final generation = ++_generation;
    _requiresSignIn = false;
    _loading = true;
    _loadingMore = false;
    _error = null;
    _loadMoreError = null;
    notifyListeners();
    try {
      final page = await _repository.history();
      if (!_isCurrent(generation)) return;
      _items
        ..clear()
        ..addAll(page.items);
      _nextCursor = page.nextCursor;
    } on AppException catch (error) {
      if (!_isCurrent(generation)) return;
      if (error.kind == AppErrorKind.authentication) {
        _clearSession();
        _requiresSignIn = true;
      } else {
        _error = error;
      }
    } catch (_) {
      if (_isCurrent(generation)) {
        _error = const AppException(AppErrorKind.server);
      }
    } finally {
      if (_isCurrent(generation)) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    if (_disposed || _loading || _loadingMore || !hasMore) return;
    final cursor = _nextCursor!;
    final generation = _generation;
    _loadingMore = true;
    _loadMoreError = null;
    notifyListeners();
    try {
      final page = await _repository.history(cursor: cursor);
      if (!_isCurrent(generation)) return;
      final seen = _items.map((item) => item.id).toSet();
      _items.addAll(page.items.where((item) => seen.add(item.id)));
      _nextCursor = page.nextCursor;
    } on AppException catch (error) {
      if (!_isCurrent(generation)) return;
      if (error.kind == AppErrorKind.authentication) {
        _clearSession();
        _requiresSignIn = true;
      } else {
        _loadMoreError = error;
      }
    } catch (_) {
      if (_isCurrent(generation)) {
        _loadMoreError = const AppException(AppErrorKind.server);
      }
    } finally {
      if (_isCurrent(generation)) {
        _loadingMore = false;
        notifyListeners();
      }
    }
  }

  bool _isCurrent(int generation) {
    if (_disposed || generation != _generation) return false;
    if (!_repository.hasAuthenticatedSession) {
      _clearSession();
      notifyListeners();
      return false;
    }
    return true;
  }

  void _clearSession() {
    _items.clear();
    _nextCursor = null;
    _error = null;
    _loadMoreError = null;
    _loading = false;
    _loadingMore = false;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _clearSession();
    super.dispose();
  }
}
