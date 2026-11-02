import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/private_image.dart';
import '../../../core/widgets/source_reference_card.dart';
import '../../../data/models/reference_media.dart';
import 'admin_editor_section.dart';

class AdminReferenceCard extends StatelessWidget {
  const AdminReferenceCard({
    required this.media,
    required this.busy,
    required this.onEdit,
    required this.onStatus,
    super.key,
  });
  final ReferenceMedia media;
  final bool busy;
  final VoidCallback onEdit;
  final ValueChanged<String> onStatus;
  @override
  Widget build(BuildContext context) => Card(
    key: ValueKey('admin-media-${media.id}'),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide =
              constraints.maxWidth >=
              620 * MediaQuery.textScalerOf(context).scale(1);
          final preview = ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.medium),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: media.path == null
                  ? const Center(child: Text('Image unavailable'))
                  : PrivateImage(
                      path: media.path!,
                      semanticLabel: media.altText,
                      width: wide ? 220 : constraints.maxWidth,
                    ),
            ),
          );
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminContentStatus(media.status),
              const SizedBox(height: AppSpacing.sm),
              if (media.synthetic)
                const Text('SYNTHETIC TEST FIXTURE · not disease evidence'),
              Text(
                media.altText,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text('${media.slug} · display order ${media.order}'),
              SelectableText(
                'Credit: ${media.credit}\nAttribution: ${media.attribution}\nLicense: ${media.license}',
              ),
              Text(
                media.rightsConfirmed
                    ? 'Hosting rights confirmation recorded; review applicability before publication.'
                    : 'Hosting rights not confirmed. Review permission before publication.',
              ),
              ExpansionTile(
                key: PageStorageKey('admin-media-source-${media.id}'),
                expansionAnimationStyle: AnimationStyle(
                  duration: AppMotion.resolve(context, AppMotion.reveal),
                ),
                title: const Text('Source & rights'),
                children: [
                  KeyedSubtree(
                    key: PageStorageKey('admin-media-source-body-${media.id}'),
                    child: SourceReferenceCard(reference: media.source),
                  ),
                ],
              ),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  TextButton(
                    onPressed: busy ? null : onEdit,
                    child: const Text('Edit metadata / reorder / replace'),
                  ),
                  for (final status in ['ACTIVE', 'INACTIVE', 'DELETED'])
                    TextButton(
                      onPressed: busy ? null : () => onStatus(status),
                      child: Text(switch (status) {
                        'ACTIVE' => 'Publish',
                        'INACTIVE' => 'Hide',
                        _ => 'Retire and clean',
                      }),
                    ),
                ],
              ),
            ],
          );
          return wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 220, child: preview),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(child: details),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    preview,
                    const SizedBox(height: AppSpacing.md),
                    details,
                  ],
                );
        },
      ),
    ),
  );
}
