import '../datasources/scan_datasource.dart';
import '../models/scan_history_page.dart';
import '../models/scan_record.dart';

abstract interface class ScanRecordsRepository {
  bool get hasAuthenticatedSession;
  Future<ScanRecord> read(String id, {String? anonymousKey});
  Future<ScanHistoryPage> history({String? cursor, int limit = 20});
}

class ApiScanRecordsRepository implements ScanRecordsRepository {
  ApiScanRecordsRepository(this._remote);
  final ScanDatasource _remote;

  @override
  bool get hasAuthenticatedSession => _remote.hasAuthenticatedSession;

  @override
  Future<ScanRecord> read(String id, {String? anonymousKey}) =>
      _remote.read(id, anonymousKey: anonymousKey);

  @override
  Future<ScanHistoryPage> history({String? cursor, int limit = 20}) =>
      _remote.history(cursor: cursor, limit: limit);
}
