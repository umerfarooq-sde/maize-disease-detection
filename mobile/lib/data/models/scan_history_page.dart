import '../../core/exceptions/app_exception.dart';
import 'scan_record.dart';

class ScanHistoryPage {
  ScanHistoryPage({required List<ScanRecord> items, required this.nextCursor})
    : items = List.unmodifiable(items);

  final List<ScanRecord> items;
  final String? nextCursor;

  factory ScanHistoryPage.fromJson(Object? value) {
    if (value is Map<String, dynamic> &&
        value['items'] is List<dynamic> &&
        value.containsKey('nextCursor')) {
      final rawItems = value['items'] as List<dynamic>;
      final rawCursor = value['nextCursor'];
      if (rawItems.length <= 50 &&
          (rawCursor == null ||
              (rawCursor is String && _uuid.hasMatch(rawCursor)))) {
        final items = rawItems.map(ScanRecord.fromJson).toList();
        if (items.map((item) => item.id).toSet().length == items.length &&
            (rawCursor == null ||
                (items.isNotEmpty && items.last.id == rawCursor))) {
          return ScanHistoryPage(
            items: items,
            nextCursor: rawCursor as String?,
          );
        }
      }
    }
    throw const AppException(AppErrorKind.invalidResponse);
  }

  static final _uuid = RegExp(
    r'^[a-f0-9]{8}-[a-f0-9]{4}-[1-8][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
  );
}
