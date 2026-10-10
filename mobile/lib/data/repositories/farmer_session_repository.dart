import '../../core/exceptions/app_exception.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/memory_session_tokens.dart';
import '../models/farmer_account.dart';

class FarmerSessionRepository {
  FarmerSessionRepository(this._api, this.tokens) {
    tokens.renew = _refresh;
  }
  final ApiClient _api;
  final MemorySessionTokens tokens;
  FarmerAccount? _account;
  Future<String?>? _refreshing;
  FarmerAccount? get account => tokens.hasSession ? _account : null;

  Future<void> signIn(String email, String password) async {
    final normalized = email.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normalized) ||
        normalized.length > 254 ||
        password.isEmpty ||
        password.runes.length > 128) {
      throw const AppException(AppErrorKind.validation);
    }
    try {
      final response = await _api.request(
        ApiMethod.post,
        'auth/login',
        body: {'email': normalized, 'password': password},
      );
      _acceptGrant(response.data);
    } catch (_) {
      // An admin or malformed grant must not leave a newly issued refresh session.
      if (_api.hasRefreshCookie) {
        try {
          await _api.request(ApiMethod.post, 'auth/logout');
        } catch (_) {}
      }
      clear();
      rethrow;
    }
  }

  String _acceptGrant(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const AppException(AppErrorKind.invalidResponse);
    }
    final token = value['accessToken'];
    final expires = value['expiresIn'];
    if (token is! String ||
        token.length > 4096 ||
        !RegExp(
          r'^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$',
        ).hasMatch(token) ||
        value['tokenType'] != 'Bearer' ||
        expires is! int ||
        expires <= 0 ||
        expires > 86400 ||
        !_api.hasRefreshCookie) {
      throw const AppException(AppErrorKind.invalidResponse);
    }
    final account = FarmerAccount.fromJson(value['user']);
    if (this.account != null && this.account!.email != account.email) {
      throw const AppException(AppErrorKind.authentication);
    }
    _account = account;
    tokens.save(token, Duration(seconds: expires));
    return token;
  }

  Future<String?> _refresh() {
    if (_refreshing != null) return _refreshing!;
    final revision = tokens.revision;
    _refreshing = () async {
      try {
        final response = await _api.request(ApiMethod.post, 'auth/refresh');
        if (!tokens.hasSession || tokens.revision != revision) {
          throw const AppException(AppErrorKind.authentication);
        }
        return _acceptGrant(response.data);
      } on AppException catch (error) {
        if (tokens.revision == revision &&
            (error.kind == AppErrorKind.authentication ||
                error.kind == AppErrorKind.authorization ||
                error.kind == AppErrorKind.invalidResponse)) {
          clear();
        }
        rethrow;
      } finally {
        _refreshing = null;
      }
    }();
    return _refreshing!;
  }

  Future<void> signOut() async {
    try {
      if (_api.hasRefreshCookie) {
        await _api.request(ApiMethod.post, 'auth/logout');
      }
    } on AppException catch (error) {
      if (error.kind != AppErrorKind.authentication) rethrow;
    } finally {
      clear();
    }
  }

  void clear() {
    _account = null;
    _api.clearSessionCredentials();
    tokens.invalidate();
  }
}
