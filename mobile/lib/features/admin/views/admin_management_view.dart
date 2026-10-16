import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_states.dart';
import '../../../data/models/admin_management.dart';
import '../view_models/admin_management_view_model.dart';
import '../widgets/management_editor_form.dart';

class AdminManagementView extends StatelessWidget {
  const AdminManagementView({super.key});
  Future<void> _status(
    BuildContext context,
    AdminManagementViewModel model,
    ManagementEntry item,
    String status,
  ) async {
    final confirmed = await confirmManagement(
      context,
      status == 'ACTIVE'
          ? 'Activate reviewed version?'
          : 'Deactivate this version?',
      status == 'ACTIVE'
          ? 'This publishes the selected version and may retire the previous active version/configuration. Source review is required; the classifier model is unchanged.'
          : 'This removes the selected version from current use. Historical content, results and version references remain.',
    );
    if (context.mounted && confirmed) await model.status(item, status);
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<AdminManagementViewModel>();
    final editor = model.editor;
    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Knowledge & configuration',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Classifier class mappings are read-only. Changing classes requires a new trained model version. Source and calculator changes are versioned and audited.',
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final area in ManagementArea.values)
                ChoiceChip(
                  label: Text(area.label),
                  selected: model.area == area,
                  onSelected: model.busy ? null : (_) => model.select(area),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          if (model.error case final error?) ...[
            AppErrorState(error: error, onRetry: model.refresh),
            if (error.kind.name == 'conflict')
              const Text(
                'The selected version or configuration changed. Refresh and review the latest state before trying again.',
              ),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (editor != null)
            ManagementEditorForm(
              key: ObjectKey(editor),
              editor: editor,
              busy: model.busy,
              onSave: model.save,
              onCancel: model.cancel,
            )
          else ...[
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: model.busy ? null : () => model.load(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh management'),
                ),
                FilledButton.icon(
                  onPressed: model.busy ? null : () => model.edit(),
                  icon: const Icon(Icons.add),
                  label: const Text('New reviewed draft'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (model.busy)
              const AppLoadingState(
                message: 'Working on reviewed configuration…',
              )
            else if (model.items.isEmpty && model.error == null)
              const AppEmptyState(
                title: 'No managed versions yet',
                message:
                    'Add only approved, sourced project content. No sample recommendations are seeded.',
              ),
            for (final item in model.items)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        model.area == ManagementArea.diseases
                            ? '${item.values['literalLabel']} · ${item.values['slug']} · ${item.status}'
                            : model.area == ManagementArea.fertilizers
                            ? 'Product metadata version ${item.version} · ${item.status}'
                            : '${item.values['documentKey'] ?? item.values['ruleKey'] ?? item.values['configKey']} · version ${item.version} · ${item.status}',
                      ),
                      if (model.area == ManagementArea.knowledge)
                        Text(
                          item.ready
                              ? 'Stored embeddings available; current policy is checked again on activation.'
                              : 'Embeddings must be built before activation.',
                        ),
                      Wrap(
                        spacing: AppSpacing.sm,
                        children: [
                          TextButton(
                            onPressed:
                                model.busy ||
                                    (model.area == ManagementArea.fertilizers &&
                                        item.values['contentEditable'] == false)
                                ? null
                                : () => model.edit(item),
                            child: Text(
                              model.area == ManagementArea.diseases
                                  ? 'Edit display metadata'
                                  : 'New version from this',
                            ),
                          ),
                          if (model.area == ManagementArea.knowledge &&
                              item.status == 'DRAFT')
                            OutlinedButton(
                              onPressed: model.busy
                                  ? null
                                  : () => model.index(item),
                              child: const Text('Build embeddings'),
                            ),
                          if (model.area == ManagementArea.fertilizers)
                            OutlinedButton(
                              onPressed: model.busy
                                  ? null
                                  : () => model.copyProduct(item),
                              child: const Text('Copy product to a new slug'),
                            ),
                          if (model.area != ManagementArea.diseases &&
                              model.area !=
                                  ManagementArea.modelSpecifications &&
                              item.status != 'ACTIVE' &&
                              (model.area != ManagementArea.knowledge ||
                                  item.status == 'DRAFT'))
                            TextButton(
                              onPressed: model.busy || !item.ready
                                  ? null
                                  : () =>
                                        _status(context, model, item, 'ACTIVE'),
                              child: const Text('Activate'),
                            ),
                          if (model.area != ManagementArea.diseases &&
                              model.area !=
                                  ManagementArea.modelSpecifications &&
                              (item.status == 'ACTIVE' ||
                                  (model.area == ManagementArea.knowledge &&
                                      item.status == 'DRAFT')))
                            TextButton(
                              onPressed: model.busy
                                  ? null
                                  : () => _status(
                                      context,
                                      model,
                                      item,
                                      model.area == ManagementArea.knowledge
                                          ? 'ARCHIVED'
                                          : 'INACTIVE',
                                    ),
                              child: const Text('Deactivate'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (model.nextCursor != null)
              OutlinedButton(
                onPressed: model.busy ? null : () => model.load(more: true),
                child: const Text('Load more versions'),
              ),
            if (model.area == ManagementArea.fertilizer ||
                model.area == ManagementArea.yieldRules)
              const Text(
                'Latest 100 stored versions are shown. New recommendations require approved project sources; existing formulas and historical versions are retained.',
              ),
          ],
        ],
      ),
    );
  }
}
