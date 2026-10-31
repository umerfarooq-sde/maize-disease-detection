import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/data/models/scan_record.dart';
import 'package:maizedoctor/features/disease_detection/utils/scan_polling.dart';
import 'helpers.dart';

void main() {
  test('default automatic polling supports fifteen bounded checks', () async {
    final records = FakeScanRecordsRepository()
      ..result = ScanRecord.fromJson(scanJson(status: ScanStatus.processing));
    final initial = ScanRecord.fromJson(scanJson(status: ScanStatus.pending));
    final updated = await pollScanAnalysis(
      records,
      initial,
      interval: Duration.zero,
      isActive: () => true,
      onUpdate: (_) {},
    );
    expect(records.reads.length, 15);
    expect(updated.status, ScanStatus.processing);
  });

  test('polling stops as soon as a prediction completes', () async {
    final records = FakeScanRecordsRepository()
      ..responses.addAll([
        ScanRecord.fromJson(scanJson(status: ScanStatus.processing)),
        ScanRecord.fromJson(scanJson(status: ScanStatus.completed)),
      ]);
    final observed = <ScanStatus>[];
    final updated = await pollScanAnalysis(
      records,
      ScanRecord.fromJson(scanJson(status: ScanStatus.pending)),
      interval: Duration.zero,
      isActive: () => true,
      onUpdate: (record) => observed.add(record.status),
    );
    expect(records.reads.length, 2);
    expect(observed, [ScanStatus.processing, ScanStatus.completed]);
    expect(updated.status, ScanStatus.completed);
  });

  test('cancelled polling performs no further requests', () async {
    final records = FakeScanRecordsRepository();
    final result = await pollScanAnalysis(
      records,
      ScanRecord.fromJson(scanJson(status: ScanStatus.pending)),
      interval: Duration.zero,
      isActive: () => false,
      onUpdate: (_) => fail('updates must stop after cancellation'),
    );
    expect(records.reads, isEmpty);
    expect(result.status, ScanStatus.pending);
  });
}
