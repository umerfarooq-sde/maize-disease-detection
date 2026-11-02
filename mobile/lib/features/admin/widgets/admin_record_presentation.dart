import '../../../data/models/admin_accounts.dart';

String adminUtc(DateTime date) {
  final value = date.toUtc();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} · ${two(value.hour)}:${two(value.minute)} UTC';
}

String auditActionLabel(String action) => switch (action) {
  'CREATE' => 'Creation recorded',
  'UPDATE' => 'Update recorded',
  'ACTIVATE' => 'Activation recorded',
  'DEACTIVATE' => 'Deactivation recorded',
  'DELETE' => 'Deletion recorded',
  'MODEL_PROMOTION' => 'Model promotion recorded',
  _ => 'Recorded event · ${action.replaceAll('_', ' ').toLowerCase()}',
};
String auditEntityLabel(String entity) => switch (entity) {
  'farmer_account' => 'Farmer account',
  'disease' => 'Disease catalogue',
  'disease_source' => 'Knowledge source',
  'knowledge_document' => 'Knowledge document',
  'fertilizer_rule' => 'Fertilizer rule',
  'calculator_config' => 'Calculator configuration',
  'fertilizer' => 'Fertilizer product',
  'model_version' => 'Model registry',
  _ => 'Other recorded entity',
};
String auditTitle(AdminAuditEntry entry) =>
    entry.entityType == 'farmer_account' &&
        entry.metadata.containsKey('fromStatus') &&
        entry.metadata.containsKey('toStatus')
    ? 'Farmer account status change'
    : auditActionLabel(entry.action);
String auditMetadataLabel(String key) => switch (key) {
  'fromStatus' => 'Previous status',
  'toStatus' => 'New status',
  'expectedStatus' => 'Expected status',
  'revokedSessions' => 'Revoked sessions',
  'documentVersion' => 'Document version',
  'fieldsChanged' => 'Changed fields',
  'status' => 'Status',
  'version' => 'Version',
  _ => key,
};
