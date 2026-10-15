import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_states.dart';
import '../../disease_detection/utils/scan_presentation.dart';
import '../view_models/model_health_view_model.dart';
import '../widgets/offline_model_metrics.dart';

class ModelHealthView extends StatelessWidget {
  const ModelHealthView({super.key});
  @override
  Widget build(BuildContext context) {
    final model = context.watch<ModelHealthViewModel>();
    final data = model.data;
    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Model health',
                  style: Theme.of(context).textTheme.headlineMedium,
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
            'Offline evaluation and live operational signals measure different things. Farmer predictions have no verified ground truth.',
          ),
          const SizedBox(height: AppSpacing.lg),
          if (model.loading)
            const AppLoadingState(message: 'Checking model healthâ€¦')
          else if (model.error case final error?)
            AppErrorState(error: error, onRetry: model.load)
          else if (data != null) ...[
            Text('Checked ${scanDate(data.asOf)} (local)'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Deployment and readiness',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(switch (data.registryStatus) {
                      'SINGLE_PRODUCTION' =>
                        'Production registry: ${data.productionVersion}',
                      'MULTIPLE_PRODUCTION' =>
                        'Registry conflict: multiple production models.',
                      _ => 'No model has been promoted to production.',
                    }),
                    Text(
                      'Configured research model: ${data.configuredVersion ?? 'Unavailable'}',
                    ),
                    Text('Live service: ${data.status}'),
                    if (data.modelVersion != null)
                      Text(
                        'Loaded model: ${data.modelVersion}\nPreprocessing: ${data.preprocessingVersion}',
                      ),
                    if (data.status == 'READY')
                      Text(
                        data.matchesProduction
                            ? 'Loaded version matches the production registry.'
                            : 'Loaded research version is not the single promoted production model.',
                      ),
                    if (data.status == 'READY' && !data.registered)
                      const Text(
                        'Loaded version is not present in the displayed registry.',
                      ),
                    const Text(
                      'Academic/FYP research only. Commercial clearance and independent field validation are pending.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
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
            Text(
              'Runtime operational statistics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'One FastAPI process since startup; counters reset on restart and do not aggregate multiple workers. Requests admitted to the authenticated prediction handler include invalid images, busy and unavailable outcomes. Authorization/query rejections are excluded.',
            ),
            if (data.runtime case final runtime?) ...[
              Text('Since ${scanDate(runtime.since)} (local)'),
              Text(
                'Requests: ${runtime.requests} Â· In flight: ${runtime.inFlight}\nSucceeded: ${runtime.successes} Â· Failed: ${runtime.failures}',
              ),
              Text(
                'Mean completed-request latency: ${runtime.meanLatencyMs?.toStringAsFixed(1) ?? 'Unavailable'} ms',
              ),
              const Text(
                'Includes image reading, preprocessing and inference, including failed requests; excludes Node, Cloudinary and database time.',
              ),
              Text(
                'Low-confidence results: ${runtime.lowConfidence} Â· ${metricPercent(runtime.lowConfidenceRate)} of successes',
              ),
              if (data.confidencePolicy == 'UNCONFIGURED')
                const Text(
                  'No validation-approved threshold is configured. Every successful prediction is marked low confidence; this is not a measured deterioration signal.',
                ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Prediction distribution',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Text(
                'Counts of model outputs, not accuracy or disease prevalence.',
              ),
              for (final entry in runtime.distribution.entries) ...[
                Text('${diseaseLabel(entry.key)}: ${entry.value}'),
                LinearProgressIndicator(
                  value: runtime.successes == 0
                      ? 0
                      : entry.value / runtime.successes,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ] else
              const Text(
                'Live statistics unavailable. Refresh after the internal service recovers.',
              ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Drift detection is unavailable: no verified ground-truth feedback exists. Latency, uncertainty and label counts are monitoring signals only.',
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Registered models',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Latest 50 registrations. Registration dates are not training dates.',
            ),
            for (final entry in data.entries)
              Card(
                child: ListTile(
                  title: Text(entry.version),
                  subtitle: Text(
                    '${entry.status} Â· ${entry.architecture}\n${entry.datasetVersion} Â· preprocessing ${entry.preprocessingVersion}\nRegistered ${scanDate(entry.registeredAt)} (local)',
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
