import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/datasources/leaf_image_datasource.dart';
import '../view_models/scan_view_model.dart';

class ScanReadyActions extends StatelessWidget {
  const ScanReadyActions({required this.model, super.key});

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

class ScanSelectedActions extends StatelessWidget {
  const ScanSelectedActions({required this.model, super.key});

  final ScanViewModel model;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        liveRegion: true,
        child: const Text(
          'Review the whole leaf. Nothing is submitted until you choose Analyze leaf.',
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      FilledButton.icon(
        key: const Key('upload-leaf-action'),
        onPressed: model.upload,
        icon: const Icon(Icons.document_scanner_outlined),
        label: const Text('Analyze leaf'),
      ),
      const SizedBox(height: AppSpacing.md),
      ScanReselectActions(model: model, removeLabel: 'Remove photo'),
    ],
  );
}

class ScanReselectActions extends StatelessWidget {
  const ScanReselectActions({
    required this.model,
    required this.removeLabel,
    super.key,
  });

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
