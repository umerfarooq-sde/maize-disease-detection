import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_states.dart';
import '../../../data/models/admin_accounts.dart';
import '../view_models/audit_log_view_model.dart';
import '../widgets/audit_entry_card.dart';

class AuditLogView extends StatefulWidget {
  const AuditLogView({super.key});
  @override
  State<AuditLogView> createState() => _AuditLogViewState();
}

class _AuditLogViewState extends State<AuditLogView> {
  final _from = TextEditingController(),
      _to = TextEditingController(),
      _actor = TextEditingController();
  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    _actor.dispose();
    super.dispose();
  }

  Future<void> _filter(
    AuditLogViewModel model, {
    String? action,
    String? entity,
  }) => model.filter(
    selectedAction: action,
    selectedEntity: entity,
    actor: _actor.text,
    start: _from.text,
    end: _to.text,
  );
  @override
  Widget build(BuildContext context) {
    final model = context.watch<AuditLogViewModel>();
    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Audit history',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Read-only recorded actions. Times and date filters use UTC. Only reviewed metadata is shown; historical records cannot be edited here.',
          ),
          const SizedBox(height: AppSpacing.lg),
          DropdownButtonFormField<String>(
            initialValue: model.action ?? '',
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Action'),
            items: [
              const DropdownMenuItem(value: '', child: Text('All actions')),
              for (final action in accountAuditActions)
                DropdownMenuItem(value: action, child: Text(action)),
            ],
            onChanged: model.busy
                ? null
                : (value) => _filter(
                    model,
                    action: value == '' ? null : value,
                    entity: model.entityType,
                  ),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: model.entityType ?? '',
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Affected area'),
            items: [
              const DropdownMenuItem(value: '', child: Text('All areas')),
              for (final entity in accountAuditEntities)
                DropdownMenuItem(
                  value: entity,
                  child: Text(entity.replaceAll('_', ' ')),
                ),
            ],
            onChanged: model.busy
                ? null
                : (value) => _filter(
                    model,
                    action: model.action,
                    entity: value == '' ? null : value,
                  ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('audit-actor'),
            controller: _actor,
            enabled: !model.busy,
            decoration: const InputDecoration(labelText: 'Actor ID (optional)'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('audit-from'),
            controller: _from,
            enabled: !model.busy,
            decoration: const InputDecoration(
              labelText: 'From UTC date (optional)',
              hintText: 'YYYY-MM-DD',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('audit-to'),
            controller: _to,
            enabled: !model.busy,
            decoration: const InputDecoration(
              labelText: 'Through UTC date (optional)',
              hintText: 'YYYY-MM-DD',
              helperText: 'Supply both dates, no more than 366 days apart.',
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton(
            key: const Key('audit-filter'),
            onPressed: model.busy
                ? null
                : () => _filter(
                    model,
                    action: model.action,
                    entity: model.entityType,
                  ),
            child: const Text('Apply / refresh audit filters'),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (model.error case final error?) ...[
            AppErrorState(error: error, onRetry: model.load),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (model.busy)
            const AppLoadingState(message: 'Loading recorded actions…'),
          if (!model.busy && model.error == null && model.items.isEmpty)
            const AppEmptyState(
              title: 'No recorded actions match',
              message: 'Try other filters or refresh after an Admin change.',
            ),
          for (final entry in model.items) ...[
            AuditEntryCard(entry: entry),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (model.nextCursor != null)
            OutlinedButton(
              onPressed: model.busy ? null : () => model.load(more: true),
              child: const Text('Load more audit records'),
            ),
        ],
      ),
    );
  }
}
