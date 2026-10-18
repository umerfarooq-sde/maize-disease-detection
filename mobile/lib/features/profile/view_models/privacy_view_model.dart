import 'package:flutter/foundation.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../data/models/deletion_request.dart';
import '../../../data/repositories/privacy_repository.dart';

class PrivacyViewModel extends ChangeNotifier {
  PrivacyViewModel(this._repository) : _revision = _repository.sessionRevision;
  final PrivacyRepository _repository;
  final int? _revision;
  DeletionRequest? _request;
  DeletionRequest? get request => signedIn ? _request : null;
  AppException? error;
  bool busy = false, loaded = false, _disposed = false;
  bool get signedIn =>
      !_disposed &&
      _repository.signedIn &&
      _repository.sessionRevision == _revision;
  Future<void> load() => _run(false);
  Future<void> submit() => _run(true);
  Future<void> _run(bool submit) async {
    if (!signedIn || busy || (submit && _request != null)) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final value = submit
          ? await _repository.submit()
          : await _repository.read();
      if (signedIn) {
        _request = value;
        loaded = true;
      }
    } on AppException catch (failure) {
      if (signedIn) error = failure;
    } catch (_) {
      if (signedIn) error = const AppException(AppErrorKind.network);
    } finally {
      if (!_disposed) {
        busy = false;
        if (!signedIn) {
          _request = null;
          error = null;
        }
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
