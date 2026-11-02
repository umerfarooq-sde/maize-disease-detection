import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../auth/view_models/farmer_session_view_model.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_states.dart';
import '../../../core/widgets/theme_mode_selector.dart';
import '../view_models/profile_view_model.dart';
import '../widgets/account_action.dart';
import '../widgets/profile_account_header.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});
  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  bool _requested = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Profile is a parent route of History/Edit. Do not fetch its private
    // projection while it is offstage underneath a directly opened child.
    if (!_requested && TickerMode.valuesOf(context).enabled) {
      _requested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final model = context.read<ProfileViewModel?>();
        if (model != null && model.signedIn && !model.loaded) model.load();
      });
    }
  }

  Future<void> _edit(
    BuildContext context,
    ProfileViewModel? profile,
    FarmerSessionViewModel session,
  ) async {
    final revision = session.revision;
    await context.push(AppRoutes.editProfile);
    if (context.mounted && session.revision == revision && session.signedIn) {
      await profile?.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<FarmerSessionViewModel>();
    final profile = context.watch<ProfileViewModel?>();
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.md),
      child: Semantics(
        header: true,
        child: Text(text, style: Theme.of(context).textTheme.titleLarge),
      ),
    );
    return AppPage(
      storageKey: 'profile',
      maxWidth: AppSizing.readingMaxWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Your field, your space',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ProfileAccountHeader(
            signedIn: session.signedIn,
            email: session.account?.email,
            profile: session.signedIn ? profile?.data : null,
          ),
          if (session.signedIn && profile != null) ...[
            if (profile.loading)
              const AppLoadingState(
                message: 'Loading your account details…',
                inline: true,
              ),
            if (profile.error case final error?)
              AppErrorState(error: error, onRetry: profile.load),
          ],
          if (session.error != null && !session.signedIn) ...[
            const SizedBox(height: AppSpacing.md),
            Semantics(
              liveRegion: true,
              child: Text(
                session.error!.kind == AppErrorKind.network ||
                        session.error!.kind == AppErrorKind.timeout ||
                        session.error!.kind == AppErrorKind.server
                    ? 'Signed out on this device. We could not contact the server to revoke the session. Please reconnect and sign in again.'
                    : 'Your session ended. Please sign in again.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
          if (!session.signedIn) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: session.busy
                  ? null
                  : () => context.push(AppRoutes.auth),
              child: const Text('Sign in'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: session.busy
                  ? null
                  : () => context.push(AppRoutes.register),
              child: const Text('Create farmer account'),
            ),
          ],
          heading('My account'),
          AccountAction(
            key: const Key('edit-farmer-profile'),
            title: 'Personalize your profile',
            description:
                'Your display name, optional field details and private photo.',
            icon: Icons.manage_accounts_outlined,
            onTap: () => _edit(context, profile, session),
          ),
          heading('My activity'),
          AccountAction(
            title: 'Scan history',
            description: 'Review saved images and model predictions.',
            icon: Icons.history,
            onTap: () => context.push(AppRoutes.history),
          ),
          const SizedBox(height: AppSpacing.sm),
          AccountAction(
            title: 'Field insights',
            description: 'Your scan activity and model label patterns.',
            icon: Icons.insights_outlined,
            onTap: () => context.push(AppRoutes.analytics),
          ),
          heading('Preferences'),
          const ThemeModeSelector(),
          heading('Account and privacy'),
          AccountAction(
            title: 'Your account data',
            description:
                'Review or submit a data-deletion request. This does not erase data immediately.',
            icon: Icons.privacy_tip_outlined,
            onTap: () => context.push(AppRoutes.dataDeletion),
          ),
          if (session.signedIn) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              key: const Key('profile-sign-out'),
              onPressed: session.busy ? null : session.signOut,
              icon: const Icon(Icons.logout),
              label: Text(session.busy ? 'Please wait…' : 'Sign out'),
            ),
          ],
          heading('Administration'),
          AccountAction(
            title: 'Administrator workspace',
            description:
                'Separate administrator sign-in and authorized access.',
            icon: Icons.admin_panel_settings_outlined,
            onTap: () => context.push(AppRoutes.admin),
          ),
        ],
      ),
    );
  }
}
