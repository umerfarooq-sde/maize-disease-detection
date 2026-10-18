import '../../core/exceptions/app_exception.dart';
import '../../core/network/api_client.dart';
import '../models/deletion_request.dart';

abstract interface class PrivacyRepository {
  bool get signedIn;
  int? get sessionRevision;
  Future<DeletionRequest?> read();
  Future<DeletionRequest> submit();
}

class ApiPrivacyRepository implements PrivacyRepository {
  ApiPrivacyRepository(this._api);
  final ApiClient _api;
  @override
  bool get signedIn => _api.hasAuthenticatedSession;
  @override
  int? get sessionRevision => _api.sessionRevision;
  @override
  Future<DeletionRequest?> read() async => DeletionRequest.fromResponse(
    (await _api.get('profile/data-deletion', authenticated: true)).data,
  );
  @override
  Future<DeletionRequest> submit() async {
    try {
      return DeletionRequest.fromResponse(
            (await _api.request(
              ApiMethod.post,
              'profile/data-deletion',
              authenticated: true,
              body: const {},
            )).data,
          ) ??
          (throw const AppException(AppErrorKind.invalidResponse));
    } on AppException catch (error) {
      if (![
        AppErrorKind.network,
        AppErrorKind.timeout,
        AppErrorKind.server,
      ].contains(error.kind)) {
        rethrow;
      }
      // A timed-out request may have committed. Reconcile once; do not assume
      // a failed response means no request was saved.
      final saved = await read();
      if (saved != null) return saved;
      rethrow;
    }
  }
}
