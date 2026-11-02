import 'package:flutter/material.dart';
import 'admin_selectable_text.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/horizontal_data_scroll.dart';
import '../../../data/models/model_health.dart';
import '../../disease_detection/utils/scan_presentation.dart';
import 'admin_metric_grid.dart';

String metricPercent(double? value) =>
    value == null ? 'Unavailable' : '${(value * 100).toStringAsFixed(2)}%';

class OfflineModelMetrics extends StatelessWidget {
  const OfflineModelMetrics({required this.data, super.key});
  final OfflineEvaluation data;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        header: true,
        child: Text(
          'Offline evaluation — research evidence',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      const Text(
        'Saved final-test results from the pinned model artifact. Descriptive research metrics on a previously inspected corpus; independent field accuracy is not established.',
      ),
      const SizedBox(height: AppSpacing.lg),
      AdminMetricGrid(
        children: [
          AdminMetricCard(
            label: 'Test accuracy',
            value: metricPercent(data.accuracy),
            icon: Icons.science_outlined,
          ),
          AdminMetricCard(
            label: 'Macro precision',
            value: metricPercent(data.precision),
            icon: Icons.filter_center_focus,
          ),
          AdminMetricCard(
            label: 'Macro recall',
            value: metricPercent(data.recall),
            icon: Icons.search,
          ),
          AdminMetricCard(
            label: 'Macro F1',
            value: metricPercent(data.f1),
            icon: Icons.balance,
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      Text('Final-test unique contents: ${data.sampleCount}'),
      Card(
        child: ExpansionTile(
          key: const PageStorageKey('offline-class-metrics'),
          title: const Text('Per-class test metrics'),
          subtitle: const Text(
            'Support, precision, recall, F1 and specificity',
          ),
          expansionAnimationStyle: AnimationStyle(
            duration: AppMotion.resolve(context, AppMotion.reveal),
          ),
          children: [
            for (final item in data.classes)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        diseaseLabel(item.label),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text('Support: ${item.support} unique contents'),
                      Text(
                        'Precision: ${metricPercent(item.precision)} · Recall: ${metricPercent(item.recall)}',
                      ),
                      Text(
                        'F1: ${metricPercent(item.f1)} · Specificity: ${metricPercent(item.specificity)}',
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      Card(
        child: ExpansionTile(
          key: const PageStorageKey('offline-confusion-matrix'),
          title: const Text('Saved confusion matrix'),
          subtitle: const Text('Actual versus predicted · saved counts'),
          expansionAnimationStyle: AnimationStyle(
            duration: AppMotion.resolve(context, AppMotion.reveal),
          ),
          children: [
            KeyedSubtree(
              key: const PageStorageKey('offline-matrix-body'),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Rows: actual class. Columns: predicted class. Counts, not percentages. Scroll horizontally.',
                    ),
                    HorizontalDataScroll(
                      child: DataTable(
                        headingRowHeight:
                            AppSizing.touchTarget *
                            MediaQuery.textScalerOf(context).scale(1) *
                            2,
                        dataRowMinHeight: AppSizing.touchTarget,
                        dataRowMaxHeight: double.infinity,
                        columns: [
                          const DataColumn(label: Text('Actual / predicted')),
                          for (final item in data.classes)
                            DataColumn(label: Text(diseaseLabel(item.label))),
                        ],
                        rows: [
                          for (var i = 0; i < data.classes.length; i++)
                            DataRow(
                              cells: [
                                DataCell(
                                  Text(diseaseLabel(data.classes[i].label)),
                                ),
                                for (var j = 0; j < data.classes.length; j++)
                                  DataCell(
                                    Semantics(
                                      label:
                                          'Actual ${diseaseLabel(data.classes[i].label)}, predicted ${diseaseLabel(data.classes[j].label)}: ${data.confusionMatrix[i][j]}',
                                      excludeSemantics: true,
                                      child: Text(
                                        '${data.confusionMatrix[i][j]}',
                                      ),
                                    ),
                                  ),
                              ],
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
      Card(
        child: ExpansionTile(
          key: const PageStorageKey('offline-evidence-details'),
          title: const Text('Evaluation provenance'),
          expansionAnimationStyle: AnimationStyle(
            duration: AppMotion.resolve(context, AppMotion.reveal),
          ),
          children: [
            KeyedSubtree(
              key: const PageStorageKey('offline-evidence-body'),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AdminSelectableText(
                        'Architecture: ${data.architecture}\nDataset: ${data.datasetVersion}\nExperiment: ${data.experimentId}',
                      ),
                      const Text(
                        'Training date: not recorded in artifact. Evaluation date and calibration results are not supplied by this response.',
                      ),
                      AdminSelectableText(
                        'Dataset/index fingerprint: ${data.indexFingerprint}',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
