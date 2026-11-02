import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/scan_record.dart';

class ScanUploadStatus extends StatelessWidget {
  const ScanUploadStatus({required this.progress, super.key});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final transferring = progress < 1;
    final percent = (progress * 100).round();
    return Semantics(
      liveRegion: true,
      label: transferring
          ? 'Uploading photo, $percent percent'
          : 'Upload sent, waiting for the server',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                transferring ? 'Uploading securely' : 'Finalizing upload',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              LinearProgressIndicator(
                value: transferring
                    ? progress
                    : MediaQuery.disableAnimationsOf(context)
                    ? 1
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                transferring
                    ? 'Uploading photo… $percent%'
                    : 'The photo is uploaded. Waiting for the server to save it safely…',
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Keep this screen open until the upload finishes.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScanProcessingStatus extends StatelessWidget {
  const ScanProcessingStatus({
    required this.scan,
    required this.checking,
    required this.onRefresh,
    required this.onNewScan,
    super.key,
  });

  final ScanRecord scan;
  final bool checking;
  final VoidCallback onRefresh;
  final VoidCallback onNewScan;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        liveRegion: true,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (checking && !MediaQuery.disableAnimationsOf(context))
                      const SizedBox.square(
                        dimension: AppSizing.stateIcon,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    else
                      Icon(
                        Icons.schedule_outlined,
                        size: AppSizing.stateIcon,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Text(
                        scan.status == ScanStatus.processing
                            ? 'Analyzing your leaf'
                            : 'Waiting for analysis',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  'Your photo is saved. The service is still analyzing it.',
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  checking
                      ? 'Analyzing leaf… checking status'
                      : 'Analysis is taking longer than usual. You can check again safely.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (!checking) ...[
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton.icon(
                    key: const Key('refresh-analysis-action'),
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Check analysis status'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      TextButton(onPressed: onNewScan, child: const Text('Start a new scan')),
    ],
  );
}
