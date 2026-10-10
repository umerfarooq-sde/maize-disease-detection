import 'package:flutter/foundation.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../data/models/scan_record.dart';
import '../../../data/models/selected_leaf_image.dart';
import '../../../data/repositories/scan_records_repository.dart';
import '../../../data/repositories/scan_repository.dart';
import '../utils/scan_polling.dart';
import 'scan_result_arguments.dart';

class ScanResultViewModel extends ChangeNotifier {
  ScanResultViewModel(
    this._records, {
    required this.scanId,
    ScanRepository? uploads,
    ScanResultArguments? initial,
    this.pollInterval = const Duration(seconds: 2),
    this.maxPollAttempts = 6,
  }) : _uploads = uploads,
       _initial = initial {
    if (initial != null && initial.scan.id != scanId) {
      error = const AppException(AppErrorKind.invalidResponse);
    } else {
      scan = initial?.scan;
    }
  }
  final ScanRecordsRepository _records;
  final ScanRepository? _uploads;
  final ScanResultArguments? _initial;
  final String scanId;
  final Duration pollInterval;
  final int maxPollAttempts;
  ScanRecord? scan;
  AppException? error;
  bool loading = false;
  bool uploading = false;
  double progress = 0;
  bool _disposed = false;
  int _generation = 0;
  bool get busy => loading || uploading;
  SelectedLeafImage? get selectedImage => _initial?.selectedImage;
  bool get canRetryAnalysis =>
      scan?.status == ScanStatus.failed &&
      _uploads != null &&
      _initial?.selectedImage != null &&
      _initial?.requestKey != null;

  Future<void> load() async {
    if (scan != null && !analysisPending(scan!)) return;
    await refresh();
  }

  Future<void> refresh() async {
    if (busy || _disposed || (_initial != null && _initial.scan.id != scanId)) {
      return;
    }
    final generation = _generation;
    bool active() => !_disposed && generation == _generation;
    loading = true;
    error = null;
    _notify();
    try {
      final updated = await _records.read(
        scanId,
        anonymousKey: _initial?.requestKey,
      );
      if (!active()) return;
      if (updated.id != scanId) {
        throw const AppException(AppErrorKind.invalidResponse);
      }
      scan = updated;
      _notify();
      if (analysisPending(updated)) {
        await pollScanAnalysis(
          _records,
          updated,
          anonymousKey: _initial?.requestKey,
          interval: pollInterval,
          maxAttempts: maxPollAttempts,
          isActive: active,
          onUpdate: (updated) {
            scan = updated;
            _notify();
          },
        );
      }
    } on AppException catch (failure) {
      if (active()) error = failure;
    } catch (_) {
      if (active()) error = const AppException(AppErrorKind.network);
    } finally {
      if (active()) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> retryAnalysis() async {
    if (busy || _disposed || !canRetryAnalysis) return;
    final generation = _generation;
    bool active() => !_disposed && generation == _generation;
    uploading = true;
    error = null;
    progress = 0;
    _notify();
    try {
      final result = await _uploads!.upload(
        _initial!.selectedImage!,
        _initial.requestKey!,
        (value) {
          if (active()) {
            progress = value.clamp(progress, 1);
            _notify();
          }
        },
      );
      if (result.id != scanId) {
        throw const AppException(AppErrorKind.invalidResponse);
      }
      if (active()) scan = result;
    } on AppException catch (failure) {
      if (active()) error = failure;
    } catch (_) {
      if (active()) error = const AppException(AppErrorKind.network);
    } finally {
      if (active()) {
        uploading = false;
        _notify();
      }
    }
    if (active() && scan != null && analysisPending(scan!)) await refresh();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
