import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/admin_accounts.dart';
import 'admin_record_presentation.dart';
import 'admin_selectable_text.dart';

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.history, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        auditTitle(entry),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Text(
                      auditEntityLabel(entry.entityType),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(adminUtc(entry.createdAt)),
          Text(
            entry.actorRole == null
                ? 'Actor identity unavailable'
                : 'Actor role: ${entry.actorRole}',
          ),
          for (final item in entry.metadata.entries)
            Text(
              '${auditMetadataLabel(item.key)}: ${item.value is List ? (item.value as List).join(', ') : item.value}',
            ),
          ExpansionTile(
            key: PageStorageKey('audit-detail-${entry.id}'),
            title: const Text('Recorded event details'),
            expansionAnimationStyle: AnimationStyle(
              duration: AppMotion.resolve(context, AppMotion.reveal),
            ),
            children: [
              KeyedSubtree(
                key: PageStorageKey('audit-detail-body-${entry.id}'),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AdminSelectableText(
                        'Original action: ${entry.action}\nOriginal entity: ${entry.entityType}',
                      ),
                      AdminSelectableText(
                        'Record ID: ${entry.id}\nAffected entity: ${entry.entityId}',
                      ),
                      AdminSelectableText(
                        'Actor ID: ${entry.actorId ?? 'Unavailable'}',
                      ),
                      AdminSelectableText(
                        'Recorded timestamp: ${entry.createdAt.toUtc().toIso8601String()}',
                      ),
                      const Text(
                        'Read-only recorded metadata. No separate operation outcome is supplied; an action name alone does not establish success.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
