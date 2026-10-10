import '../../core/exceptions/app_exception.dart';

class FarmerAccount {
  const FarmerAccount({required this.email, required this.createdAt});
  final String email;
  final DateTime createdAt;
  static FarmerAccount fromJson(Object? value) {
    if (value is! Map<String, dynamic> || value['role'] != 'FARMER') {
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
    return FarmerAccount(email: email, createdAt: DateTime.parse(created));
  }
}
