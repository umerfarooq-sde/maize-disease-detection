import 'package:flutter/foundation.dart';
import '../../data/repositories/private_image_repository.dart';

class PrivateImageViewModel extends ChangeNotifier {
  PrivateImageViewModel(this._repository, this.path, this.anonymousKey);
  final PrivateImageRepository _repository;
  final String path;
  final String? anonymousKey;
  Uint8List? bytes;
  bool loading = false;
  bool _disposed = false;
  Future<void> load() async {
    if (_disposed || loading) return;
    final revision = _repository.sessionRevision;
    loading = true;
    bytes = null;
    notifyListeners();
    try {
      final result = await _repository.read(path, anonymousKey: anonymousKey);
      if (!_disposed && revision == _repository.sessionRevision) bytes = result;
    } catch (_) {
      // Raw image URLs, capabilities and transport exceptions are never retained.
    } finally {
      if (!_disposed) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    bytes = null;
    super.dispose();
  }
}
