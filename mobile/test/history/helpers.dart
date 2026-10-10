import 'dart:async';
import 'package:maizedoctor/data/models/scan_history_page.dart';
import 'package:maizedoctor/data/models/scan_record.dart';
import 'package:maizedoctor/data/repositories/scan_records_repository.dart';
import '../scans/helpers.dart';

String historyId(int index) =>
    '00000000-0000-4000-8000-${index.toString().padLeft(12, '0')}';

Map<String, Object?> historyScanJson(
  int index, {
  ScanStatus status = ScanStatus.completed,
}) => {...scanJson(status: status), 'id': historyId(index)};

ScanRecord historyScan(int index, {ScanStatus status = ScanStatus.completed}) =>
    ScanRecord.fromJson(historyScanJson(index, status: status));

class FakeScanRecordsRepository implements ScanRecordsRepository {
  @override
  bool hasAuthenticatedSession = true;
  final requests = <({String? cursor, int limit})>[];
  final responses = <Future<ScanHistoryPage>>[];
  int readCalls = 0;
  @override
  Future<ScanHistoryPage> history({String? cursor, int limit = 20}) {
    requests.add((cursor: cursor, limit: limit));
    return responses.isEmpty
        ? Future.value(ScanHistoryPage(items: [], nextCursor: null))
        : responses.removeAt(0);
  }

  @override
  Future<ScanRecord> read(String id, {String? anonymousKey}) async {
    readCalls++;
    return historyScan(1);
  }
}
