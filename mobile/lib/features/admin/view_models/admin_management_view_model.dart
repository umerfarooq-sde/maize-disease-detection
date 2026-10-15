import 'package:flutter/foundation.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../data/models/admin_management.dart';
import '../../../data/repositories/admin_management_repository.dart';

class AdminManagementViewModel extends ChangeNotifier {
  AdminManagementViewModel(this._repository);
  final AdminManagementRepository _repository;
  ManagementArea area = ManagementArea.knowledge;
  List<ManagementEntry> _items = const [];
  int? _revision;
  int _generation = 0;
  bool _disposed = false;
  bool busy = false;
  AppException? error;
  String? nextCursor;
  ManagementEditor? _editor;
  bool get _sameSession =>
      _repository.hasSession && _revision == _repository.revision;
  List<ManagementEntry> get items => _sameSession ? _items : const [];
  ManagementEditor? get editor => _sameSession ? _editor : null;
  bool _current(int generation, int? revision) =>
      !_disposed &&
      generation == _generation &&
      _repository.hasSession &&
      revision == _repository.revision;
  Future<void> select(ManagementArea value) async {
    if (busy) return;
    area = value;
    _editor = null;
    await load();
  }

  Future<void> refresh() async {
    if (busy) return;
    _editor = null;
    await load();
  }

  Future<void> load({bool more = false}) async {
    if (_disposed || (more && (busy || nextCursor == null))) return;
    final generation = ++_generation, revision = _repository.revision;
    if (_revision != revision) _editor = null;
    _revision = revision;
    busy = true;
    error = null;
    if (!more) {
      _items = const [];
      nextCursor = null;
    }
    if (!_repository.hasSession) {
      busy = false;
      _editor = null;
      _items = const [];
      _notify();
      return;
    }
    _notify();
    try {
      final page = await _repository.list(
        area,
        cursor: more ? nextCursor : null,
      );
      if (!_current(generation, revision)) return;
      final ids = <String>{};
      _items = List.unmodifiable(
        [if (more) ..._items, ...page.items].where((item) => ids.add(item.id)),
      );
      if (page.nextCursor == nextCursor && more && page.nextCursor != null) {
        throw const AppException(AppErrorKind.invalidResponse);
      }
      nextCursor = page.nextCursor;
    } on AppException catch (failure) {
      if (_current(generation, revision)) error = failure;
    } catch (_) {
      if (_current(generation, revision)) {
        error = const AppException(AppErrorKind.server);
      }
    } finally {
      if (_current(generation, revision)) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> edit([ManagementEntry? item]) async {
    if (busy || _disposed) return;
    if (area == ManagementArea.knowledge && item != null) {
      final revision = _repository.revision;
      await _mutation(() async {
        final detail = await _repository.document(item.id);
        if (!_disposed &&
            _repository.hasSession &&
            _repository.revision == revision) {
          _editor = ManagementEditor(
            area,
            detail,
            managementEditorValues(area, detail),
          );
        }
      }, reload: false);
    } else {
      _revision = _repository.revision;
      _editor = ManagementEditor(
        area,
        item,
        managementEditorValues(area, item),
      );
      error = null;
      _notify();
    }
  }

  void cancel() {
    if (busy) return;
    _editor = null;
    error = null;
    _notify();
  }

  Future<void> save(Map<String, String> fields) async {
    final editing = editor;
    if (editing == null || busy) return;
    await _mutation(() async {
      await _repository.save(editing, managementWrite(editing, fields));
      if (!_disposed) _editor = null;
    });
  }

  Future<void> index(ManagementEntry item) =>
      _mutation(() => _repository.index(item.id));
  Future<void> status(ManagementEntry item, String status) =>
      _mutation(() => _repository.status(area, item, status));
  Future<void> _mutation(
    Future<void> Function() operation, {
    bool reload = true,
  }) async {
    if (_disposed || busy || !_repository.hasSession) return;
    final generation = ++_generation, revision = _repository.revision;
    _revision = revision;
    busy = true;
    error = null;
    _notify();
    try {
      await operation();
      if (_current(generation, revision)) {
        busy = false;
        if (reload) {
          await load();
        }
      }
    } on AppException catch (failure) {
      if (_current(generation, revision)) error = failure;
    } catch (_) {
      if (_current(generation, revision)) {
        error = const AppException(AppErrorKind.server);
      }
    } finally {
      if (_current(generation, revision)) {
        busy = false;
        _notify();
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _items = const [];
    _editor = null;
    super.dispose();
  }
}
