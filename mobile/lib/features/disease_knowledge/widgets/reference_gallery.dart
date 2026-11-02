import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/private_image.dart';
import '../../../core/widgets/source_reference_card.dart';
import '../../../core/widgets/app_states.dart';
import '../../../data/repositories/reference_media_repository.dart';
import '../view_models/reference_gallery_view_model.dart';
import 'reference_image_viewer.dart';

class ReferenceGallery extends StatefulWidget {
  const ReferenceGallery({required this.slug, super.key});
  final String slug;
  @override
  State<ReferenceGallery> createState() => _ReferenceGalleryState();
}

class _ReferenceGalleryState extends State<ReferenceGallery> {
  static const _pageSize = 4;
  int _page = 0;
  final _heading = GlobalKey();
  String get slug => widget.slug;
  @override
  void didUpdateWidget(covariant ReferenceGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slug != slug) {
      _page = 0;
    }
  }

  void _changePage(int page) {
    setState(() => _page = page);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _heading.currentContext;
      if (mounted && target != null) {
        Scrollable.ensureVisible(
          target,
          duration: AppMotion.resolve(context, AppMotion.navigation),
          alignment: 0.02,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.read<ReferenceMediaRepository?>();
    if (repository == null) {
      return const AppEmptyState(
        title: 'Reference photographs',
        message:
            'No reviewed reference photographs are available for this disease yet.',
        icon: Icons.photo_library_outlined,
      );
    }
    return ChangeNotifierProvider(
      key: ValueKey('reference-gallery-$slug'),
      create: (_) => ReferenceGalleryViewModel(repository, slug)..load(),
      child: Consumer<ReferenceGalleryViewModel>(
        builder: (context, model, _) {
          final published = model.items
              .where(
                (media) => media.status == 'ACTIVE' && media.rightsConfirmed,
              )
              .toList(growable: false);
          final pages = (published.length + _pageSize - 1) ~/ _pageSize;
          final page = pages == 0 ? 0 : _page.clamp(0, pages - 1);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                key: _heading,
                header: true,
                child: Text(
                  'Reference images',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Published photographs with source and display-rights attribution. Tap an image to inspect it.',
              ),
              const SizedBox(height: AppSpacing.md),
              if (model.busy)
                const AppLoadingState(
                  message: 'Loading reference photographs…',
                  inline: true,
                )
              else if (model.error != null)
                AppErrorState(error: model.error!, onRetry: model.load)
              else if (published.isEmpty)
                const AppEmptyState(
                  title: 'No reviewed photographs yet',
                  message:
                      'No reviewed reference photographs are available for this disease yet. Images require source and display-rights review.',
                  icon: Icons.photo_library_outlined,
                )
              else
                for (final media
                    in published.skip(page * _pageSize).take(_pageSize))
                  Card(
                    key: ValueKey(media.id),
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
                            LayoutBuilder(
                              builder: (context, constraints) => Semantics(
                                button: true,
                                label:
                                    'Inspect reference image: ${media.altText}',
                                child: InkWell(
                                  key: ValueKey('reference-open-${media.id}'),
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.medium,
                                  ),
                                  onTap: () => showDialog<void>(
                                    context: context,
                                    useSafeArea: false,
                                    builder: (_) =>
                                        ReferenceImageViewer(media: media),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.medium,
                                    ),
                                    child: AspectRatio(
                                      aspectRatio: 4 / 3,
                                      child: PrivateImage(
                                        path: media.path!,
                                        semanticLabel: media.altText,
                                        width: constraints.maxWidth,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: AppSpacing.md),
                          Text(media.altText),
                          SelectableText(
                            '${media.attribution}\nCredit: ${media.credit}\nLicense: ${media.license}',
                          ),
                          SourceReferenceCard(reference: media.source),
                        ],
                      ),
                    ),
                  ),
              if (!model.busy && model.error == null && pages > 1) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Reference photographs · page ${page + 1} of $pages',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    OutlinedButton.icon(
                      onPressed: page > 0 ? () => _changePage(page - 1) : null,
                      icon: const Icon(Icons.chevron_left),
                      label: const Text('Previous photographs'),
                    ),
                    OutlinedButton.icon(
                      onPressed: page + 1 < pages
                          ? () => _changePage(page + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                      label: const Text('Next photographs'),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
