import 'package:flutter/foundation.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../data/models/admin_accounts.dart';
import '../../../data/repositories/admin_accounts_repository.dart';

class FarmerManagementViewModel extends ChangeNotifier {
  FarmerManagementViewModel(this._repository)
    : _revision = _repository.sessionRevision;
  final AdminAccountsRepository _repository;
  final int? _revision;
  bool busy = false, _disposed = false;
  List<ManagedFarmer> items = const [];
  String? nextCursor, status, email, message;
  AppException? error;
  bool get _valid =>
      !_disposed &&
      _repository.signedIn &&
      _repository.sessionRevision == _revision;
  Future<void> load({bool more = false}) async {
    if (!_valid || busy || (more && nextCursor == null)) return;
    busy = true;
    error = null;
    message = null;
    _changed();
    try {
      final page = await _repository.farmers(
        status: status,
        email: email,
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

  Future<void> filter(String? selectedStatus, String selectedEmail) async {
    if (!_valid || busy) return;
    status = selectedStatus;
    email = selectedEmail.trim().isEmpty ? null : selectedEmail.trim();
    items = const [];
    nextCursor = null;
    await load();
  }

  Future<void> changeStatus(ManagedFarmer farmer, String selectedStatus) async {
    if (!_valid || busy) return;
    busy = true;
    error = null;
    message = null;
    _changed();
    try {
      final updated = await _repository.changeStatus(farmer, selectedStatus);
      if (_valid) {
        items = List.unmodifiable(
          items
              .map((item) => item.id == updated.id ? updated : item)
              .where((item) => status == null || item.status == status),
        );
        message = 'Account status saved. Previous sessions were revoked.';
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
