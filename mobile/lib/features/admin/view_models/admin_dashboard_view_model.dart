import 'package:flutter/foundation.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../data/models/admin_dashboard.dart';
import '../../../data/models/farmer_analytics.dart';
import '../../../data/repositories/admin_dashboard_repository.dart';

class AdminDashboardViewModel extends ChangeNotifier {
  AdminDashboardViewModel(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now {
    range = AnalyticsDateRange.lastDays(30, now: _now());
  }
  final AdminDashboardRepository _repository;
  final DateTime Function() _now;
  late AnalyticsDateRange range;
  AdminDashboard? _data;
  int? _revision;
  int _generation = 0;
  bool _disposed = false;
  bool loading = false;
  AppException? error;
  AdminDashboard? get data =>
      _repository.hasSession && _revision == _repository.revision
      ? _data
      : null;
  Future<void> selectDays(int days) =>
      load(range: AnalyticsDateRange.lastDays(days, now: _now()));
  Future<void> load({AnalyticsDateRange? range}) async {
    if (_disposed) return;
    if (range != null) this.range = range;
    final generation = ++_generation;
    final revision = _repository.revision;
    _data = null;
    error = null;
    _revision = revision;
    if (!_repository.hasSession) {
      loading = false;
      notifyListeners();
      return;
    }
    loading = true;
    notifyListeners();
    try {
      final value = await _repository.load(this.range);
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
