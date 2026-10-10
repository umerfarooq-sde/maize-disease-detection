import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/data/datasources/leaf_image_datasource.dart';
import 'package:maizedoctor/data/models/scan_record.dart';
import 'package:maizedoctor/features/disease_detection/view_models/scan_view_model.dart';
import 'helpers.dart';

void main() {
  test(
    'gallery/camera selection and cancellation preserve the existing preview',
    () async {
      final repo = FakeScanRepository();
      final model = ScanViewModel(repo);
      addTearDown(model.dispose);
      await model.select(LeafImageSource.gallery);
      expect(model.image, leafImage);
      repo.selection = null;
      await model.select(LeafImageSource.camera);
      expect(model.image, leafImage);
      expect(repo.sources, [LeafImageSource.gallery, LeafImageSource.camera]);
      model.clear();
      expect(model.image, isNull);
    },
  );
  test(
    'Android recovered selection is previewed and never uploaded automatically',
    () async {
      final repo = FakeScanRepository()..recovered = leafImage;
      final model = ScanViewModel(repo);
      addTearDown(model.dispose);
      await model.recoverSelection();
      expect(model.image, leafImage);
      expect(repo.keys, isEmpty);
    },
  );
  test(
    'upload progress, duplicate-tap protection, retry key and new selection key',
    () async {
      final repo = FakeScanRepository()..pending = Completer<ScanRecord>();
      final model = ScanViewModel(repo);
      addTearDown(model.dispose);
      await model.select(LeafImageSource.gallery);
      final pending = model.upload();
      expect(model.uploading, true);
      repo.reportProgress!(0.5);
      expect(model.progress, 0.5);
      await model.upload();
      model.clear();
      await model.select(LeafImageSource.camera);
      expect(repo.keys.length, 1);
      expect(model.image, leafImage);
      repo.pending!.completeError(const AppException(AppErrorKind.timeout));
      await pending;
      expect(model.error?.kind, AppErrorKind.timeout);
      expect(model.uploading, false);
      expect(model.image, leafImage);
      repo.pending = null;
      await model.retry();
      expect(repo.keys[0], repo.keys[1]);
      expect(model.scan, savedScan);
      await model.upload();
      expect(repo.keys.length, 2);
      await model.select(LeafImageSource.gallery);
      await model.upload();
      expect(repo.keys.last, isNot(repo.keys.first));
    },
  );
  test(
    'retry after selection failure reopens the picker instead of uploading an old photo',
    () async {
      final repo = FakeScanRepository();
      final model = ScanViewModel(repo);
      addTearDown(model.dispose);
      await model.select(LeafImageSource.gallery);
      repo.selectError = const AppException(AppErrorKind.imageAccess);
      await model.select(LeafImageSource.camera);
      expect(model.error?.kind, AppErrorKind.imageAccess);
      repo.selectError = null;
      await model.retry();
      expect(repo.sources.last, LeafImageSource.camera);
      expect(repo.keys, isEmpty);
    },
  );
  test('dispose ignores late progress and completion safely', () async {
    final repo = FakeScanRepository()..pending = Completer<ScanRecord>();
    final model = ScanViewModel(repo);
    await model.select(LeafImageSource.gallery);
    final pending = model.upload();
    model.dispose();
    repo.reportProgress!(1);
    repo.pending!.complete(savedScan);
    await pending;
    expect(model.scan, isNull);
  });
  test(
    'failed analysis keeps the saved photo and retries the same scan key without picking again',
    () async {
      final repo = FakeScanRepository()
        ..result = ScanRecord.fromJson(scanJson(status: ScanStatus.failed));
      final model = ScanViewModel(repo);
      addTearDown(model.dispose);
      await model.select(LeafImageSource.gallery);
      await model.upload();
      expect(model.analysisFailed, true);
      expect(model.image, leafImage);
      expect(model.error, isNull);
      final failed = model.scan;
      repo.uploadError = const AppException(AppErrorKind.network);
      await model.retry();
      expect(model.scan, failed);
      expect(model.image, leafImage);
      expect(model.error?.kind, AppErrorKind.network);
      repo.uploadError = null;
      repo.result = ScanRecord.fromJson(scanJson(status: ScanStatus.completed));
      await model.retry();
      expect(model.scan?.status, ScanStatus.completed);
      expect(model.analysisFailed, false);
      expect(model.error, isNull);
      expect(repo.keys, hasLength(3));
      expect(repo.keys.toSet(), hasLength(1));
      expect(repo.sources, [LeafImageSource.gallery]);
      await model.upload();
      expect(repo.keys, hasLength(3));
    },
  );
  test('pending and processing scans block accidental re-upload', () async {
    for (final status in [ScanStatus.pending, ScanStatus.processing]) {
      final repo = FakeScanRepository()
        ..result = ScanRecord.fromJson(scanJson(status: status));
      final model = ScanViewModel(repo);
      addTearDown(model.dispose);
      await model.select(LeafImageSource.gallery);
      await model.upload();
      await model.upload();
      expect(model.scan?.status, status);
      expect(repo.keys, hasLength(1));
    }
  });
}
