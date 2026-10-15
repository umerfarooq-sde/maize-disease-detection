import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_states.dart';
import '../view_models/knowledge_detail_view_model.dart';
import '../widgets/knowledge_section_card.dart';

class KnowledgeDetailView extends StatelessWidget {
  const KnowledgeDetailView({super.key});
  @override
  Widget build(BuildContext context) {
    final model = context.watch<KnowledgeDetailViewModel>();
    return AppPage(
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
            Text(
              detail.disease.name,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (detail.disease.scientificName case final name?) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(name),
            ],
            if (detail.disease.description.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              SelectableText(detail.disease.description),
            ],
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Reviewed source information, not a guaranteed diagnosis or locally tailored prescription. Consult an agricultural expert when uncertain.',
            ),
            const SizedBox(height: AppSpacing.md),
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
            for (final section in detail.sections) ...[
              KnowledgeSectionCard(section: section),
              const SizedBox(height: AppSpacing.lg),
            ],
          ],
        ],
      ),
    );
  }
}
