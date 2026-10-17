import 'package:flutter/foundation.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../data/models/reference_media.dart';
import '../../../data/models/selected_leaf_image.dart';
import '../../../data/repositories/reference_media_repository.dart';

class ReferenceGalleryViewModel extends ChangeNotifier {
  ReferenceGalleryViewModel(this.repository, this.slug)
    : _revision = repository.revision;
  final ReferenceMediaRepository repository;
  int? _revision;
  String slug;
  List<ReferenceMedia> items = const [];
  SelectedLeafImage? selected;
  ReferenceMedia? editing;
  AppException? error;
  bool busy = false, _disposed = false;
  bool get valid =>
      !_disposed && repository.enabled && repository.revision == _revision;
  void _clearSessionState() {
    items = const [];
    selected = null;
    editing = null;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_disposed || busy) return;
    if (!valid) {
      _clearSessionState();
      error = const AppException(AppErrorKind.authentication);
      notifyListeners();
      return;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } on AppException catch (e) {
      if (valid) error = e;
    } catch (_) {
      if (valid) error = const AppException(AppErrorKind.server);
    } finally {
      if (!_disposed) {
        busy = false;
        if (!valid) {
          _clearSessionState();
          error = const AppException(AppErrorKind.authentication);
        }
        notifyListeners();
      }
    }
  }

  Future<void> load() {
    if (!_disposed && !busy && repository.revision != _revision) {
      _revision = repository.revision;
      _clearSessionState();
    }
    return _run(() async {
      items = const [];
      final rows = await repository.list(slug);
      if (valid) items = rows;
    });
  }

  Future<void> choose() => _run(() async {
    final image = await repository.choose();
    if (valid) selected = image;
  });
  void edit(ReferenceMedia? value) {
    if (valid && !busy) {
      editing = value;
      selected = null;
      notifyListeners();
    }
  }

  Future<void> save(Map<String, Object?> metadata) => _run(() async {
    final old = editing, image = selected;
    if (image != null) {
      await repository.upload(image, {
        'diseaseSlug': slug,
        ...metadata,
        if (old != null) 'replacementFor': old.id,
      });
    } else if (old != null) {
      await repository.edit(old, metadata);
    } else {
      throw const AppException(AppErrorKind.validation);
    }
    final rows = await repository.list(slug);
    if (valid) {
      items = rows;
      selected = null;
      editing = null;
    }
  });
  Future<void> status(ReferenceMedia row, String status, String note) =>
      _run(() async {
        await repository.status(row, status, note);
        final rows = await repository.list(slug);
        if (valid) items = rows;
      });
  @override
  void dispose() {
    _disposed = true;
    _clearSessionState();
    super.dispose();
  }
}
