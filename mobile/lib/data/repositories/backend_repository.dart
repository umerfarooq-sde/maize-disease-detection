import '../datasources/backend_datasource.dart';
import '../models/backend_health.dart';

abstract interface class BackendRepository {
  Future<BackendHealth> checkConnection();
}

class ApiBackendRepository implements BackendRepository {
  const ApiBackendRepository(this._source);
  final BackendDatasource _source;
  @override
  Future<BackendHealth> checkConnection() => _source.fetchHealth();
}
