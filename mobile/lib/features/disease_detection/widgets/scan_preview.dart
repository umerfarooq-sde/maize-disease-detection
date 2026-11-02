import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/selected_leaf_image.dart';

class ScanPreview extends StatelessWidget {
  const ScanPreview({required this.image, this.submitted = false, super.key});
  final SelectedLeafImage image;
  final bool submitted;
  static const _aspectRatio = 4 / 3;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: _aspectRatio,
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Image.memory(
              image.bytes,
              key: const Key('leaf-image-preview'),
              fit: BoxFit.contain,
              cacheWidth: AppConstants.previewPixels,
              semanticLabel: 'Selected maize leaf photo',
              errorBuilder: (_, _, _) => const Center(
                child: Text(
                  'This photo cannot be previewed. Choose another photo.',
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: context.semanticColors.success,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      submitted ? 'Submitted leaf photo' : 'Review your photo',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${image.width} × ${image.height} · ${_formatName(image.mimeType)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  static String _formatName(String mimeType) => switch (mimeType) {
    'image/jpeg' => 'JPEG',
    'image/png' => 'PNG',
    'image/webp' => 'WebP',
    _ => 'Image',
  };
}
