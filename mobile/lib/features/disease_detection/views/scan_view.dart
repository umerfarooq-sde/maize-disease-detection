import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_states.dart';
import '../../../data/datasources/leaf_image_datasource.dart';
import '../../../data/models/scan_record.dart';
import '../view_models/scan_result_arguments.dart';
import '../view_models/scan_view_model.dart';
import '../utils/scan_polling.dart';
import '../widgets/scan_preview.dart';
import '../widgets/scan_result_card.dart';

class ScanView extends StatefulWidget {
  const ScanView({this.onResult, super.key});
  final ValueChanged<ScanResultArguments>? onResult;
  @override
  State<ScanView> createState() => _ScanViewState();
}

class _ScanViewState extends State<ScanView> {
  String? _deliveredScanId;
  @override
  Widget build(BuildContext context) {
    final model = context.watch<ScanViewModel>();
    if (model.scan == null) _deliveredScanId = null;
    final result = model.resultArguments;
    if (widget.onResult != null &&
        result?.scan.status == ScanStatus.completed &&
        _deliveredScanId != result!.scan.id) {
      _deliveredScanId = result.scan.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            model.scan?.id == result.scan.id &&
            model.scan?.status == ScanStatus.completed) {
          widget.onResult?.call(result);
        }
      });
    }
    final text = Theme.of(context).textTheme;
    final stage = model.stage;
    return AppPage(
      storageKey: 'scan-page',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Scan a maize leaf', style: text.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Start with a clear photo of one leaf. Review it before analysis.',
            style: text.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (model.image case final image?)
            ScanPreview(image: image)
          else
            const _PhotoGuide(),
          const SizedBox(height: AppSpacing.lg),
          _StageTransition(
            stage: stage,
            child: switch (stage) {
              ScanFlowStage.idle => _IdleActions(model: model),
              ScanFlowStage.selecting => AppLoadingState(
                message: model.lastSource == LeafImageSource.camera
                    ? 'Opening your camera…'
                    : 'Opening your photos…',
              ),
              ScanFlowStage.selected => _SelectedActions(model: model),
              ScanFlowStage.uploading => _UploadState(progress: model.progress),
              ScanFlowStage.processing => _ProcessingState(
                scan: model.scan!,
                checking: model.polling,
                onRefresh: model.refreshAnalysis,
                onNewScan: model.clear,
              ),
              ScanFlowStage.completed =>
                widget.onResult == null
                    ? ScanResultCard(scan: model.scan!, showImage: false)
                    : const AppSuccessState(
                        title: 'Analysis complete',
                        message: 'Opening your results…',
                      ),
              ScanFlowStage.failed => _FailedState(model: model),
              ScanFlowStage.error => _ScanErrorState(model: model),
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'JPEG, PNG or WebP · up to 5 MB and 16 megapixels. Sign-in is optional for leaf uploads.',
            style: text.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Photograph only the leaf. Avoid faces, documents and location details.',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _StageTransition extends StatelessWidget {
  const _StageTransition({required this.stage, required this.child});

  final ScanFlowStage stage;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180),
    curve: Curves.easeOutCubic,
    alignment: Alignment.topCenter,
    child: KeyedSubtree(key: ValueKey(stage), child: child),
  );
}

class _IdleActions extends StatelessWidget {
  const _IdleActions({required this.model});

  final ScanViewModel model;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (model.cameraSupported)
        FilledButton.icon(
          key: const Key('camera-leaf-action'),
          onPressed: () => model.select(LeafImageSource.camera),
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('Take a leaf photo'),
        )
      else
        FilledButton.icon(
          key: const Key('gallery-leaf-action'),
          onPressed: () => model.select(LeafImageSource.gallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Choose from gallery'),
        ),
      if (model.cameraSupported) ...[
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          key: const Key('gallery-leaf-action'),
          onPressed: () => model.select(LeafImageSource.gallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Choose from gallery'),
        ),
      ],
    ],
  );
}

class _SelectedActions extends StatelessWidget {
  const _SelectedActions({required this.model});

  final ScanViewModel model;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        liveRegion: true,
        child: const Text(
          'Photo ready. Review the image, then choose Analyze leaf.',
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      FilledButton.icon(
        key: const Key('upload-leaf-action'),
        onPressed: model.upload,
        icon: const Icon(Icons.document_scanner_outlined),
        label: const Text('Analyze this leaf'),
      ),
      const SizedBox(height: AppSpacing.md),
      _ReselectActions(model: model, removeLabel: 'Remove photo'),
    ],
  );
}

