import 'package:flutter/foundation.dart';
import '../exceptions/app_exception.dart';
import '../../data/repositories/private_image_repository.dart';

class PrivateImageViewModel extends ChangeNotifier {
  PrivateImageViewModel(this._repository, this.path, this.anonymousKey);
  final PrivateImageRepository _repository;
  final String path;
  final String? anonymousKey;
  Uint8List? bytes;
  bool loading = false;
  bool _disposed = false;
  AppErrorKind? failureKind;
  String get failureMessage => switch (failureKind) {
    AppErrorKind.network => 'Check your connection and retry the photo.',
    AppErrorKind.timeout => 'The photo request timed out. Please retry.',
    AppErrorKind.authentication => 'Sign in again to view this photo.',
    AppErrorKind.authorization => 'You do not have access to this photo.',
    AppErrorKind.notFound => 'This photo is no longer available.',
    _ => 'The photo could not be loaded. Please retry.',
  };
  Future<void> load() async {
    if (_disposed || loading) return;
    final revision = _repository.sessionRevision;
    loading = true;
    bytes = null;
    failureKind = null;
    notifyListeners();
    try {
      final result = await _repository.read(path, anonymousKey: anonymousKey);
      if (!_disposed && revision == _repository.sessionRevision) bytes = result;
    } on AppException catch (failure) {
      if (!_disposed && revision == _repository.sessionRevision) {
        failureKind = failure.kind;
      }
    } catch (_) {
      // An unknown error stays generic. Never retain transport details.
    } finally {
      if (!_disposed) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    bytes = null;
    super.dispose();
  }
}
