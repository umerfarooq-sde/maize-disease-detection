import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_states.dart';
import '../../../data/models/knowledge.dart';
import '../view_models/knowledge_detail_view_model.dart';
import '../widgets/knowledge_section_card.dart';
import '../widgets/reference_gallery.dart';
import '../utils/knowledge_presentation.dart';
import '../../../core/widgets/source_reference_card.dart';

class KnowledgeDetailView extends StatefulWidget {
  const KnowledgeDetailView({super.key});
  @override
  State<KnowledgeDetailView> createState() => _KnowledgeDetailViewState();
}

class _KnowledgeDetailViewState extends State<KnowledgeDetailView> {
  final Map<String, GlobalKey> _anchors = {};
  String? _selected;

  void _jump(String id) {
    final target = _anchors[id]?.currentContext;
    if (target == null) return;
    setState(() => _selected = id);
    Scrollable.ensureVisible(
      target,
      duration: AppMotion.resolve(context, AppMotion.navigation),
      alignment: 0.02,
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<KnowledgeDetailViewModel>();
    final ids =
        model.detail?.sections.map((section) => section.documentId).toSet() ??
        <String>{};
    _anchors.removeWhere((id, _) => !ids.contains(id));
    if (!ids.contains(_selected)) {
      _selected = null;
    }
    return AppPage(
      maxWidth: AppSizing.readingMaxWidth,
      storageKey: 'knowledge-detail-${model.slug}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (model.loading)
            const AppLoadingState(message: 'Loading reviewed information…')
          else if (model.error case final error?)
            error.kind == AppErrorKind.notFound ||
                    error.kind == AppErrorKind.validation
                ? const AppEmptyState(
                    title: 'Entry unavailable',
                    message:
                        'This entry may have been archived. Return to the catalogue for published knowledge.',
                  )
                : AppErrorState(error: error, onRetry: model.load)
          else if (model.detail case final detail?) ...[
            _KnowledgeHeader(detail: detail),
            if (detail.sections.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Semantics(
                header: true,
                child: Text(
                  'On this page',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final section in detail.sections)
                    InputChip(
                      key: ValueKey('section-link-${section.documentId}'),
                      label: Text(knowledgeTypeLabel(section.knowledgeType)),
                      tooltip: 'Read ${section.title}',
                      selected: _selected == section.documentId,
                      onPressed: () => _jump(section.documentId),
                    ),
                ],
              ),
            ],
            if (detail.growthStages.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              _ApplicabilitySection(
                title: 'Reviewed growth-stage applicability',
                icon: Icons.grass_outlined,
                items: detail.growthStages,
              ),
            ],
            if (detail.severityDescriptors.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              _ApplicabilitySection(
                title: 'Reviewed severity descriptions',
                icon: Icons.assessment_outlined,
                items: detail.severityDescriptors,
              ),
            ],
            if (detail.metadataSource case final source?) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Catalogue attribution',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              SourceReferenceCard(reference: source),
            ],
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: context.semanticColors.infoContainer,
                borderRadius: BorderRadius.circular(AppRadii.medium),
              ),
              child: Text(
                'Reviewed source information—not a guaranteed diagnosis or locally tailored prescription. Consult an agricultural expert when uncertain.',
                style: TextStyle(color: context.semanticColors.onInfoContainer),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: model.load,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh details'),
              ),
            ),
            if (detail.sections.isEmpty)
              const AppEmptyState(
                title: 'No reviewed sections published',
                message:
                    'Source-backed information will appear when available.',
              ),
            if (detail.sections.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Reviewed information',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            for (final section in detail.sections) ...[
              KnowledgeSectionCard(
                key: _anchors.putIfAbsent(section.documentId, GlobalKey.new),
                section: section,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            ReferenceGallery(
              key: ValueKey('gallery-${detail.disease.slug}'),
              slug: detail.disease.slug,
            ),
          ],
        ],
      ),
    );
  }
}

class _KnowledgeHeader extends StatelessWidget {
  const _KnowledgeHeader({required this.detail});

  final DiseaseDetail detail;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.hero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (detail.classifierSupported != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                detail.classifierSupported!
                    ? 'Classifier-supported context'
                    : 'Informational knowledge entry · not a trained classifier output',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onPrimaryContainer,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Text(
            detail.disease.name,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: colors.onPrimaryContainer,
            ),
          ),
          if (detail.disease.scientificName case final String name?) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              name,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colors.onPrimaryContainer,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (detail.disease.description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            SelectableText(
              detail.disease.description,
              style: TextStyle(color: colors.onPrimaryContainer),
            ),
          ],
        ],
      ),
    );
  }
}

class _ApplicabilitySection extends StatelessWidget {
  const _ApplicabilitySection({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<String> items;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          for (final item in items) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•'),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: SelectableText(item)),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}
