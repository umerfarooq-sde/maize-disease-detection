import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/private_image.dart';
import '../../../core/widgets/source_reference_card.dart';
import '../../../data/models/reference_media.dart';

class ReferenceImageViewer extends StatelessWidget {
  const ReferenceImageViewer({required this.media, super.key});
  final ReferenceMedia media;

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    child: Scaffold(
      appBar: AppBar(
        toolbarHeight:
            kToolbarHeight * MediaQuery.textScalerOf(context).scale(1),
        leading: IconButton(
          tooltip: 'Close reference image',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(media.synthetic ? 'UI test image' : 'Reference photograph'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizing.contentMaxWidth,
            ),
            child: Column(
              children: [
                Expanded(
                  flex: 2,
                  child: ClipRect(
                    child: InteractiveViewer(
                      key: const Key('reference-image-zoom'),
                      minScale: 1,
                      maxScale: 4,
                      child: SizedBox.expand(
                        child: PrivateImage(
                          path: media.path!,
                          semanticLabel: media.altText,
                        ),
                      ),
                    ),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (media.synthetic)
                          const Text(
                            'SYNTHETIC TEST FIXTURE · not disease evidence',
                          ),
                        SelectableText(
                          media.altText,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text('Pinch to zoom. Pan to inspect the image.'),
                        const SizedBox(height: AppSpacing.sm),
                        SelectableText(
                          '${media.attribution}\nCredit: ${media.credit}\nLicense: ${media.license}',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SourceReferenceCard(reference: media.source),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
