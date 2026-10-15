import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/admin_accounts.dart';

class AuditEntryCard extends StatelessWidget {
  const AuditEntryCard({required this.entry, super.key});
  final AdminAuditEntry entry;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${entry.action} · ${entry.entityType}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(entry.createdAt.toUtc().toIso8601String()),
          SelectableText('Affected entity: ${entry.entityId}'),
          SelectableText(
            entry.actorId == null
                ? 'Actor: system or removed account'
                : 'Actor: ${entry.actorRole} ${entry.actorId}',
          ),
          for (final item in entry.metadata.entries)
            Text(
              '${_label(item.key)}: ${item.value is List ? (item.value as List).join(', ') : item.value}',
            ),
        ],
      ),
    ),
  );
  String _label(String key) => switch (key) {
    'fromStatus' => 'Previous status',
    'toStatus' => 'New status',
    'expectedStatus' => 'Expected status',
    'revokedSessions' => 'Revoked sessions',
    'documentVersion' => 'Document version',
    'fieldsChanged' => 'Changed fields',
    'status' => 'Status',
    'version' => 'Version',
    _ => 'Reviewed metadata',
  };
}
