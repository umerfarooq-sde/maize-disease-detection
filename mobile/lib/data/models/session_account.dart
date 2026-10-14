import '../../core/exceptions/app_exception.dart';

enum AccountRole { farmer, admin }

class SessionAccount {
  const SessionAccount({
    required this.email,
    required this.createdAt,
    this.role = AccountRole.farmer,
  });
  final AccountRole role;
  final String email;
  final DateTime createdAt;
  static SessionAccount fromJson(
    Object? value, {
    AccountRole requiredRole = AccountRole.farmer,
  }) {
    if (value is! Map<String, dynamic> ||
        value['role'] != requiredRole.name.toUpperCase()) {
      throw const AppException(AppErrorKind.authorization);
    }
    final email = value['email'];
    final created = value['createdAt'];
    if (email is! String ||
        email.length > 254 ||
        !email.contains('@') ||
        created is! String ||
        DateTime.tryParse(created) == null) {
      throw const AppException(AppErrorKind.invalidResponse);
    }
    return SessionAccount(
      email: email,
      createdAt: DateTime.parse(created),
      role: requiredRole,
    );
  }
}