class _ReselectActions extends StatelessWidget {
  const _ReselectActions({required this.model, required this.removeLabel});

  final ScanViewModel model;
  final String removeLabel;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: [
      OutlinedButton.icon(
        key: const Key('gallery-leaf-action'),
        onPressed: () => model.select(LeafImageSource.gallery),
        icon: const Icon(Icons.photo_library_outlined),
        label: const Text('Choose another photo'),
      ),
      if (model.cameraSupported)
        OutlinedButton.icon(
          key: const Key('camera-leaf-action'),
          onPressed: () => model.select(LeafImageSource.camera),
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('Take another photo'),
        ),
      TextButton.icon(
        onPressed: model.clear,
        icon: const Icon(Icons.close),
        label: Text(removeLabel),
      ),
    ],
  );
}

class _UploadState extends StatelessWidget {
  const _UploadState({required this.progress});

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
              LinearProgressIndicator(value: transferring ? progress : null),
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

class _ProcessingState extends StatelessWidget {
  const _ProcessingState({
    required this.scan,
    required this.checking,
    required this.onRefresh,
    required this.onNewScan,
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
                    if (checking)
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

class _FailedState extends StatelessWidget {
  const _FailedState({required this.model});

  final ScanViewModel model;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ScanResultCard(
        scan: model.scan!,
        showImage: false,
        busy: model.busy,
        onRetry: model.canRetryAnalysis ? model.upload : null,
      ),
      const SizedBox(height: AppSpacing.md),
      _ReselectActions(model: model, removeLabel: 'Start a new scan'),
    ],
  );
}

class _ScanErrorState extends StatelessWidget {
  const _ScanErrorState({required this.model});

  final ScanViewModel model;

  @override
  Widget build(BuildContext context) {
    final error = model.error!;
    final pending = model.scan != null && analysisPending(model.scan!);
    final title = switch (error.kind) {
      AppErrorKind.imageAccess
          when model.lastSource == LeafImageSource.camera =>
        'Camera access is needed',
      AppErrorKind.imageAccess => 'Photo access is needed',
      AppErrorKind.invalidImage => 'This photo is not supported',
      AppErrorKind.imageTooLarge => 'This photo is too large',
      AppErrorKind.network || AppErrorKind.timeout =>
        pending ? 'Could not check the analysis' : 'Upload interrupted',
      AppErrorKind.server ||
      AppErrorKind.uploadInProgress => 'Analysis service is busy',
      _ => 'We could not continue',
    };
    final retryLabel = pending
        ? 'Check status again'
        : model.image != null &&
              error.kind != AppErrorKind.invalidImage &&
              error.kind != AppErrorKind.imageTooLarge &&
              error.kind != AppErrorKind.imageAccess
        ? 'Try upload again'
        : model.lastSource == LeafImageSource.camera
        ? 'Try camera again'
        : 'Choose photo again';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: AppEmptyState(
            title: title,
            message: error.message,
            icon: error.kind == AppErrorKind.imageAccess
                ? Icons.no_photography_outlined
                : Icons.cloud_off_outlined,
            action: FilledButton.icon(
              key: const Key('scan-retry-action'),
              onPressed: model.retry,
              icon: const Icon(Icons.refresh),
              label: Text(retryLabel),
            ),
          ),
        ),
        if (model.image != null && !pending) ...[
          const SizedBox(height: AppSpacing.md),
          _ReselectActions(model: model, removeLabel: 'Remove photo'),
        ] else if (model.image == null &&
            model.lastSource == LeafImageSource.camera) ...[
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            key: const Key('gallery-leaf-action'),
            onPressed: () => model.select(LeafImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Choose from gallery instead'),
          ),
        ],
      ],
    );
  }
}

class _PhotoGuide extends StatelessWidget {
  const _PhotoGuide();
  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.eco_outlined,
            size: AppSizing.emblem,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'A good photo starts here',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('Use natural light and keep the leaf in focus.'),
          const SizedBox(height: AppSpacing.md),
          const _GuideTip(
            icon: Icons.center_focus_strong,
            text: 'Fill the frame with one leaf.',
          ),
          const SizedBox(height: AppSpacing.sm),
          const _GuideTip(
            icon: Icons.wb_sunny_outlined,
            text: 'Avoid harsh shadows and blur.',
          ),
        ],
      ),
    ),
  );
}

class _GuideTip extends StatelessWidget {
  const _GuideTip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        icon,
        size: AppSizing.icon,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: Text(text)),
    ],
  );
}
