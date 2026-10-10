import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_states.dart';
import '../../../data/models/scan_record.dart';
import '../view_models/scan_history_view_model.dart';
import '../widgets/history_scan_tile.dart';

class HistoryView extends StatelessWidget {
  const HistoryView({this.onOpenScan, this.onSignIn, super.key});
  final ValueChanged<ScanRecord>? onOpenScan;
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    final model = context.watch<ScanHistoryViewModel>();
    if (!model.hasAuthenticatedSession) {
      return AppPage(
        child: AppEmptyState(
          title: 'Sign in to see your scans',
          icon: Icons.lock_outline,
          message:
              'Saved scans are private to your account. You can still scan as a guest without a personal history.',
          action: FilledButton.icon(
            key: const Key('history-sign-in'),
            onPressed: onSignIn ?? () => context.push(AppRoutes.auth),
            icon: const Icon(Icons.person_outline),
            label: const Text('Sign in'),
          ),
        ),
      );
    }
    final items = model.items;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: model.refresh,
        child: CustomScrollView(
          key: const PageStorageKey('scan-history'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.all(Responsive.pagePadding(context)),
              sliver: SliverMainAxisGroup(
                slivers: [
                  SliverToBoxAdapter(
                    child: _content(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Your saved scans',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Refresh scan history',
                                onPressed: model.isLoading
                                    ? null
                                    : model.refresh,
                                icon: const Icon(Icons.refresh),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          const Text(
                            'Private to your signed-in farmer account.',
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          if (model.isLoading)
                            const AppLoadingState(
                              message: 'Loading your scans…',
                            ),
                          if (model.error case final error?) ...[
                            AppErrorState(error: error, onRetry: model.refresh),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          if (!model.isLoading &&
                              model.error == null &&
                              items.isEmpty)
                            AppEmptyState(
                              title: 'Your scan history starts here',
                              message:
                                  'Your saved leaf scans will appear here.',
                              icon: Icons.history,
                              action: FilledButton.icon(
                                onPressed: () => context.go(AppRoutes.scan),
                                icon: const Icon(
                                  Icons.document_scanner_outlined,
                                ),
                                label: const Text('Scan a leaf'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SliverList.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) => _content(
                      HistoryScanTile(
                        key: ValueKey(items[index].id),
                        scan: items[index],
                        onOpen: onOpenScan == null
                            ? null
                            : () => onOpenScan!(items[index]),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _content(
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (model.loadMoreError case final error?)
                              AppErrorState(
                                error: error,
                                onRetry: model.loadMore,
                              ),
                            if (model.isLoadingMore)
                              const AppLoadingState(
                                message: 'Loading more scans…',
                              ),
                            if (model.hasMore &&
                                !model.isLoadingMore &&
                                model.loadMoreError == null)
                              OutlinedButton.icon(
                                key: const Key('history-load-more'),
                                onPressed: model.isLoading
                                    ? null
                                    : model.loadMore,
                                icon: const Icon(Icons.expand_more),
                                label: const Text('Load more scans'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(Widget child) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppSizing.contentMaxWidth),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}
