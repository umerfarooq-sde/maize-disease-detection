import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../data/datasources/leaf_image_datasource.dart';
import '../../../data/models/scan_record.dart';
import '../../../data/models/selected_leaf_image.dart';
import '../../../data/repositories/scan_repository.dart';
import '../../../data/repositories/scan_records_repository.dart';
import '../utils/scan_polling.dart';
import 'scan_result_arguments.dart';

class ScanViewModel extends ChangeNotifier {
  ScanViewModel(
    this._repository, {
    ScanRecordsRepository? records,
    this.pollInterval = const Duration(seconds: 2),
    this.maxPollAttempts = 6,
  }) : _records = records;
  final ScanRepository _repository;
  final ScanRecordsRepository? _records;
  final Duration pollInterval;
  final int maxPollAttempts;
  SelectedLeafImage? image;
  ScanRecord? scan;
  AppException? error;
  bool selecting = false;
  bool uploading = false;
  bool polling = false;
  double progress = 0;
  String? _requestKey;
  bool _disposed = false;
  LeafImageSource? _lastSource;
  bool _uploadFailed = false;
  int _generation = 0;
  bool get busy => selecting || uploading || polling;
  bool get cameraSupported => _repository.cameraSupported;
  bool get analysisFailed => scan?.status == ScanStatus.failed;
  ScanResultArguments? get resultArguments => scan == null
      ? null
      : ScanResultArguments(
          scan: scan!,
          selectedImage: image,
          requestKey: _requestKey,
        );

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
        _generation++;
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
    if (busy ||
        _disposed ||
        selected == null ||
        key == null ||
        (scan != null && !analysisFailed)) {
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
        _uploadFailed = result.status == ScanStatus.failed;
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
    if (!_disposed &&
        scan != null &&
        analysisPending(scan!) &&
        _records != null) {
      await refreshAnalysis();
    }
  }

  Future<void> refreshAnalysis() async {
    final current = scan;
    final records = _records;
    if (busy ||
        _disposed ||
        current == null ||
        records == null ||
        !analysisPending(current)) {
      return;
    }
    final generation = _generation;
    bool active() => !_disposed && generation == _generation;
    polling = true;
    error = null;
    _notify();
    try {
      await pollScanAnalysis(
        records,
        current,
        anonymousKey: _requestKey,
        interval: pollInterval,
        maxAttempts: maxPollAttempts,
        isActive: active,
        onUpdate: (updated) {
          scan = updated;
          _uploadFailed = updated.status == ScanStatus.failed;
          _notify();
        },
      );
    } on AppException catch (failure) {
      if (active()) error = failure;
    } catch (_) {
      if (active()) error = const AppException(AppErrorKind.network);
    } finally {
      if (active()) {
        polling = false;
        _notify();
      }
    }
  }

  Future<void> retry() =>
      scan != null && analysisPending(scan!) && _records != null
      ? refreshAnalysis()
      : _uploadFailed
      ? upload()
      : _select(_lastSource);
  void clear() {
    if (selecting || uploading || _disposed) return;
    _generation++;
    polling = false;
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
    _generation++;
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
