import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/scan_record.dart';
import '../../disease_detection/utils/scan_presentation.dart';
import '../../../core/widgets/private_image.dart';
import '../../../data/models/scan_prediction.dart';

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
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Selected scan', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.small),
                child: PrivateImage(
                  path: scan.imageUrl.toString(),
                  width: AppSizing.emblem,
                  height: AppSizing.emblem,
                  fit: BoxFit.cover,
                  semanticLabel: 'Selected saved scan thumbnail',
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (scan.prediction case final prediction?)
                      Text(
                        diseaseLabel(prediction.predictedClass),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    Text(
                      'Scanned ${scanDate(scan.createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (scan.prediction?.predictionStatus ==
              ScanPredictionStatus.lowConfidence)
            Text(
              'Uncertain result',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            )
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
