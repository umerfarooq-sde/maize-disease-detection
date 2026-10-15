import 'package:flutter/foundation.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../data/repositories/registration_repository.dart';

class RegistrationViewModel extends ChangeNotifier {
  RegistrationViewModel(this._repository);
  final RegistrationRepository _repository;
  bool busy = false;
  bool _disposed = false;
  String? registeredEmail;
  AppException? error;

  String? get errorMessage => switch (error?.kind) {
    null => null,
    AppErrorKind.conflict =>
      'An account already uses this email. Sign in, or use a different email.',
    AppErrorKind.validation =>
      'Check your email and use a password with 15–128 characters.',
    _ => error!.message,
  };

  Future<void> register(String email, String password) async {
    if (busy || _disposed || registeredEmail != null) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final user = await _repository.register(email, password);
      if (!_disposed) registeredEmail = user.email;
    } on AppException catch (failure) {
      if (!_disposed) error = failure;
    } catch (_) {
      if (!_disposed) error = const AppException(AppErrorKind.network);
    } finally {
      if (!_disposed) {
        busy = false;
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
