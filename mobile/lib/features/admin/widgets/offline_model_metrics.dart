import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/model_health.dart';
import '../../disease_detection/utils/scan_presentation.dart';

String metricPercent(double? value) =>
    value == null ? 'Unavailable' : '${(value * 100).toStringAsFixed(2)}%';

class OfflineModelMetrics extends StatelessWidget {
  const OfflineModelMetrics({required this.data, super.key});
  final OfflineEvaluation data;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Offline evaluation', style: Theme.of(context).textTheme.titleLarge),
      const Text(
        'Saved final-test results from the pinned model artifact. Descriptive research metrics on a previously inspected corpus; independent field accuracy is not established.',
      ),
      const SizedBox(height: AppSpacing.md),
      Text(
        'Architecture: ${data.architecture}\nDataset: ${data.datasetVersion}\nExperiment: ${data.experimentId}\nTraining date: not recorded in artifact\nFinal-test unique contents: ${data.sampleCount}',
      ),
      SelectableText('Dataset/index fingerprint: ${data.indexFingerprint}'),
      const SizedBox(height: AppSpacing.md),
      Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        children: [
          _metric('Test accuracy', data.accuracy),
          _metric('Macro precision', data.precision),
          _metric('Macro recall', data.recall),
          _metric('Macro F1', data.f1),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      const Text(
        'Per-class test metrics Â· scroll horizontally for all columns',
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Class')),
            DataColumn(label: Text('Support')),
            DataColumn(label: Text('Precision')),
            DataColumn(label: Text('Recall')),
            DataColumn(label: Text('F1')),
            DataColumn(label: Text('Specificity')),
          ],
          rows: [
            for (final item in data.classes)
              DataRow(
                cells: [
                  DataCell(Text(diseaseLabel(item.label))),
                  DataCell(Text('${item.support}')),
                  DataCell(Text(metricPercent(item.precision))),
                  DataCell(Text(metricPercent(item.recall))),
                  DataCell(Text(metricPercent(item.f1))),
                  DataCell(Text(metricPercent(item.specificity))),
                ],
              ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      Text(
        'Saved confusion matrix',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const Text(
        'Rows: actual class. Columns: predicted class. Counts, not percentages. Scroll horizontally.',
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            const DataColumn(label: Text('Actual / predicted')),
            for (final label in modelLabels)
              DataColumn(label: Text(diseaseLabel(label))),
          ],
          rows: [
            for (var i = 0; i < 4; i++)
              DataRow(
                cells: [
                  DataCell(Text(diseaseLabel(modelLabels[i]))),
                  for (final count in data.confusionMatrix[i])
                    DataCell(Text('$count')),
                ],
              ),
          ],
        ),
      ),
    ],
  );
  Widget _metric(String label, double value) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(label), Text(metricPercent(value))],
      ),
    ),
  );
}
