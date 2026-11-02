import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_states.dart';
import '../../../data/models/admin_management.dart';
import '../view_models/admin_management_view_model.dart';
import 'admin_draft_guard.dart';
import 'admin_editor_section.dart';
import 'management_editor_form.dart';
import 'calculator_editor_sections.dart';
import 'admin_calculator_card.dart';
import 'admin_record_page.dart';

class AdminContentManagement extends StatefulWidget {
  const AdminContentManagement({
    required this.onStatus,
    this.onAreaChanged,
    super.key,
  });
  final ValueChanged<ManagementArea>? onAreaChanged;
  final Future<void> Function(ManagementEntry, String) onStatus;
  @override
  State<AdminContentManagement> createState() => _AdminContentManagementState();
}

class _AdminContentManagementState extends State<AdminContentManagement> {
  String _query = '', _status = 'ALL';
  Future<void> _area(ManagementArea area) async {
    final model = context.read<AdminManagementViewModel>();
    if (model.busy || model.area == area) return;
    if (!await (context.read<AdminDraftGuard?>()?.leave(context) ??
            Future.value(true)) ||
        !mounted) {
      return;
    }
    if (widget.onAreaChanged case final change?) {
      change(area);
    } else {
      await model.select(area);
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<AdminManagementViewModel>();
    final disease = model.area == ManagementArea.diseases;
    final editor = model.editor;
    final calculator = isCalculatorManagement(model.area);
    final visible = model.items
        .where(
          (item) =>
              (_status == 'ALL' || item.status == _status) &&
              [
                item.title,
                item.values['slug'],
                item.values['documentKey'],
                item.values['knowledgeType'],
                item.values['diseaseSlug'],
                item.values['ruleKey'],
                item.values['configKey'],
                calculatorMap(item.values['draftInput'])['modelKey'],
                calculatorMap(
                  calculatorMap(item.values['draftInput'])['product'],
                )['slug'],
              ].join(' ').toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            calculator
                ? calculatorHeading(model.area)
                : disease
                ? 'Disease catalogue'
                : 'Knowledge documents',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (!calculator) const Text('Classifier class mappings are read-only.'),
        if (model.area == ManagementArea.modelSpecifications)
          const Text(
            'Pending domain approval / Disabled — specifications do not execute calculations.',
          ),
        ExpansionTile(
          key: PageStorageKey('management-scope-${model.area.name}'),
          title: const Text('Workflow and scope'),
          expansionAnimationStyle: AnimationStyle(
            duration: AppMotion.resolve(context, AppMotion.reveal),
          ),
          children: [
            Text(
              calculator
                  ? calculatorPurpose(model.area)
                  : disease
                  ? 'Manage display identity and reviewed metadata. Classifier class mappings are read-only; changes never retrain the model.'
                  : 'Source-backed, versioned knowledge. Classifier class mappings are read-only. Save Draft → Build Embeddings → Activate. Each operation is confirmed separately.',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final area
                in calculator
                    ? [
                        ManagementArea.fertilizers,
                        ManagementArea.fertilizer,
                        ManagementArea.yieldRules,
                        ManagementArea.modelSpecifications,
                      ]
                    : [ManagementArea.diseases, ManagementArea.knowledge])
              ChoiceChip(
                label: Text(area.label),
                selected: model.area == area,
                onSelected: model.busy ? null : (_) => _area(area),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (model.error case final error?) ...[
          AppErrorState(
            error: error,
            onRetry: () async {
              if (await (context.read<AdminDraftGuard?>()?.leave(context) ??
                      Future.value(editor == null)) &&
                  context.mounted) {
                await model.refresh();
              }
            },
          ),
          if (editor != null)
            const Text(
              'Your draft is retained. Review the error before saving again. Cancel editing to refresh the latest stored version; unsaved changes require confirmation.',
            ),
          if (error.kind.name == 'conflict')
            const Text(
              'Version conflict: a newer change exists. Nothing was overwritten. Keep a copy of your edits before discarding and reviewing the latest state.',
            ),
        ],
        if (editor != null)
          ManagementEditorForm(
            key: ObjectKey(editor),
            editor: editor,
            busy: model.busy,
            onSave: (values) async {
              await model.save(values);
              if (context.mounted &&
                  model.error == null &&
                  model.editor == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      calculator
                          ? model.area == ManagementArea.modelSpecifications
                                ? 'Specification saved. Execution remains disabled.'
                                : model.area == ManagementArea.fertilizers
                                ? 'Product metadata saved. Check the returned visibility and eligibility.'
                                : 'Draft saved. Activation remains a separate confirmed action.'
                          : disease
                          ? 'Display metadata saved.'
                          : 'Draft saved. Build embeddings, then activate when eligible.',
                    ),
                  ),
                );
              }
            },
            onCancel: model.cancel,
          )
        else ...[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton.icon(
                onPressed: model.busy ? null : () => model.edit(),
                icon: const Icon(Icons.add),
                label: Text(
                  model.area == ManagementArea.fertilizers
                      ? 'New reviewed product'
                      : disease
                      ? 'New informational entry'
                      : 'New reviewed draft',
                ),
              ),
              OutlinedButton.icon(
                onPressed: model.busy ? null : () => model.load(),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh management'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            key: const Key('admin-content-filter'),
            decoration: const InputDecoration(
              labelText: 'Filter loaded records',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Local filter only. Load more versions to include additional records; this does not search the full database.',
          ),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final status in [
                'ALL',
                if (model.area != ManagementArea.modelSpecifications) 'ACTIVE',
                if (!disease) 'DRAFT',
                if (model.area != ManagementArea.modelSpecifications)
                  disease || calculator ? 'INACTIVE' : 'ARCHIVED',
              ])
                FilterChip(
                  label: Text(status),
                  selected: _status == status,
                  onSelected: (_) => setState(() => _status = status),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${visible.length} matching / ${model.items.length} loaded records',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          if (model.busy)
            const AppLoadingState(
              message: 'Working on reviewed content…',
              inline: true,
            )
          else if (visible.isEmpty && model.error == null)
            AppEmptyState(
              title: model.items.isEmpty
                  ? 'No managed content yet'
                  : 'No loaded matches',
              message: model.items.isEmpty
                  ? 'Add only approved, sourced content. No recommendations or disease facts are seeded.'
                  : 'Change the local filter or load another page.',
            ),
        ],
      ],
    );
    if (editor != null) {
      return AppPage(
        storageKey:
            'admin-content-${model.area.name}-editor-${identityHashCode(editor)}',
        maxWidth: AppSizing.formMaxWidth,
        child: header,
      );
    }
    return AdminRecordPage(
      storageKey: 'admin-content-${model.area.name}-list',
      header: header,
      count: visible.length,
      itemBuilder: (context, index) {
        final item = visible[index];
        return calculator
            ? AdminCalculatorCard(
                key: ValueKey(item.id),
                area: model.area,
                item: item,
                busy: model.busy,
                onEdit: () => model.edit(item),
                onCopy: () => model.copyProduct(item),
                onStatus: (status) => widget.onStatus(item, status),
              )
            : AdminContentEntryCard(
                key: ValueKey(item.id),
                item: item,
                disease: disease,
                items: model.items,
                busy: model.busy,
                onEdit: () => model.edit(item),
                onIndex: () => model.index(item),
                onStatus: (status) => widget.onStatus(item, status),
              );
      },
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (calculator &&
              model.nextCursor == null &&
              [
                ManagementArea.fertilizer,
                ManagementArea.yieldRules,
                ManagementArea.modelSpecifications,
              ].contains(model.area))
            const Text(
              'Latest 100 stored versions are returned by the existing API. Local filtering does not search earlier versions.',
            ),
          if (model.nextCursor != null)
            OutlinedButton(
              onPressed: model.busy ? null : () => model.load(more: true),
              child: const Text('Load more versions'),
            ),
        ],
      ),
    );
  }
}

