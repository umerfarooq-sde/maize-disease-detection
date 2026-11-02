import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_states.dart';
import '../../../data/models/scan_record.dart';
import '../../scan_history/widgets/history_scan_tile.dart';
import '../view_models/home_view_model.dart';

class HomeRecentScans extends StatefulWidget {
  const HomeRecentScans({required this.signedIn, this.onOpenScan, super.key});
  final bool signedIn;
  final ValueChanged<ScanRecord>? onOpenScan;
  @override
  State<HomeRecentScans> createState() => _HomeRecentScansState();
}

class _HomeRecentScansState extends State<HomeRecentScans> {
  bool? _active;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.valuesOf(context).enabled;
    final returning = _active == false && active;
    _active = active;
    // The indexed shell retains this page. Refresh only on a genuine return,
    // not on rebuilds, progress ticks, theme changes or tab reselection.
    if (returning) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _active == true) {
          context.read<HomeViewModel>().loadRecentScans();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<HomeViewModel>();
    final text = Theme.of(context).textTheme;
    if (!widget.signedIn || !model.hasHistoryAccess) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Make room for your progress',
                  style: text.titleLarge,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Sign in to keep future scans in your private history. Guest scans stay anonymous.',
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton.icon(
                key: const Key('home-history-sign-in'),
                onPressed: () => context.push(AppRoutes.auth),
                icon: const Icon(Icons.person_outline),
                label: const Text('Sign in or create an account'),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text('Recent scans', style: text.titleLarge),
              ),
            ),
            IconButton(
              tooltip: 'Refresh recent scans',
              onPressed: model.recentLoading ? null : model.loadRecentScans,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        Text(
          'Private to this account · model outputs, not diagnoses',
          style: text.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        if (model.recentLoading)
          const AppLoadingState(message: 'Loading recent scans…', inline: true)
        else if (model.recentError case final error?)
          AppErrorState(error: error, onRetry: model.loadRecentScans)
        else if (model.recentScans.isEmpty)
          const AppEmptyState(
            title: 'Your first scan starts here',
            message:
                'Your saved leaf scans will appear here after you use the scanner.',
            icon: Icons.history,
          )
        else ...[
          for (final scan in model.recentScans) ...[
            HistoryScanTile(
              key: ValueKey('recent-${scan.id}'),
              scan: scan,
              compact: true,
              onOpen: widget.onOpenScan == null
                  ? null
                  : () => widget.onOpenScan!(scan),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          TextButton(
            key: const Key('home-view-all-scans'),
            onPressed: () => context.push(AppRoutes.history),
            child: const Text('View all scans'),
          ),
        ],
      ],
    );
  }
}
