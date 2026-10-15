import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import '../../core/exceptions/app_exception.dart';
import '../../core/network/api_client.dart';

class PrivateImageRepository {
  PrivateImageRepository(this._api);
  final ApiClient _api;
  static const _concurrency = 2;
  static const _maximumWaiting = 32;
  int _active = 0;
  final _waiting = Queue<Completer<void>>();
  int? get sessionRevision => _api.sessionRevision;
  Future<Uint8List> read(String path, {String? anonymousKey}) async {
    final revision = sessionRevision;
    if (_active >= _concurrency) {
      if (_waiting.length >= _maximumWaiting) {
        throw const AppException(AppErrorKind.rateLimited);
      }
      final ready = Completer<void>();
      _waiting.add(ready);
      await ready.future;
    } else {
      _active++;
    }
    try {
      if (revision != sessionRevision) {
        throw const AppException(AppErrorKind.authentication);
      }
      return await _api.readPrivateImage(path, anonymousKey: anonymousKey);
    } finally {
      // Transfer this slot directly to the oldest waiter, without a race in
      // which a new thumbnail could take its place and exceed the server limit.
      if (_waiting.isEmpty) {
        _active--;
      } else {
        _waiting.removeFirst().complete();
      }
    }
  }
}
