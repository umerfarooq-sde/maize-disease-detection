import '../../core/exceptions/app_exception.dart';
import '../../core/network/api_client.dart';
import '../models/registration_credentials.dart';
import '../models/session_account.dart';

abstract interface class RegistrationRepository {
  Future<SessionAccount> register(String email, String password);
}

/// Enrollment returns a safe account projection, never a session grant.
class ApiRegistrationRepository implements RegistrationRepository {
  const ApiRegistrationRepository(this._api);
  final ApiClient _api;

  @override
  Future<SessionAccount> register(String email, String password) async {
    if (RegistrationCredentials.emailError(email) != null ||
        RegistrationCredentials.passwordError(password) != null) {
      throw const AppException(AppErrorKind.validation);
    }
    final normalized = RegistrationCredentials.normalizeEmail(email);
    final response = await _api.request(
      ApiMethod.post,
      'auth/register',
      body: {'email': normalized, 'password': password},
    );
    final data = response.data;
    if (response.statusCode != 201 ||
        data is! Map<String, dynamic> ||
        data.length != 1 ||
        !data.containsKey('user')) {
      throw const AppException(AppErrorKind.invalidResponse);
    }
    final user = SessionAccount.fromJson(data['user']);
    if (user.email != normalized) {
      throw const AppException(AppErrorKind.invalidResponse);
    }
    return user;
  }
}
