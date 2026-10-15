import 'package:flutter/material.dart';
import '../../../core/widgets/private_image.dart';
import '../../../data/models/scan_record.dart';
import '../../../data/models/selected_leaf_image.dart';
import 'scan_preview.dart';

class ScanResultImage extends StatelessWidget {
  const ScanResultImage({
    required this.scan,
    this.selectedImage,
    this.anonymousKey,
    super.key,
  });
  final String? anonymousKey;
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
        child: PrivateImage(
          path: scan.imageUrl.toString(),
          anonymousKey: anonymousKey,
          key: const Key('saved-leaf-image'),
          fit: BoxFit.contain,
          semanticLabel: 'Saved maize leaf photo',
        ),
      ),
    );
  }
}
