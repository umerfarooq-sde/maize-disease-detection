import '../../../core/exceptions/app_exception.dart';
import '../../../data/models/scan_record.dart';
import '../../../data/repositories/scan_records_repository.dart';

bool analysisPending(ScanRecord scan) =>
    scan.status == ScanStatus.pending || scan.status == ScanStatus.processing;

/// Sequential, bounded status checks; selection/session disposal fences updates.
Future<ScanRecord> pollScanAnalysis(
  ScanRecordsRepository records,
  ScanRecord initial, {
  required bool Function() isActive,
  required void Function(ScanRecord) onUpdate,
  String? anonymousKey,
  Duration interval = const Duration(seconds: 2),
  int maxAttempts = 6,
}) async {
  var current = initial;
  final elapsed = Stopwatch()..start();
  const maximumWait = Duration(seconds: 30);
  for (
    var attempt = 0;
    attempt < maxAttempts && analysisPending(current);
    attempt++
  ) {
    if (!isActive() || elapsed.elapsed + interval > maximumWait) break;
    await Future<void>.delayed(interval);
    if (!isActive()) break;
    current = await records.read(initial.id, anonymousKey: anonymousKey);
    if (!isActive()) break;
    if (current.id != initial.id) {
      throw const AppException(AppErrorKind.invalidResponse);
    }
    onUpdate(current);
  }
  return current;
}
