import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/scan_record.dart';
import '../../../data/models/selected_leaf_image.dart';
import 'scan_preview.dart';

class ScanResultImage extends StatelessWidget {
  const ScanResultImage({required this.scan, this.selectedImage, super.key});
  final ScanRecord scan;
  final SelectedLeafImage? selectedImage;
  static const _aspectRatio = 4 / 3;

  @override
  Widget build(BuildContext context) {
    if (selectedImage case final image?) return ScanPreview(image: image);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: _aspectRatio,
        child: Image.network(
          scan.imageUrl.toString(),
          key: const Key('saved-leaf-image'),
          cacheWidth: AppConstants.previewPixels,
          fit: BoxFit.contain,
          semanticLabel: 'Saved maize leaf photo',
          errorBuilder: (_, _, _) => const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text('The saved photo preview is unavailable.'),
            ),
          ),
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}
