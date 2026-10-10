import 'package:flutter/foundation.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../data/models/farmer_account.dart';
import '../../../data/repositories/farmer_session_repository.dart';

class FarmerSessionViewModel extends ChangeNotifier {
  FarmerSessionViewModel(this._repository) {
    _repository.tokens.addListener(_changed);
  }
  final FarmerSessionRepository _repository;
  FarmerAccount? get account => _repository.account;
  bool get signedIn => account != null;
  int get revision => _repository.tokens.revision;
  bool busy = false;
  AppException? error;
  bool _disposed = false;
  Future<void> signIn(String email, String password) =>
      _run(() => _repository.signIn(email, password));
  Future<void> signOut() => _run(_repository.signOut);
  Future<void> _run(Future<void> Function() action) async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    _changed();
    try {
      await action();
    } on AppException catch (failure) {
      if (!_disposed) error = failure;
    } catch (_) {
      if (!_disposed) error = const AppException(AppErrorKind.network);
    } finally {
      if (!_disposed) {
        busy = false;
        _changed();
      }
    }
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _repository.tokens.removeListener(_changed);
    super.dispose();
  }
}
