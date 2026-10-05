import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/data/models/backend_health.dart';
import 'package:maizedoctor/data/repositories/backend_repository.dart';
import 'package:maizedoctor/features/home/view_models/home_view_model.dart';

class ControlledRepository implements BackendRepository {
  Completer<BackendHealth> result = Completer<BackendHealth>();
  int calls = 0;
  @override
  Future<BackendHealth> checkConnection() {
    calls++;
    return result.future;
  }
}

void main() {
  test(
    'connection intent reports loading/success and prevents duplicate requests',
    () async {
      final repository = ControlledRepository();
      final model = HomeViewModel(repository);
      addTearDown(model.dispose);
      final loading = <bool>[];
      model.addListener(() => loading.add(model.isLoading));
      expect(model.health, null);
      expect(repository.calls, 0);
      final request = model.checkConnection();
      await model.checkConnection();
      expect(repository.calls, 1);
      repository.result.complete(
        BackendHealth(isAvailable: true, checkedAt: DateTime.now()),
      );
      await request;
      expect(loading, [true, false]);
      expect(model.health!.isAvailable, true);
      expect(model.error, null);
    },
  );
  test('error is recoverable and retry clears failure', () async {
    final repository = ControlledRepository();
    final model = HomeViewModel(repository);
    addTearDown(model.dispose);
    var request = model.checkConnection();
    repository.result.completeError(const AppException(AppErrorKind.network));
    await request;
    expect(model.error!.kind, AppErrorKind.network);
    repository.result = Completer();
    request = model.checkConnection();
    expect(model.error, null);
    repository.result.complete(
      BackendHealth(isAvailable: false, checkedAt: DateTime.now()),
    );
    await request;
    expect(model.health!.isAvailable, false);
  });
  test(
    'unexpected repository failures become safe application errors',
    () async {
      final repository = ControlledRepository();
      final model = HomeViewModel(repository);
      addTearDown(model.dispose);
      final request = model.checkConnection();
      repository.result.completeError(StateError('private dependency details'));
      await request;
      expect(model.error!.kind, AppErrorKind.server);
      expect(model.error!.message, isNot(contains('private')));
    },
  );
  test('disposed feature does not notify or start more requests', () async {
    final repository = ControlledRepository();
    final model = HomeViewModel(repository);
    var notifications = 0;
    model.addListener(() {
      notifications++;
    });
    final request = model.checkConnection();
    model.dispose();
    repository.result.complete(
      BackendHealth(isAvailable: true, checkedAt: DateTime.now()),
    );
    await request;
    await model.checkConnection();
    expect(notifications, 1);
    expect(repository.calls, 1);
  });
}
