import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../auth/view_models/farmer_session_view_model.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/feature_card.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});
  @override
  Widget build(BuildContext context) {
    final session = context.watch<FarmerSessionViewModel>();
    return AppPage(
      storageKey: 'profile',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your field, your space',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            session.signedIn
                ? 'Signed in as ${session.account!.email}'
                : 'You are exploring as a guest.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (session.error != null && !session.signedIn) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                session.error!.kind == AppErrorKind.network ||
                        session.error!.kind == AppErrorKind.timeout ||
                        session.error!.kind == AppErrorKind.server
                    ? 'Signed out on this device. We could not contact the server to revoke the session. Please reconnect and sign in again.'
                    : 'Your session ended. Please sign in again.',
                style: const TextStyle(color: AppColors.error),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: AppSizing.emblem,
                    color: AppColors.blue,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    session.signedIn
                        ? 'Your scans are saved to your account'
                        : 'Make room for your progress',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    session.signedIn
                        ? 'Open your scan history to review previous model predictions.'
                        : 'Sign in with your farmer account to save new scans. Guest scans remain anonymous.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  OutlinedButton(
                    onPressed: session.busy
                        ? null
                        : () async {
                            if (session.signedIn) {
                              await session.signOut();
                            } else if (context.mounted) {
                              context.push(AppRoutes.auth);
                            }
                          },
                    child: Text(
                      session.busy
                          ? 'Please wait…'
                          : session.signedIn
                          ? 'Sign out'
                          : 'Sign in',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          FeatureCard(
            title: 'Scan history',
            description: 'Review your saved leaf images and model predictions.',
            icon: Icons.history,
            onTap: () => context.push(AppRoutes.history),
          ),
          const SizedBox(height: AppSpacing.lg),
          FeatureCard(
            title: 'Field insights',
            description: 'A future view of your crop activity.',
            icon: Icons.insights_outlined,
            tone: AppColors.amber,
            tint: AppColors.wheat,
            onTap: () => context.push(AppRoutes.analytics),
          ),
        ],
      ),
    );
  }
}
