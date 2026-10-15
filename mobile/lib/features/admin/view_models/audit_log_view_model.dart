import 'package:flutter/foundation.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../data/models/admin_accounts.dart';
import '../../../data/repositories/admin_accounts_repository.dart';

class AuditLogViewModel extends ChangeNotifier {
  AuditLogViewModel(this._repository) : _revision = _repository.sessionRevision;
  final AdminAccountsRepository _repository;
  final int? _revision;
  bool busy = false, _disposed = false;
  List<AdminAuditEntry> items = const [];
  String? nextCursor, action, entityType, actorId, from, to;
  AppException? error;
  bool get _valid =>
      !_disposed &&
      _repository.signedIn &&
      _repository.sessionRevision == _revision;
  Future<void> load({bool more = false}) async {
    if (!_valid || busy || (more && nextCursor == null)) return;
    busy = true;
    error = null;
    _changed();
    try {
      final page = await _repository.audits(
        action: action,
        entityType: entityType,
        actorId: actorId,
        from: from,
        to: to,
        cursor: more ? nextCursor : null,
      );
      if (_valid) {
        items = List.unmodifiable(
          more ? [...items, ...page.items] : page.items,
        );
        nextCursor = page.nextCursor;
      }
    } on AppException catch (failure) {
      if (_valid) error = failure;
    } catch (_) {
      if (_valid) error = const AppException(AppErrorKind.network);
    } finally {
      if (_valid) {
        busy = false;
        _changed();
      }
    }
  }

  Future<void> filter({
    String? selectedAction,
    String? selectedEntity,
    String actor = '',
    String start = '',
    String end = '',
  }) async {
    if (!_valid || busy) return;
    action = selectedAction;
    entityType = selectedEntity;
    actorId = actor.trim().isEmpty ? null : actor.trim();
    from = start.trim().isEmpty ? null : start.trim();
    to = end.trim().isEmpty ? null : end.trim();
    items = const [];
    nextCursor = null;
    await load();
  }

  void _changed() {
    if (_valid) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    items = const [];
    super.dispose();
  }
}
