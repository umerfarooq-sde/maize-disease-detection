import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/data/models/farmer_profile.dart';
import 'package:maizedoctor/features/profile/view_models/profile_view_model.dart';
import 'helpers.dart';

void main() {
  const draft = ProfileDraft('Saved farmer', 'Region', 'PK', '2.5');
  test(
    'profile loading/save suppression, persistent result and photo actions',
    () async {
      final repo = FakeProfileRepository()..pendingRead = Completer();
      final model = ProfileViewModel(repo);
      addTearDown(model.dispose);
      final loading = model.load();
      expect(model.loading, true);
      await model.load();
      expect(repo.reads, 1);
      repo.pendingRead!.complete(repo.saved);
      await loading;
      expect(model.data!.displayName, 'Fixture farmer');
      repo.pendingSave = Completer();
      final save = model.save(draft);
      await model.save(draft);
      expect(repo.writes, 1);
      repo.pendingSave!.complete(
        FarmerProfile.fromResponse(profileJson(name: 'Saved farmer')),
      );
      await save;
      expect(model.message, 'Your profile is saved.');
      expect(model.data!.displayName, 'Saved farmer');
      await model.choosePhoto();
      expect(model.photo, isNotNull);
      await model.uploadPhoto();
      expect(model.progress, 1);
      expect(model.photo, isNull);
      expect(model.data!.avatarUrl, isNotNull);
      await model.removePhoto();
      expect(model.data!.avatarUrl, isNull);
    },
  );
  for (final kind in [
    AppErrorKind.network,
    AppErrorKind.timeout,
    AppErrorKind.conflict,
    AppErrorKind.validation,
    AppErrorKind.server,
    AppErrorKind.invalidImage,
  ]) {
    test('profile $kind leaves safe failure and allows retry', () async {
      final repo = FakeProfileRepository();
      final model = ProfileViewModel(repo);
      addTearDown(model.dispose);
      await model.load();
      repo.failure = AppException(kind);
      await model.save(draft);
      expect(model.error!.kind, kind);
      expect(model.busy, false);
      expect(model.errorMessage, isNotEmpty);
      repo.failure = null;
      await model.save(draft);
      expect(model.error, isNull);
      expect(model.data!.displayName, 'Saved farmer');
    });
  }
  test(
    'guest, changed identity and disposed requests cannot expose a different farmer',
    () async {
      final guest = FakeProfileRepository()..signedIn = false;
      final guestModel = ProfileViewModel(guest);
      await guestModel.load();
      expect(guest.reads, 0);
      guestModel.dispose();
      final repo = FakeProfileRepository()..pendingRead = Completer();
      final model = ProfileViewModel(repo);
      final pending = model.load();
      repo.sessionRevision = 2;
      repo.pendingRead!.complete(repo.saved);
      await pending;
      expect(model.data, isNull);
      expect(model.signedIn, false);
      model.dispose();
      final disposedRepo = FakeProfileRepository()..pendingRead = Completer();
      final disposed = ProfileViewModel(disposedRepo);
      final late = disposed.load();
      disposed.dispose();
      disposedRepo.pendingRead!.complete(disposedRepo.saved);
      await late;
      expect(disposed.data, isNull);
    },
  );
}