class AdminContentEntryCard extends StatelessWidget {
  const AdminContentEntryCard({
    required this.item,
    required this.disease,
    required this.items,
    required this.busy,
    required this.onEdit,
    required this.onIndex,
    required this.onStatus,
    super.key,
  });
  final ManagementEntry item;
  final bool disease, busy;
  final List<ManagementEntry> items;
  final VoidCallback onEdit, onIndex;
  final ValueChanged<String> onStatus;
  @override
  Widget build(BuildContext context) {
    final data = item.values;
    final metadata = data['catalogueMetadata'];
    final source = disease && metadata is Map
        ? metadata['source']
        : data['source'];
    final active = items.where(
      (entry) =>
          entry.values['documentKey'] == data['documentKey'] &&
          entry.status == 'ACTIVE',
    );
    String count(Object? value) =>
        value is List ? '${value.length}' : 'unavailable';
    return Card(
      key: ValueKey('content-${item.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminContentStatus(item.status),
            const SizedBox(height: AppSpacing.md),
            Text(item.title, style: Theme.of(context).textTheme.titleLarge),
            if (disease) ...[
              Text(
                data['literalLabel'] == null
                    ? 'Informational entry · not a trained output'
                    : 'Classifier context · ${data['literalLabel']}',
              ),
              Text('Protected slug · ${data['slug']}'),
              if (data['scientificName'] case final String name
                  when name.isNotEmpty)
                Text(name, style: Theme.of(context).textTheme.bodyMedium),
              if (data['description'] case final String description)
                Text(description, maxLines: 3, overflow: TextOverflow.ellipsis),
              if (metadata is Map)
                Text(
                  'Metadata entries · ${count(metadata['growthStages'])} growth-stage entries · ${count(metadata['severityDescriptors'])} severity descriptors',
                ),
              if (data['literalLabel'] == 'Healthy')
                const Text(
                  'Healthy / scouting context. A model label is not a field-wide health guarantee.',
                ),
            ] else ...[
              Text('${data['diseaseSlug']} · ${data['knowledgeType']}'),
              SelectableText(
                'Series ${data['documentKey']} · version ${item.version}',
              ),
              Text(
                active.isEmpty
                    ? 'Active version not present among loaded records.'
                    : 'Active version in loaded records: ${active.map((entry) => entry.version).join(', ')}',
              ),
              Text(
                item.ready
                    ? 'Stored embeddings available; current policy is checked again on activation.'
                    : 'Embeddings must be built before activation.',
              ),
            ],
            if (source is Map)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  'Source · ${source['title'] ?? 'Title unavailable'}\nPublisher · ${source['publisher'] ?? 'Unavailable'}',
                ),
              ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                TextButton.icon(
                  onPressed: busy ? null : onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(
                    disease ? 'Edit display metadata' : 'New version from this',
                  ),
                ),
                if (!disease && item.status == 'DRAFT')
                  OutlinedButton(
                    onPressed: busy ? null : onIndex,
                    child: const Text('Build embeddings'),
                  ),
                if (!disease && item.status == 'DRAFT')
                  TextButton(
                    onPressed: busy || !item.ready
                        ? null
                        : () => onStatus('ACTIVE'),
                    child: const Text('Activate'),
                  ),
                if (!disease && ['DRAFT', 'ACTIVE'].contains(item.status))
                  TextButton(
                    onPressed: busy ? null : () => onStatus('ARCHIVED'),
                    child: const Text('Deactivate'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
