import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_cards.dart';
import '../../../data/models/model_health.dart';
import '../../disease_detection/utils/scan_presentation.dart';
import 'admin_metric_grid.dart';
import 'offline_model_metrics.dart';

class ModelIdentityPanel extends StatelessWidget {
  const ModelIdentityPanel({required this.data, super.key});
  final AdminModelHealth data;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final registry = data.entries.where(
      (entry) => entry.version == data.modelVersion,
    );
    final architecture =
        data.offline?.architecture ??
        (registry.isEmpty ? null : registry.first.architecture);
    return AppStatusPanel(
      tone: data.status == 'READY'
          ? AppStatusTone.information
          : AppStatusTone.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text('Deployed model', style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                data.status == 'READY'
                    ? Icons.check_circle_outline
                    : Icons.info_outline,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Live service: ${data.status}',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            data.modelVersion ?? 'Loaded model unavailable',
            style: theme.textTheme.titleLarge,
          ),
          Text(
            'Architecture: ${architecture ?? 'Unavailable'}\nPreprocessing: ${data.preprocessingVersion ?? 'Unavailable'}',
          ),
          const SizedBox(height: AppSpacing.md),
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
          if (data.status == 'INCOMPATIBLE')
            const Text(
              'The service reports incompatible model health. The response does not identify a specific artifact or hash failure.',
            ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Reported readiness is not a fresh inference test. Academic/FYP research only; commercial clearance and independent field validation are pending.',
          ),
        ],
      ),
    );
  }
}

class ModelConfidenceNotice extends StatelessWidget {
  const ModelConfidenceNotice({required this.policy, super.key});
  final String? policy;
  @override
  Widget build(BuildContext context) => AppStatusPanel(
    tone: AppStatusTone.warning,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Confidence policy and limitations',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('Reported policy: ${policy ?? 'Unavailable'}'),
        Text(switch (policy) {
          'UNCONFIGURED' =>
            'No validation-approved threshold is configured. Every successful prediction is marked low confidence; this is not a measured deterioration signal. High raw class scores are not verified diagnostic confidence.',
          'VALIDATION_BASED' =>
            'The service reports a validation-based policy. A model prediction remains distinct from a confirmed diagnosis or independent field validation.',
          _ =>
            'Policy information is unavailable. Do not infer certainty from raw class scores.',
        }),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Numeric threshold, temperature, calibration results and artifact hashes are not exposed in this Admin response. No values are inferred here.',
        ),
      ],
    ),
  );
}

class ModelRuntimePanel extends StatelessWidget {
  const ModelRuntimePanel({required this.data, super.key});
  final ModelRuntime? data;
  @override
  Widget build(BuildContext context) {
    final runtime = data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Runtime operational statistics',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'One FastAPI process since startup; counters reset on restart and do not aggregate multiple workers. Requests admitted to the authenticated prediction handler include invalid images, busy and unavailable outcomes. Authorization/query rejections are excluded.',
        ),
        const SizedBox(height: AppSpacing.lg),
        if (runtime == null)
          const Text(
            'Live statistics unavailable. Refresh after the internal service recovers.',
          )
        else ...[
          Text('Since ${scanDate(runtime.since)} (local)'),
          const SizedBox(height: AppSpacing.md),
          AdminMetricGrid(
            minimumColumnWidth: AppSizing.emblem * 3,
            children: [
              AdminMetricCard(
                label: 'Handler attempts',
                value: '${runtime.requests}',
                icon: Icons.receipt_long_outlined,
                note: 'In flight: ${runtime.inFlight}',
              ),
              AdminMetricCard(
                label: 'Succeeded',
                value: '${runtime.successes}',
                icon: Icons.check_circle_outline,
              ),
              AdminMetricCard(
                label: 'Failed',
                value: '${runtime.failures}',
                icon: Icons.error_outline,
              ),
              AdminMetricCard(
                label: 'Mean completed-request latency',
                value: runtime.meanLatencyMs == null
                    ? null
                    : '${runtime.meanLatencyMs!.toStringAsFixed(1)} ms',
                icon: Icons.timer_outlined,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Latency includes image reading, preprocessing and inference, including failed requests; excludes Node, Cloudinary and database time.',
          ),
          Text(
            'Low-confidence results: ${runtime.lowConfidence} · ${metricPercent(runtime.lowConfidenceRate)} of successes',
          ),
          Card(
            child: ExpansionTile(
              key: const PageStorageKey('runtime-prediction-distribution'),
              title: const Text('Prediction distribution'),
              subtitle: const Text(
                'Model outputs, not accuracy or disease prevalence',
              ),
              expansionAnimationStyle: AnimationStyle(
                duration: AppMotion.resolve(context, AppMotion.reveal),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      for (final entry in runtime.distribution.entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Semantics(
                            label:
                                '${diseaseLabel(entry.key)}: ${entry.value} of ${runtime.successes} successful outputs',
                            excludeSemantics: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  '${diseaseLabel(entry.key)}: ${entry.value}',
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                LinearProgressIndicator(
                                  value: runtime.successes == 0
                                      ? 0
                                      : entry.value / runtime.successes,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        const Text(
          'Drift detection is unavailable: no verified ground-truth feedback exists. Latency, uncertainty and label counts are monitoring signals only.',
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: () => context.go('/admin/ai-operations'),
          icon: const Icon(Icons.query_stats),
          label: const Text('View AI Operations'),
        ),
      ],
    );
  }
}
