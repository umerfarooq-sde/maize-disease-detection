import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_states.dart';
import '../view_models/profile_view_model.dart';
import '../widgets/profile_editor_form.dart';
import '../widgets/profile_photo_editor.dart';

class ProfileEditorView extends StatelessWidget {
  const ProfileEditorView({super.key});
  @override
  Widget build(BuildContext context) {
    final model = context.watch<ProfileViewModel>();
    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your farmer profile',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Choose the name you use here. Region, country and field area are optional. These details are private to your signed-in profile.',
          ),
          const SizedBox(height: AppSpacing.xl),
          if (!model.signedIn)
            AppEmptyState(
              title: 'Sign in to edit your profile',
              message:
                  'Your saved profile will be available after you sign in again.',
              action: FilledButton(
                onPressed: () => context.push(AppRoutes.auth),
                child: const Text('Sign in'),
              ),
            )
          else if (model.loading)
            const AppLoadingState(message: 'Loading your saved profile…')
          else ...[
            if (model.errorMessage case final message?) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: model.busy ? null : model.load,
                child: const Text('Reload saved profile'),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (model.message case final message?) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  style: const TextStyle(color: AppColors.forest),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (model.loaded) ...[
              ProfileEditorForm(
                key: ValueKey(model.data?.revision ?? 'new-profile'),
                profile: model.data,
                busy: model.busy,
                onSave: model.save,
              ),
              const SizedBox(height: AppSpacing.xxl),
              if (model.data != null)
                const ProfilePhotoEditor()
              else
                const Text(
                  'Save your display name first to add a profile photo.',
                ),
            ],
          ],
        ],
      ),
    );
  }
}
