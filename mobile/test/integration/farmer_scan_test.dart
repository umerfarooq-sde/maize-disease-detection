import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/network/api_client.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/storage/memory_session_tokens.dart';
import 'package:maizedoctor/data/datasources/leaf_image_datasource.dart';
import 'package:maizedoctor/data/datasources/scan_datasource.dart';
import 'package:maizedoctor/data/models/scan_record.dart';
import 'package:maizedoctor/data/repositories/farmer_session_repository.dart';
import 'package:maizedoctor/data/repositories/scan_records_repository.dart';
import 'package:maizedoctor/data/repositories/scan_repository.dart';
import 'package:maizedoctor/features/disease_detection/view_models/scan_view_model.dart';
import 'package:maizedoctor/features/scan_history/view_models/scan_history_view_model.dart';
import '../core/api_client_test.dart' show errorKind;
import 'scan_upload_test.dart' show FixtureImageSource;

void main() {
  const live = bool.fromEnvironment('RUN_LIVE_SCAN_INFERENCE');
  test(
    'real farmer sign-in, scan, private history/detail, account isolation and logout',
    () async {
      final tokens = MemorySessionTokens();
      final api = ApiClient(
        config: AppConfig.fromEnvironment(),
        tokenSource: tokens,
      );
      final session = FarmerSessionRepository(api, tokens);
      final records = ApiScanRecordsRepository(ScanDatasource(api));
      final upload = ScanViewModel(
        ApiScanRepository(FixtureImageSource(), ScanDatasource(api)),
        records: records,
      );
      final history = ScanHistoryViewModel(records);
      try {
        Future<void> signIn(String prefix) => session.signIn(
          Platform.environment['SCAN_FIXTURE_${prefix}_EMAIL']!,
          Platform.environment['SCAN_FIXTURE_${prefix}_PASSWORD']!,
        );
        await signIn('OWNER');
        await history.load();
        expect(history.items, isEmpty);
        await upload.select(LeafImageSource.gallery);
        await upload.upload();
        expect(upload.error, isNull);
        final scan = upload.scan!;
        expect(scan.status, ScanStatus.completed);
        expect(scan.prediction!.modelVersion, 'mobilenet-v3-small-v2-20261009');
        expect(scan.prediction!.confidenceThreshold, isNull);
        await history.refresh();
        expect(history.items.map((item) => item.id), [scan.id]);
        expect(history.hasMore, false);
        final read = await records.read(scan.id);
        expect(
          read.prediction!.predictedClass,
          scan.prediction!.predictedClass,
        );
        expect(read.prediction!.confidence, scan.prediction!.confidence);
        expect(read.createdAt, scan.createdAt);
        final page = await records.history(limit: 1);
        expect(page.items.single.id, scan.id);
        expect(page.nextCursor, isNull);
        await session.signOut();
        expect(api.hasAuthenticatedSession, false);
        await history.refresh();
        expect(history.items, isEmpty);
        await expectLater(
          records.history(),
          throwsA(errorKind(AppErrorKind.authentication)),
        );
        await signIn('OTHER');
        expect((await records.history()).items, isEmpty);
        await expectLater(
          records.read(scan.id),
          throwsA(errorKind(AppErrorKind.notFound)),
        );
        await expectLater(
          records.history(cursor: scan.id),
          throwsA(errorKind(AppErrorKind.notFound)),
        );
        await session.signOut();
      } finally {
        history.dispose();
        upload.dispose();
        tokens.dispose();
        api.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
    skip: live && Platform.environment.containsKey('SCAN_FIXTURE_OWNER_EMAIL')
        ? false
        : 'Use the fixture-cleaning --inference --farmer harness.',
  );
}
