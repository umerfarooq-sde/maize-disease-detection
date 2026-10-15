import '../../core/network/api_client.dart';
import '../models/model_health.dart';

abstract interface class ModelHealthRepository {
  bool get hasSession;
  int? get revision;
  Future<AdminModelHealth> load();
}

class ApiModelHealthRepository implements ModelHealthRepository {
  const ApiModelHealthRepository(this._api);
  final ApiClient _api;
  @override
  bool get hasSession => _api.hasAuthenticatedSession;
  @override
  int? get revision => _api.sessionRevision;
  @override
  Future<AdminModelHealth> load() async => AdminModelHealth.fromJson(
    (await _api.get('admin/model-health', authenticated: true)).data,
  );
}
