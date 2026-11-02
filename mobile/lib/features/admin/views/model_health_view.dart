import 'package:flutter/material.dart';
import '../widgets/admin_selectable_text.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_states.dart';
import '../../disease_detection/utils/scan_presentation.dart';
import '../view_models/model_health_view_model.dart';
import '../widgets/model_health_panels.dart';
import '../widgets/offline_model_metrics.dart';

class ModelHealthView extends StatelessWidget {
  const ModelHealthView({super.key});
  @override
  Widget build(BuildContext context) {
    final model = context.watch<ModelHealthViewModel>();
    final data = model.data;
    return AppPage(
      storageKey: 'admin-model-health',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Model health',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh model health',
                onPressed: model.loading ? null : model.load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const Text(
            'Read-only model evidence. Offline evaluation and live operational signals measure different things. Farmer predictions have no verified ground truth.',
          ),
          const SizedBox(height: AppSpacing.lg),
          if (model.loading)
            const AppLoadingState(message: 'Checking model health…')
          else if (model.error case final error?)
            AppErrorState(error: error, onRetry: model.load)
          else if (data != null) ...[
            Text(
              'Checked ${scanDate(data.asOf)} (local)',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            ModelIdentityPanel(data: data),
            const SizedBox(height: AppSpacing.xl),
            ModelConfidenceNotice(policy: data.confidencePolicy),
            const SizedBox(height: AppSpacing.xl),
            if (data.offline case final offline?)
              OfflineModelMetrics(data: offline)
            else
              const AppEmptyState(
                title: 'Offline evidence unavailable',
                message:
                    'A compatible loaded model with pinned evaluation evidence is required. Runtime predictions are never substituted for test metrics.',
                icon: Icons.science_outlined,
              ),
            const SizedBox(height: AppSpacing.xl),
            ModelRuntimePanel(data: data.runtime),
            const SizedBox(height: AppSpacing.xl),
            Card(
              child: ExpansionTile(
                key: const PageStorageKey('model-registry-details'),
                title: const Text('Technical details and registry'),
                subtitle: Text(
                  '${data.entries.length} displayed registrations · read-only',
                ),
                expansionAnimationStyle: AnimationStyle(
                  duration: AppMotion.resolve(context, AppMotion.reveal),
                ),
                children: [
                  KeyedSubtree(
                    key: const PageStorageKey('model-registry-body'),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Latest 50 registrations. Registration dates are not training dates. Artifact hashes and specific integrity diagnostics are not supplied by this API.',
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Supported classifier categories reported in this response',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (data.offline != null)
                            for (final item in data.offline!.classes)
                              AdminSelectableText(
                                '${diseaseLabel(item.label)} · ${item.label}',
                              )
                          else if (data.runtime != null)
                            for (final label in data.runtime!.distribution.keys)
                              AdminSelectableText(
                                '${diseaseLabel(label)} · $label',
                              )
                          else
                            const Text(
                              'Classifier categories unavailable. No historical mapping is substituted.',
                            ),
                          if (data.entries.isEmpty)
                            const Text('No registered models returned.'),
                          for (final entry in data.entries)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.lg,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  AdminSelectableText(
                                    entry.version,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  Text(
                                    'Status: ${entry.status}\nArchitecture: ${entry.architecture}\nDataset: ${entry.datasetVersion}\nPreprocessing: ${entry.preprocessingVersion}\nRegistered ${scanDate(entry.registeredAt)} (local)',
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
