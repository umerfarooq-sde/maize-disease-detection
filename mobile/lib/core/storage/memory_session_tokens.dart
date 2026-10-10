import 'package:flutter/foundation.dart';
import 'access_token_source.dart';

/// Volatile credentials only: no preferences, files, logs or plaintext fallback.
class MemorySessionTokens extends ChangeNotifier implements SessionTokenSource {
  String? _access;
  DateTime? _expiresAt;
  int _revision = 0;
  Future<String?> Function()? renew;
  @override
  bool get hasSession => _access != null;
  @override
  int get revision => _revision;

  void save(String access, Duration lifetime) {
    final newIdentity = !hasSession;
    _access = access;
    _expiresAt = DateTime.now().add(lifetime);
    if (newIdentity) {
      _revision++;
      notifyListeners();
    }
  }

  @override
  Future<String?> readAccessToken() async {
    if (!hasSession) return null;
    if (_expiresAt!.isAfter(DateTime.now().add(const Duration(seconds: 30)))) {
      return _access;
    }
    return renew == null ? null : await renew!();
  }

  @override
  void invalidate() {
    if (!hasSession) return;
    _access = null;
    _expiresAt = null;
    _revision++;
    notifyListeners();
  }

  @override
  void dispose() {
    renew = null;
    _access = null;
    _expiresAt = null;
    super.dispose();
  }
}
