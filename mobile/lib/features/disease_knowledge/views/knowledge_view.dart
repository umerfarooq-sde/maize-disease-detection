import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_states.dart';
import '../view_models/knowledge_view_model.dart';
import '../../../core/widgets/feature_card.dart';
import '../widgets/knowledge_match_card.dart';

class KnowledgeView extends StatefulWidget {
  const KnowledgeView({super.key});
  @override
  State<KnowledgeView> createState() => _KnowledgeViewState();
}

class _KnowledgeViewState extends State<KnowledgeView> {
  final _query = TextEditingController();
  bool get _hasDraft => _query.text.isNotEmpty;

  void _clearSearch(KnowledgeViewModel model) {
    _query.clear();
    model.clearSearch();
    setState(() {});
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<KnowledgeViewModel>();
    return AppPage(
      storageKey: 'knowledge-library',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Maize knowledge',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Explore reviewed information and its original sources. This library does not diagnose your crop.',
          ),
          const SizedBox(height: AppSpacing.xl),
          TextField(
            key: const Key('knowledge-query'),
            controller: _query,
            enabled: !model.searching,
            decoration: InputDecoration(
              labelText: 'Search reviewed knowledge',
              hintText: 'For example: common rust symptoms',
              helperText: '3–1000 characters, up to 1800 UTF-8 bytes.',
              helperMaxLines: 3,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _hasDraft
                  ? IconButton(
                      key: const Key('knowledge-clear-input'),
                      tooltip: 'Clear search',
                      onPressed: () => _clearSearch(model),
                      icon: const Icon(Icons.clear),
                    )
                  : null,
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (value) => model.search(value),
            onChanged: (_) {
              model.editSearch();
              setState(() {});
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton.icon(
                key: const Key('knowledge-search'),
                onPressed: model.searching
                    ? null
                    : () => model.search(_query.text),
                icon: const Icon(Icons.search),
                label: const Text('Search knowledge'),
              ),
              if (model.query != null ||
                  model.searchError != null ||
                  model.searching)
                TextButton(
                  onPressed: () => _clearSearch(model),
                  child: const Text('Clear search'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          if (model.searching)
            const AppLoadingState(message: 'Searching reviewed passages…'),
          if (model.searchError case final error?)
            error.kind == AppErrorKind.validation
                ? Text(
                    'Enter 3–1000 readable characters within 1800 UTF-8 bytes.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  )
                : AppErrorState(
                    error: error,
                    onRetry: () => model.search(_query.text),
                  ),
          if (model.result case final result?) ...[
            Text(
              'Retrieved passages',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              result.matches.isEmpty
                  ? 'No reviewed passages matched “${model.query}”.'
                  : '${result.matches.length} reviewed ${result.matches.length == 1 ? 'passage' : 'passages'} for “${model.query}”. Ranked for relevance; not a generated answer or diagnosis.',
            ),
            const SizedBox(height: AppSpacing.lg),
            if (result.matches.isEmpty)
              const AppEmptyState(
                title: 'No matching passages',
                message:
                    'Try another maize topic or browse the catalogue below.',
              ),
            for (final match in result.matches) ...[
              KnowledgeMatchCard(
                match: match,
                onOpen: () =>
                    context.push('${AppRoutes.knowledge}/${match.diseaseSlug}'),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            const SizedBox(height: AppSpacing.xl),
          ],
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Disease & healthy-leaf catalogue',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextButton.icon(
                onPressed: model.loading ? null : model.load,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh catalogue'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (model.loading)
            const AppLoadingState(message: 'Loading the catalogue…')
          else if (model.catalogueError case final error?)
            AppErrorState(error: error, onRetry: model.load)
          else if (model.items.isEmpty)
            const AppEmptyState(
              title: 'No published entries yet',
              message: 'Refresh later for reviewed maize knowledge.',
            )
          else
            for (final disease in model.items) ...[
              FeatureCard(
                key: ValueKey('knowledge-${disease.slug}'),
                title: disease.name,
                description: disease.description,
                descriptionMaxLines: 4,
                icon: disease.slug == 'healthy'
                    ? Icons.spa_outlined
                    : Icons.menu_book_outlined,
                onTap: () =>
                    context.push('${AppRoutes.knowledge}/${disease.slug}'),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
        ],
      ),
    );
  }
}
