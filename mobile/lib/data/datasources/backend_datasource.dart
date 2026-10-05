import '../../core/exceptions/app_exception.dart';
import '../../core/network/api_client.dart';
import '../models/backend_health.dart';

class BackendDatasource {
  const BackendDatasource(this._api);
  final ApiClient _api;

  Future<BackendHealth> fetchHealth() async {
    final response = await _api.get('health', acceptedStatuses: const {503});
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const AppException(AppErrorKind.invalidResponse);
    }
    return BackendHealth.fromJson(data, response.statusCode);
  }
}
