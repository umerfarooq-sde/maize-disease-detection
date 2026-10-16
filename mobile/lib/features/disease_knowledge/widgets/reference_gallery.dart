import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/private_image.dart';
import '../../../core/widgets/source_reference_card.dart';
import '../../../data/repositories/reference_media_repository.dart';
import '../view_models/reference_gallery_view_model.dart';

class ReferenceGallery extends StatelessWidget {
  const ReferenceGallery({required this.slug, super.key});
  final String slug;
  @override
  Widget build(BuildContext context) {
    final repository = context.read<ReferenceMediaRepository?>();
    if (repository == null) {
      return const Text('No approved reference images available.');
    }
    return ChangeNotifierProvider(
      create: (_) => ReferenceGalleryViewModel(repository, slug)..load(),
      child: Consumer<ReferenceGalleryViewModel>(
        builder: (context, model, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Reference images',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (model.busy)
              const Center(child: CircularProgressIndicator())
            else if (model.error != null)
              TextButton(
                onPressed: model.load,
                child: const Text('Could not load reference images. Retry'),
              )
            else if (model.items.isEmpty)
              const Text(
                'No approved reference images available. Images are published only after source and display-rights review.',
              )
            else
              for (final media in model.items)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (media.synthetic)
                          const Text(
                            'SYNTHETIC TEST FIXTURE · not disease evidence',
                          ),
                        if (media.path != null)
                          PrivateImage(
                            path: media.path!,
                            semanticLabel: media.altText,
                            height: 240,
                          ),
                        Text(media.altText),
                        SelectableText(
                          '${media.attribution}\nCredit: ${media.credit}\nLicense: ${media.license}',
                        ),
                        SourceReferenceCard(reference: media.source),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
