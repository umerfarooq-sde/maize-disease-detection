import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_states.dart';
import '../../../data/datasources/leaf_image_datasource.dart';
import '../view_models/scan_view_model.dart';
import '../widgets/scan_preview.dart';

class ScanView extends StatelessWidget {
  const ScanView({super.key});
  @override
  Widget build(BuildContext context) {
    final model = context.watch<ScanViewModel>();
    final text = Theme.of(context).textTheme;
    return AppPage(
      storageKey: 'scan-page',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Scan a maize leaf', style: text.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Start with a clear photo of one leaf. Review it before saving.',
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
                        : 'Saving your scan…',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          if (model.scan != null)
            Card(
              color: AppColors.sage,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: AppColors.forest,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Photo saved', style: text.titleLarge),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Your scan is saved. Disease analysis is not available yet.',
                    ),
                  ],
                ),
              ),
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
              label: const Text('Save leaf photo'),
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
              onPressed: model.busy ? null : model.clear,
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
