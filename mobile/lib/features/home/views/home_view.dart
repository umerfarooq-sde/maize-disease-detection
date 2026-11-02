import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_page.dart';
import '../../../data/models/scan_record.dart';
import '../../auth/view_models/farmer_session_view_model.dart';
import '../view_models/home_view_model.dart';
import '../widgets/home_scan_hero.dart';
import '../widgets/home_quick_actions.dart';
import '../widgets/home_recent_scans.dart';
import 'connection_card.dart';

class HomeView extends StatelessWidget {
  const HomeView({this.onOpenScan, super.key});
  final ValueChanged<ScanRecord>? onOpenScan;

  @override
  Widget build(BuildContext context) {
    final signedIn =
        context.watch<FarmerSessionViewModel?>()?.signedIn ?? false;
    final text = Theme.of(context).textTheme;
    return AppPage(
      storageKey: 'home',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              signedIn ? 'Welcome back' : 'Your field companion',
              style: text.headlineSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'One leaf. A clearer next step.',
            style: text.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              if (Responsive.preferStacked(context, constraints.maxWidth)) {
                return const Column(
                  children: [
                    HomeScanHero(),
                    SizedBox(height: AppSpacing.xl),
                    HomeQuickActions(),
                  ],
                );
              }
              return const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: HomeScanHero()),
                  SizedBox(width: AppSpacing.xl),
                  Expanded(flex: 2, child: HomeQuickActions(vertical: true)),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          HomeRecentScans(signedIn: signedIn, onOpenScan: onOpenScan),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            key: const Key('home-scan-history'),
            onPressed: () => context.push(AppRoutes.history),
            icon: const Icon(Icons.history),
            label: const Text('Scan History'),
          ),
          const SizedBox(height: AppSpacing.xl),
          Consumer<HomeViewModel>(
            builder: (context, model, _) => ConnectionCard(model: model),
          ),
        ],
      ),
    );
  }
}
