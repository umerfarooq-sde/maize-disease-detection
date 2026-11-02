import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_states.dart';
import '../../../core/widgets/app_field.dart';
import '../../../data/models/admin_accounts.dart';
import '../view_models/audit_log_view_model.dart';
import '../widgets/admin_record_page.dart';
import '../widgets/audit_entry_card.dart';
import '../widgets/admin_record_presentation.dart';

class AuditLogView extends StatefulWidget {
  const AuditLogView({super.key});
  @override
  State<AuditLogView> createState() => _AuditLogViewState();
}

class _AuditLogViewState extends State<AuditLogView> {
  final _from = TextEditingController(),
      _to = TextEditingController(),
      _actor = TextEditingController();
  String? _action, _entity;
  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    _actor.dispose();
    super.dispose();
  }

  Future<void> _apply(AuditLogViewModel model) => model.filter(
    selectedAction: _action,
    selectedEntity: _entity,
    actor: _actor.text,
    start: _from.text,
    end: _to.text,
  );

  @override
  Widget build(BuildContext context) {
    final model = context.watch<AuditLogViewModel>();
    final theme = Theme.of(context);
    return AdminRecordPage(
      storageKey: 'admin-audit-records',
      count: model.items.length,
      itemBuilder: (context, index) => AuditEntryCard(
        key: ValueKey(model.items[index].id),
        entry: model.items[index],
      ),
      footer: model.nextCursor == null
          ? const SizedBox.shrink()
          : OutlinedButton.icon(
              onPressed: model.busy ? null : () => model.load(more: true),
              icon: const Icon(Icons.expand_more),
              label: const Text('Load more audit records'),
            ),
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text('Audit history', style: theme.textTheme.headlineMedium),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Read-only recorded actions. Times and date filters use UTC. Only reviewed metadata is shown; historical records cannot be edited here.',
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: ExpansionTile(
              key: const PageStorageKey('audit-filter-panel'),
              initiallyExpanded: true,
              title: const Text('Filter recorded events'),
              subtitle: Text(
                [
                  model.action == null
                      ? 'All actions'
                      : auditActionLabel(model.action!),
                  model.entityType == null
                      ? 'All areas'
                      : auditEntityLabel(model.entityType!),
                  if (model.actorId != null) 'Actor: ${model.actorId}',
                  if (model.from != null)
                    '${model.from} through ${model.to} UTC',
                ].join(' · '),
              ),
              expansionAnimationStyle: AnimationStyle(
                duration: AppMotion.resolve(context, AppMotion.reveal),
              ),
              children: [
                KeyedSubtree(
                  key: const PageStorageKey('audit-filter-fields'),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppField(
                          label: 'Action',
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('audit-action-${_action ?? ''}'),
                            initialValue: _action ?? '',
                            isExpanded: true,
                            itemHeight: null,
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('All actions'),
                              ),
                              for (final action in accountAuditActions)
                                DropdownMenuItem(
                                  value: action,
                                  child: Text(auditActionLabel(action)),
                                ),
                            ],
                            onChanged: model.busy
                                ? null
                                : (value) => setState(
                                    () => _action = value == '' ? null : value,
                                  ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppField(
                          label: 'Affected area',
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('audit-area-${_entity ?? ''}'),
                            initialValue: _entity ?? '',
                            isExpanded: true,
                            itemHeight: null,
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('All areas'),
                              ),
                              for (final entity in accountAuditEntities)
                                DropdownMenuItem(
                                  value: entity,
                                  child: Text(auditEntityLabel(entity)),
                                ),
                            ],
                            onChanged: model.busy
                                ? null
                                : (value) => setState(
                                    () => _entity = value == '' ? null : value,
                                  ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppField(
                          label: 'Actor ID',
                          optional: true,
                          child: TextField(
                            key: const Key('audit-actor'),
                            controller: _actor,
                            enabled: !model.busy,
                            decoration: const InputDecoration(
                              helperText: 'Exact recorded actor identifier.',
                              helperMaxLines: 3,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppField(
                          label: 'From UTC date',
                          optional: true,
                          child: TextField(
                            key: const Key('audit-from'),
                            controller: _from,
                            enabled: !model.busy,
                            keyboardType: TextInputType.datetime,
                            decoration: const InputDecoration(
                              hintText: 'YYYY-MM-DD',
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppField(
                          label: 'Through UTC date',
                          optional: true,
                          child: TextField(
                            key: const Key('audit-to'),
                            controller: _to,
                            enabled: !model.busy,
                            keyboardType: TextInputType.datetime,
                            decoration: const InputDecoration(
                              hintText: 'YYYY-MM-DD',
                              helperText:
                                  'Supply both dates, a span shorter than 366 days. The through-date includes that entire UTC day.',
                              helperMaxLines: 5,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: AppSpacing.md,
                          children: [
                            FilledButton.icon(
                              key: const Key('audit-filter'),
                              onPressed: model.busy
                                  ? null
                                  : () => _apply(model),
                              icon: const Icon(Icons.filter_alt_outlined),
                              label: const Text(
                                'Apply / refresh audit filters',
                              ),
                            ),
                            TextButton(
                              onPressed: model.busy
                                  ? null
                                  : () {
                                      _actor.clear();
                                      _from.clear();
                                      _to.clear();
                                      setState(() {
                                        _action = null;
                                        _entity = null;
                                      });
                                      _apply(model);
                                    },
                              child: const Text('Clear filters'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (model.error case final error?)
            AppErrorState(error: error, onRetry: model.load),
          if (model.busy)
            const AppLoadingState(message: 'Loading recorded actions…'),
          if (!model.busy && model.error == null && model.items.isEmpty)
            const AppEmptyState(
              title: 'No recorded actions match',
              message: 'Try other filters or refresh after an Admin change.',
              icon: Icons.history,
            ),
          if (model.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                '${model.items.length} loaded events · newest recorded first',
                style: theme.textTheme.labelLarge,
              ),
            ),
        ],
      ),
    );
  }
}
