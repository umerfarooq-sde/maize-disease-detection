import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/private_image.dart';
import '../../../core/widgets/app_confirmation_dialog.dart';
import '../../../core/constants/app_constants.dart';
import '../view_models/profile_view_model.dart';

class ProfilePhotoEditor extends StatelessWidget {
  const ProfilePhotoEditor({super.key});
  Future<void> _remove(BuildContext context, ProfileViewModel model) async {
    final confirmed = await showAppConfirmation(
      context,
      title: 'Remove profile photo?',
      message: 'Your display name and field details will stay saved.',
      confirmLabel: 'Remove photo',
      destructive: true,
    );
    if (confirmed == true && context.mounted) await model.removePhoto();
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<ProfileViewModel>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Profile photo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Use a photo you own or have permission to upload. JPEG, PNG or WebP, up to 5 MB / 16 megapixels, at least 16 × 16 pixels. Camera and location metadata are removed from the stored copy.',
            ),
            const SizedBox(height: AppSpacing.lg),
            if (model.photo case final photo?)
              Image.memory(
                photo.bytes,
                key: const Key('profile-photo-preview'),
                height: AppSizing.emblem * 3,
                cacheWidth: AppConstants.previewPixels,
                fit: BoxFit.contain,
                semanticLabel: 'Selected profile photo',
                errorBuilder: (_, _, _) => const Text(
                  'Photo preview unavailable. Choose another image.',
                ),
              )
            else if (model.data?.avatarUrl case final url?)
              PrivateImage(
                path: url.toString(),
                height: AppSizing.emblem * 3,
                fit: BoxFit.contain,
                semanticLabel: 'Your saved profile photo',
              )
            else
              Icon(
                Icons.person_outline,
                size: AppSizing.emblem,
                color: context.semanticColors.info,
              ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                OutlinedButton.icon(
                  key: const Key('profile-choose-photo'),
                  onPressed: model.busy ? null : model.choosePhoto,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose profile photo'),
                ),
                if (model.photo != null) ...[
                  FilledButton(
                    onPressed: model.busy ? null : model.uploadPhoto,
                    child: const Text('Upload selected photo'),
                  ),
                  TextButton(
                    onPressed: model.busy ? null : model.clearPhoto,
                    child: const Text('Discard selection'),
                  ),
                ],
                if (model.data?.avatarUrl != null)
                  TextButton(
                    onPressed: model.busy
                        ? null
                        : () => _remove(context, model),
                    child: const Text('Remove saved photo'),
                  ),
              ],
            ),
            if (model.busy && model.photo != null) ...[
              const SizedBox(height: AppSpacing.md),
              LinearProgressIndicator(value: model.progress),
              const Text('Saving your photo…'),
            ],
          ],
        ),
      ),
    );
  }
}
