import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/scan_record.dart';
import '../../disease_detection/utils/scan_presentation.dart';
import '../../disease_detection/widgets/prediction_summary.dart';

class AssistantScanContext extends StatelessWidget {
  const AssistantScanContext({
    required this.scan,
    required this.busy,
    required this.onExplain,
    required this.onClear,
    super.key,
  });

  final ScanRecord scan;
  final bool busy;
  final VoidCallback onExplain;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.sage,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Selected scan', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text('Scanned ${scanDate(scan.createdAt)}'),
          const SizedBox(height: AppSpacing.md),
          if (scan.prediction case final prediction?)
            PredictionSummary(prediction: prediction)
          else
            Text(scanStatusLabel(scan.status)),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            key: const Key('assistant-explain-scan'),
            onPressed: busy || scan.status != ScanStatus.completed
                ? null
                : onExplain,
            icon: const Icon(Icons.auto_stories_outlined),
            label: const Text('Explain this model prediction'),
          ),
          TextButton(
            key: const Key('assistant-clear-scan'),
            onPressed: busy ? null : onClear,
            child: const Text('Remove selected scan'),
          ),
        ],
      ),
    ),
  );
}
