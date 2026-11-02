import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_states.dart';
import '../../../data/datasources/leaf_image_datasource.dart';
import '../../../data/models/scan_record.dart';
import '../../../data/models/selected_leaf_image.dart';
import '../../../core/widgets/app_cards.dart';
import '../view_models/scan_result_arguments.dart';
import '../view_models/scan_view_model.dart';
import '../utils/scan_polling.dart';
import '../widgets/scan_preview.dart';
import '../widgets/scan_photo_guide.dart';
import '../widgets/scan_operation_status.dart';
import '../widgets/scan_photo_actions.dart';
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
      maxWidth: AppSizing.readingMaxWidth,
      storageKey: 'scan-page',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text('Scan a maize leaf', style: text.headlineMedium),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Start with a clear photo of one leaf. Review it before analysis.',
            style: text.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.xl),
          const _SelectionPreview(),
          const SizedBox(height: AppSpacing.lg),
          _StageTransition(
            stage: stage,
            child: switch (stage) {
              ScanFlowStage.idle => ScanReadyActions(model: model),
              ScanFlowStage.selecting => AppLoadingState(
                message: model.lastSource == LeafImageSource.camera
                    ? 'Opening your camera…'
                    : 'Opening your photos…',
              ),
              ScanFlowStage.selected => ScanSelectedActions(model: model),
              ScanFlowStage.uploading => ScanUploadStatus(
                progress: model.progress,
              ),
              ScanFlowStage.processing => ScanProcessingStatus(
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
            'JPEG, PNG or WebP · up to 5 MiB and 16 megapixels. Sign-in is optional for leaf uploads.',
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
  Widget build(BuildContext context) {
    final content = KeyedSubtree(key: ValueKey(stage), child: child);
    // A reduced-motion transition needs no size controller at all. Keeping an
    // AnimatedSize with a zero duration can re-dirty its own layout on changes.
    if (MediaQuery.disableAnimationsOf(context)) return content;
    return AnimatedSize(
      duration: AppMotion.navigation,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: content,
    );
  }
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
      ScanReselectActions(model: model, removeLabel: 'Start a new scan'),
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
            tone: AppStatusTone.error,
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
          ScanReselectActions(model: model, removeLabel: 'Remove photo'),
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

class _SelectionPreview extends StatelessWidget {
  const _SelectionPreview();
  @override
  Widget build(BuildContext context) =>
      Selector<ScanViewModel, SelectedLeafImage?>(
        selector: (_, model) => model.image,
        builder: (_, image, _) =>
            image == null ? const ScanPhotoGuide() : ScanPreview(image: image),
      );
}
