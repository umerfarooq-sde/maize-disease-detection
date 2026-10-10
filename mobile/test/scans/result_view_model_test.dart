import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/data/datasources/leaf_image_datasource.dart';
import 'package:maizedoctor/data/models/scan_record.dart';
import 'package:maizedoctor/features/disease_detection/view_models/scan_result_arguments.dart';
import 'package:maizedoctor/features/disease_detection/view_models/scan_result_view_model.dart';
import 'package:maizedoctor/features/disease_detection/view_models/scan_view_model.dart';
import 'helpers.dart';

const guestKey = '1227d27c-72fa-4f6f-a701-27d9db89ce69';
final completed = ScanRecord.fromJson(scanJson(status: ScanStatus.completed));
final failed = ScanRecord.fromJson(scanJson(status: ScanStatus.failed));
final processing = ScanRecord.fromJson(scanJson(status: ScanStatus.processing));

void main() {
  test(
    'pending submission checks status sequentially with the original private key',
    () async {
      final uploads = FakeScanRepository();
      final records = FakeScanRecordsRepository()
        ..responses.addAll([processing, completed]);
      final model = ScanViewModel(
        uploads,
        records: records,
        pollInterval: Duration.zero,
      );
      addTearDown(model.dispose);
      await model.select(LeafImageSource.gallery);
      await model.upload();
      expect(model.scan?.status, ScanStatus.completed);
      expect(model.busy, false);
      expect(records.reads, hasLength(2));
      expect(records.reads.map((item) => item.$2).toSet(), {
        uploads.keys.single,
      });
      expect(
        model.resultArguments.toString(),
        isNot(contains(uploads.keys.single)),
      );
    },
  );
  test(
    'pending polling is bounded and manual refresh does not upload a duplicate',
    () async {
      final uploads = FakeScanRepository();
      final records = FakeScanRecordsRepository();
      final model = ScanViewModel(
        uploads,
        records: records,
        pollInterval: Duration.zero,
        maxPollAttempts: 2,
      );
      addTearDown(model.dispose);
      await model.select(LeafImageSource.gallery);
      await model.upload();
      expect(records.reads, hasLength(2));
      expect(model.scan?.status, ScanStatus.pending);
      expect(model.busy, false);
      records.result = completed;
      await model.refreshAnalysis();
      expect(model.scan?.status, ScanStatus.completed);
      expect(uploads.keys, hasLength(1));
    },
  );
  test(
    'polling network failure preserves photo and retry resumes status checks',
    () async {
      final uploads = FakeScanRepository();
      final records = FakeScanRecordsRepository()
        ..error = const AppException(AppErrorKind.timeout);
      final model = ScanViewModel(
        uploads,
        records: records,
        pollInterval: Duration.zero,
      );
      addTearDown(model.dispose);
      await model.select(LeafImageSource.gallery);
      await model.upload();
      expect(model.error?.kind, AppErrorKind.timeout);
      expect(model.image, leafImage);
      expect(model.scan?.status, ScanStatus.pending);
      records.error = null;
      records.result = completed;
      await model.retry();
      expect(model.error, isNull);
      expect(model.scan?.status, ScanStatus.completed);
      expect(uploads.keys, hasLength(1));
    },
  );
  test('clearing a polling scan fences a late status result', () async {
    final records = FakeScanRecordsRepository()
      ..pending = Completer<ScanRecord>();
    final model = ScanViewModel(
      FakeScanRepository(),
      records: records,
      pollInterval: Duration.zero,
    );
    addTearDown(model.dispose);
    await model.select(LeafImageSource.gallery);
    final request = model.upload();
    await Future<void>.delayed(Duration.zero);
    expect(model.polling, true);
    model.clear();
    records.pending!.complete(completed);
    await request;
    expect(model.scan, isNull);
    expect(model.image, isNull);
    expect(model.busy, false);
  });
  test(
    'authenticated detail reload reads the same scan without a guest key',
    () async {
      final records = FakeScanRecordsRepository()
        ..hasAuthenticatedSession = true
        ..result = completed;
      final model = ScanResultViewModel(records, scanId: completed.id);
      addTearDown(model.dispose);
      await model.load();
      expect(model.scan, completed);
      expect(records.reads.single, (completed.id, null));
      expect(model.error, isNull);
      expect(model.canRetryAnalysis, false);
    },
  );
  test(
    'guest result status reads use only the local route capability',
    () async {
      final records = FakeScanRecordsRepository()
        ..responses.addAll([processing, completed]);
      final initial = ScanResultArguments(
        scan: savedScan,
        selectedImage: leafImage,
        requestKey: guestKey,
      );
      final model = ScanResultViewModel(
        records,
        scanId: savedScan.id,
        initial: initial,
        pollInterval: Duration.zero,
      );
      addTearDown(model.dispose);
      await model.load();
      expect(model.scan, completed);
      expect(records.reads.map((item) => item.$2), everyElement(guestKey));
      expect(initial.toString(), isNot(contains(guestKey)));
    },
  );
  test('failed result reuses original bytes and key for retry', () async {
    final uploads = FakeScanRepository()..result = completed;
    final model = ScanResultViewModel(
      FakeScanRecordsRepository(),
      scanId: failed.id,
      uploads: uploads,
      initial: ScanResultArguments(
        scan: failed,
        selectedImage: leafImage,
        requestKey: guestKey,
      ),
    );
    addTearDown(model.dispose);
    await model.load();
    expect(model.canRetryAnalysis, true);
    await model.retryAnalysis();
    expect(uploads.keys, [guestKey]);
    expect(model.scan, completed);
    expect(model.canRetryAnalysis, false);
  });
  test(
    'direct guest access fails safely and foreign response IDs are rejected',
    () async {
      final records = FakeScanRecordsRepository()
        ..error = const AppException(AppErrorKind.authentication);
      final model = ScanResultViewModel(records, scanId: savedScan.id);
      addTearDown(model.dispose);
      await model.load();
      expect(model.error?.kind, AppErrorKind.authentication);
      expect(model.scan, isNull);
      records.error = null;
      final other = scanJson(status: ScanStatus.completed)
        ..['id'] = 'ba29ad82-93ec-433d-8948-2e8ca17c7428';
      records.result = ScanRecord.fromJson(other);
      await model.refresh();
      expect(model.error?.kind, AppErrorKind.invalidResponse);
      expect(model.scan, isNull);
    },
  );
  test('disposed detail ignores late completion', () async {
    final records = FakeScanRecordsRepository()
      ..pending = Completer<ScanRecord>();
    final model = ScanResultViewModel(records, scanId: savedScan.id);
    final request = model.load();
    model.dispose();
    records.pending!.complete(completed);
    await request;
    expect(model.scan, isNull);
  });
}
