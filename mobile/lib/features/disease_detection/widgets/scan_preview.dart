import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/selected_leaf_image.dart';

class ScanPreview extends StatelessWidget {
  const ScanPreview({required this.image, super.key});
  final SelectedLeafImage image;
  static const _aspectRatio = 4 / 3;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: _aspectRatio,
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
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'Review your leaf photo',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    ),
  );
}
