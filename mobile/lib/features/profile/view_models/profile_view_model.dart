import 'package:flutter/foundation.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../data/models/farmer_profile.dart';
import '../../../data/models/selected_leaf_image.dart';
import '../../../data/repositories/profile_repository.dart';

class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel(this._repository) : _revision = _repository.sessionRevision;
  final ProfileRepository _repository;
  final int? _revision;
  FarmerProfile? data;
  SelectedLeafImage? photo;
  AppException? error;
  String? message;
  bool loading = false, busy = false, loaded = false, _disposed = false;
  double progress = 0;
  bool _uncertainPhotoOutcome = false;
  bool get signedIn => _valid;
  bool get _valid =>
      !_disposed &&
      _repository.signedIn &&
      _repository.sessionRevision == _revision;
  String? get errorMessage {
    if (_uncertainPhotoOutcome) {
      return 'The connection ended before the photo update could be confirmed. Reload your saved profile and review the current photo before trying again.';
    }
    return switch (error?.kind) {
      null => null,
      AppErrorKind.conflict =>
        'Your saved profile changed. Reload it and review your changes before trying again.',
      AppErrorKind.invalidImage =>
        'Choose a valid still JPEG, PNG or WebP profile photo, at least 16 pixels on each side.',
      AppErrorKind.imageTooLarge =>
        'Choose a profile photo up to 5 MB and 16 megapixels.',
      AppErrorKind.imageAccess =>
        'We could not open your photos. Check permissions and try again.',
      _ => error!.message,
    };
  }

  Future<void> load() async {
    if (!_valid || busy || loading) return;
    loading = true;
    error = null;
    message = null;
    _changed();
    try {
      final result = await _repository.read();
      if (_valid) {
        data = result;
        loaded = true;
        _uncertainPhotoOutcome = false;
      }
    } on AppException catch (failure) {
      if (_valid) error = failure;
    } catch (_) {
      if (_valid) error = const AppException(AppErrorKind.network);
    } finally {
      if (_valid) {
        loading = false;
        _changed();
      }
    }
  }

  Future<void> _run(
    Future<void> Function() action,
    String? success, {
    bool reconcilePhoto = false,
  }) async {
    if (!_valid || loading || busy) return;
    busy = true;
    error = null;
    message = null;
    _changed();
    try {
      await action();
      if (_valid) message = success;
    } on AppException catch (failure) {
      if (_valid) {
        error = failure;
        if (reconcilePhoto &&
            [
              AppErrorKind.network,
              AppErrorKind.timeout,
              AppErrorKind.server,
            ].contains(failure.kind)) {
          _uncertainPhotoOutcome = true;
          photo = null;
          try {
            final current = await _repository.read();
            if (_valid) {
              data = current;
              _uncertainPhotoOutcome = false;
              error = const AppException(AppErrorKind.conflict);
            }
          } on Object {
            // Keep uncertainty explicit; never repeat the original mutation.
          }
        }
      }
    } catch (_) {
      if (_valid) error = const AppException(AppErrorKind.network);
    } finally {
      if (_valid) {
        busy = false;
        _changed();
      }
    }
  }

  Future<void> save(ProfileDraft draft) => _run(() async {
    final result = await _repository.save(draft, data?.revision);
    if (_valid) data = result;
  }, 'Your profile is saved.');
  Future<void> choosePhoto() => _run(() async {
    final result = await _repository.choosePhoto();
    if (_valid && result != null) photo = result;
  }, null);
  void clearPhoto() {
    if (_valid && !busy) {
      photo = null;
      _changed();
    }
  }

  Future<void> uploadPhoto() => _run(
    () async {
      final selected = photo, current = data;
      if (selected == null || current == null) {
        throw const AppException(AppErrorKind.validation);
      }
      progress = 0;
      final result = await _repository.uploadPhoto(selected, current.revision, (
        value,
      ) {
        if (_valid) {
          progress = value;
          _changed();
        }
      });
      if (_valid) {
        data = result;
        photo = null;
      }
    },
    'Your profile photo is saved.',
    reconcilePhoto: true,
  );
  Future<void> removePhoto() => _run(
    () async {
      final current = data;
      if (current == null) throw const AppException(AppErrorKind.validation);
      final result = await _repository.removePhoto(current.revision);
      if (_valid) {
        data = result;
        photo = null;
      }
    },
    'Your profile photo was removed.',
    reconcilePhoto: true,
  );
  void _changed() {
    if (_valid) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    data = null;
    photo = null;
    super.dispose();
  }
}
