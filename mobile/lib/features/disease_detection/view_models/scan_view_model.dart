import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../data/datasources/leaf_image_datasource.dart';
import '../../../data/models/scan_record.dart';
import '../../../data/models/selected_leaf_image.dart';
import '../../../data/repositories/scan_repository.dart';

class ScanViewModel extends ChangeNotifier {
  ScanViewModel(this._repository);
  final ScanRepository _repository;
  SelectedLeafImage? image;
  ScanRecord? scan;
  AppException? error;
  bool selecting = false;
  bool uploading = false;
  double progress = 0;
  String? _requestKey;
  bool _disposed = false;
  LeafImageSource? _lastSource;
  bool _uploadFailed = false;
  bool get busy => selecting || uploading;
  bool get cameraSupported => _repository.cameraSupported;

  Future<void> recoverSelection() => _select(null);
  Future<void> select(LeafImageSource source) => _select(source);
  Future<void> _select(LeafImageSource? source) async {
    if (busy || _disposed) return;
    selecting = true;
    error = null;
    _uploadFailed = false;
    _lastSource = source;
    _notify();
    try {
      final selected = source == null
          ? await _repository.recoverSelection()
          : await _repository.select(source);
      if (_disposed) return;
      if (selected != null) {
        image = selected;
        scan = null;
        _requestKey = _newKey();
        progress = 0;
      }
    } on AppException catch (failure) {
      if (!_disposed) error = failure;
    } catch (_) {
      if (!_disposed) error = const AppException(AppErrorKind.imageAccess);
    } finally {
      if (!_disposed) {
        selecting = false;
        _notify();
      }
    }
  }

  Future<void> upload() async {
    final selected = image;
    final key = _requestKey;
    if (busy || _disposed || selected == null || key == null || scan != null) {
      return;
    }
    uploading = true;
    progress = 0;
    error = null;
    _uploadFailed = true;
    _notify();
    try {
      final result = await _repository.upload(selected, key, (value) {
        if (!_disposed && uploading) {
          progress = value.clamp(progress, 1);
          _notify();
        }
      });
      if (!_disposed) {
        scan = result;
        _uploadFailed = false;
      }
    } on AppException catch (failure) {
      if (!_disposed) error = failure;
    } catch (_) {
      if (!_disposed) error = const AppException(AppErrorKind.network);
    } finally {
      if (!_disposed) {
        uploading = false;
        _notify();
      }
    }
  }

  Future<void> retry() => _uploadFailed ? upload() : _select(_lastSource);
  void clear() {
    if (busy || _disposed) return;
    image = null;
    scan = null;
    error = null;
    _requestKey = null;
    progress = 0;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  static String _newKey() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
