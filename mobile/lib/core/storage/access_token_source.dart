/// Implement with platform secure storage when mobile authentication is added.
/// This foundation does not persist tokens or provide a plaintext fallback.
abstract interface class AccessTokenSource {
  Future<String?> readAccessToken();
}
