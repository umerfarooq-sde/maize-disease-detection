/// Authentication credentials stay in memory for the current app session.
/// Persistent sign-in would require a platform secure-storage implementation.
abstract interface class AccessTokenSource {
  Future<String?> readAccessToken();
}

/// Identity revision lets transports discard responses from a previous session.
abstract interface class SessionTokenSource implements AccessTokenSource {
  bool get hasSession;
  int get revision;
  void invalidate();
}
