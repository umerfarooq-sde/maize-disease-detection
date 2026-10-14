import 'package:flutter/foundation.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../data/models/farmer_analytics.dart';
import '../../../data/models/analytics_period.dart';
export '../../../data/models/analytics_period.dart';
import '../../../data/repositories/analytics_repository.dart';

class AnalyticsViewModel extends ChangeNotifier {
  AnalyticsViewModel(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now {
    _range = AnalyticsDateRange.lastDays(30, now: _now());
  }
  final AnalyticsRepository _repository;
  final DateTime Function() _now;
  late AnalyticsDateRange _range;
  FarmerAnalytics? _summary;
  final List<AnalyticsActivity> _activity = [];
  String? _cursor;
  int? _loadedRevision;
  bool _loading = false;
  bool _loadingMore = false;
  bool _disposed = false;
  bool _requiresSignIn = false;
  int _generation = 0;
  AppException? _error;
  AppException? _moreError;
  String? _filterError;
  bool get signedIn => _repository.hasAuthenticatedSession && !_requiresSignIn;
  bool get _sameSession =>
      signedIn && _loadedRevision == _repository.sessionRevision;
  FarmerAnalytics? get summary => _sameSession ? _summary : null;
  List<AnalyticsActivity> get activity =>
      _sameSession ? List.unmodifiable(_activity) : const [];
  AnalyticsDateRange get range => _range;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _sameSession && _cursor != null;
  AppException? get error => _error;
  AppException? get moreError => _moreError;
  String? get filterError => _filterError;
  int? get selectedDays =>
      _range.to == AnalyticsDateRange.lastDays(1, now: _now()).to
      ? _range.days
      : null;
  Future<void> selectCalendarRange(DateTime from, DateTime to) async {
    try {
      await load(range: AnalyticsDateRange(from, to));
    } on AppException {
      if (!_disposed) {
        _filterError = 'Choose 1–366 UTC dates through today.';
        notifyListeners();
      }
    }
  }

  List<AnalyticsPeriod> get periods =>
      analyticsPeriods(summary?.daily ?? const []);

  Future<void> selectDays(int days) =>
      load(range: AnalyticsDateRange.lastDays(days, now: _now()));
  Future<void> load({AnalyticsDateRange? range}) async {
    if (_disposed) return;
    if (range != null) {
      final today = AnalyticsDateRange.lastDays(1, now: _now()).to;
      if (range.to.isAfter(today)) {
        _filterError = 'Choose UTC dates through today.';
        notifyListeners();
        return;
      }
      _range = range;
    }
    _filterError = null;
    _error = null;
    _moreError = null;
    _requiresSignIn = false;
    final generation = ++_generation;
    _summary = null;
    _activity.clear();
    _cursor = null;
    _loadingMore = false;
    if (!_repository.hasAuthenticatedSession) {
      _loading = false;
      notifyListeners();
      return;
    }
    final revision = _repository.sessionRevision;
    _loadedRevision = revision;
    final selectedRange = _range;
    _loading = true;
    notifyListeners();
    try {
      final results = await Future.wait<Object>([
        _repository.summary(selectedRange),
        _repository.activity(selectedRange),
      ]);
      if (!_current(generation, revision)) return;
      final summary = results[0] as FarmerAnalytics;
      final page = results[1] as AnalyticsActivityPage;
      if (!summary.range.same(selectedRange) ||
          !page.range.same(selectedRange)) {
        throw const AppException(AppErrorKind.invalidResponse);
      }
      _summary = summary;
      _activity.addAll(page.items);
      _cursor = page.nextCursor;
    } on AppException catch (failure) {
      if (_current(generation, revision)) _failed(failure, false);
    } catch (_) {
      if (_current(generation, revision)) {
        _error = const AppException(AppErrorKind.server);
      }
    } finally {
      if (_current(generation, revision)) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    if (_disposed || _loading || _loadingMore || !hasMore) return;
    final cursor = _cursor!;
    final generation = _generation;
    final revision = _loadedRevision;
    _loadingMore = true;
    _moreError = null;
    notifyListeners();
    try {
      final page = await _repository.activity(_range, cursor: cursor);
      if (!_current(generation, revision)) return;
      if (!page.range.same(_range) || page.nextCursor == cursor) {
        throw const AppException(AppErrorKind.invalidResponse);
      }
      final seen = _activity.map((item) => item.id).toSet();
      _activity.addAll(page.items.where((item) => seen.add(item.id)));
      _cursor = page.nextCursor;
    } on AppException catch (failure) {
      if (_current(generation, revision)) _failed(failure, true);
    } catch (_) {
      if (_current(generation, revision)) {
        _moreError = const AppException(AppErrorKind.server);
      }
    } finally {
      if (_current(generation, revision)) {
        _loadingMore = false;
        notifyListeners();
      }
    }
  }

  void _failed(AppException failure, bool more) {
    if (failure.kind == AppErrorKind.authentication) {
      _requiresSignIn = true;
      _summary = null;
      _activity.clear();
      _cursor = null;
    } else if (more) {
      _moreError = failure;
    } else {
      _error = failure;
    }
  }

  bool _current(int generation, int? revision) {
    if (_disposed || generation != _generation) return false;
    if (!_repository.hasAuthenticatedSession ||
        _repository.sessionRevision != revision) {
      _summary = null;
      _activity.clear();
      _cursor = null;
      _loading = false;
      _loadingMore = false;
      notifyListeners();
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _summary = null;
    _activity.clear();
    _cursor = null;
    super.dispose();
  }
}
