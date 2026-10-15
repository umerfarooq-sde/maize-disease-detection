import '../../core/exceptions/app_exception.dart';

const farmerAccountStatuses = ['ACTIVE', 'SUSPENDED', 'DEACTIVATED'];
const accountAuditActions = [
  'CREATE',
  'UPDATE',
  'ACTIVATE',
  'DEACTIVATE',
  'DELETE',
  'MODEL_PROMOTION',
];
const accountAuditEntities = [
  'farmer_account',
  'disease',
  'disease_source',
  'knowledge_document',
  'fertilizer_rule',
  'calculator_config',
  'fertilizer',
  'model_version',
];
bool accountUuid(String value) => RegExp(
  r'^[a-fA-F0-9]{8}-(?:[a-fA-F0-9]{4}-){3}[a-fA-F0-9]{12}$',
).hasMatch(value);

class ManagedFarmer {
  const ManagedFarmer(
    this.id,
    this.email,
    this.status,
    this.displayName,
    this.revision,
    this.createdAt,
  );
  final String id, email, status, revision;
  final String? displayName;
  final DateTime createdAt;
  factory ManagedFarmer.fromJson(Object? value) {
    final data = _object(value);
    final name = data['displayName'], revision = _text(data['revision'], 64);
    final status = data['status'];
    if (data.length != 6 ||
        !farmerAccountStatuses.contains(status) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(revision) ||
        (name != null && (name is! String || name.runes.length > 120))) {
      throw _invalid();
    }
    return ManagedFarmer(
      _uuid(data['id']),
      _text(data['email'], 254),
      status as String,
      name as String?,
      revision,
      _date(data['createdAt']),
    );
  }
}

class AdminAuditEntry {
  const AdminAuditEntry(
    this.id,
    this.action,
    this.entityType,
    this.entityId,
    this.createdAt,
    this.actorId,
    this.actorRole,
    this.metadata,
  );
  final String id, action, entityType, entityId;
  final DateTime createdAt;
  final String? actorId, actorRole;
  final Map<String, Object?> metadata;
  factory AdminAuditEntry.fromJson(Object? value) {
    final data = _object(value);
    final action = data['action'], entity = data['entityType'];
    final actor = data['actor'];
    if (data.length != 7 ||
        !accountAuditActions.contains(action) ||
        !(entity == 'OTHER' || accountAuditEntities.contains(entity))) {
      throw _invalid();
    }
    String? actorId, role;
    if (actor != null) {
      final parsed = _object(actor);
      actorId = _uuid(parsed['id']);
      role = _text(parsed['role'], 6);
      if (!['ADMIN', 'FARMER'].contains(role) || parsed.length != 2) {
        throw _invalid();
      }
    }
    final metadata = _object(data['metadata']);
    if (metadata.keys.any(
      (key) => ![
        'fromStatus',
        'toStatus',
        'status',
        'expectedStatus',
        'revokedSessions',
        'version',
        'documentVersion',
        'fieldsChanged',
      ].contains(key),
    )) {
      throw _invalid();
    }
    for (final entry in metadata.entries) {
      if ([
        'revokedSessions',
        'version',
        'documentVersion',
      ].contains(entry.key)) {
        if (entry.value is! int ||
            (entry.value as int) < 0 ||
            (entry.value as int) > 2147483647) {
          throw _invalid();
        }
      } else if (entry.key == 'fieldsChanged') {
        if (entry.value is! List ||
            (entry.value as List).any(
              (field) => ![
                'name',
                'description',
                'scientificName',
                'status',
              ].contains(field),
            )) {
          throw _invalid();
        }
      } else if (![
        'ACTIVE',
        'SUSPENDED',
        'DEACTIVATED',
        'DRAFT',
        'ARCHIVED',
        'INACTIVE',
      ].contains(entry.value)) {
        throw _invalid();
      }
    }
    return AdminAuditEntry(
      _uuid(data['id']),
      action as String,
      entity as String,
      _uuid(data['entityId']),
      _date(data['createdAt']),
      actorId,
      role,
      Map.unmodifiable(metadata),
    );
  }
}

({List<T> items, String? nextCursor}) accountsPage<T>(
  Object? value,
  T Function(Object?) parse,
  String Function(T) id,
) {
  final data = _object(value), items = data['items'];
  if (items is! List || items.length > 50) throw _invalid();
  final rows = items.map(parse).toList();
  if (rows.map(id).toSet().length != rows.length) throw _invalid();
  final cursor = data['nextCursor'] == null ? null : _uuid(data['nextCursor']);
  if (cursor != null && (rows.isEmpty || id(rows.last) != cursor)) {
    throw _invalid();
  }
  return (items: List.unmodifiable(rows), nextCursor: cursor);
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map<String, dynamic>) throw _invalid();
  return value;
}

String _text(Object? value, int maximum) {
  if (value is! String ||
      value.isEmpty ||
      value.length > maximum ||
      value.contains('\u0000')) {
    throw _invalid();
  }
  return value;
}

String _uuid(Object? value) {
  final text = _text(value, 36);
  if (!accountUuid(text)) throw _invalid();
  return text;
}

DateTime _date(Object? value) {
  final parsed = DateTime.tryParse(_text(value, 40));
  if (parsed == null) throw _invalid();
  return parsed;
}

AppException _invalid() => const AppException(AppErrorKind.invalidResponse);
