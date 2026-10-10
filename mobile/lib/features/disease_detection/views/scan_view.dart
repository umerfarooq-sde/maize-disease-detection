import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_states.dart';
import '../../../data/datasources/leaf_image_datasource.dart';
import '../../../data/models/scan_record.dart';
import '../view_models/scan_result_arguments.dart';
import '../view_models/scan_view_model.dart';
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
          if (model.selecting)
            const AppLoadingState(message: 'Opening your photo…'),
          if (model.uploading)
            Semantics(
              liveRegion: true,
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: model.progress < 1 ? model.progress : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    model.progress < 1
                        ? 'Uploading photo… ${(model.progress * 100).round()}%'
                        : 'Waiting for analysis…',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          if (model.polling)
            const AppLoadingState(message: 'Checking analysis status…'),
          if (model.scan case final scan?)
            ScanResultCard(
              scan: scan,
              showImage: false,
              busy: model.busy,
              onRetry: model.analysisFailed ? model.upload : null,
              onRefresh: model.refreshAnalysis,
            ),
          if (model.error case final error?)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: AppErrorState(error: error, onRetry: model.retry),
            ),
          if (model.image != null && model.scan == null) ...[
            FilledButton.icon(
              key: const Key('upload-leaf-action'),
              onPressed: model.busy ? null : model.upload,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Analyze leaf'),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          OutlinedButton.icon(
            key: const Key('gallery-leaf-action'),
            onPressed: model.busy
                ? null
                : () => model.select(LeafImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(
              model.image == null
                  ? 'Choose from gallery'
                  : 'Choose another photo',
            ),
          ),
          if (model.cameraSupported) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              key: const Key('camera-leaf-action'),
              onPressed: model.busy
                  ? null
                  : () => model.select(LeafImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Take a photo'),
            ),
          ],
          if (model.image != null) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: model.selecting || model.uploading
                  ? null
                  : model.clear,
              child: Text(
                model.scan == null ? 'Remove photo' : 'Start a new scan',
              ),
            ),
          ],
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

class _PhotoGuide extends StatelessWidget {
  const _PhotoGuide();
  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.sage,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.eco_outlined,
            size: AppSizing.emblem,
            color: AppColors.forest,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'A good photo starts here',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Use natural light. Keep the leaf in focus and fill the photo with its surface.',
          ),
        ],
      ),
    ),
  );
}
