import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/private_image.dart';
import '../../../data/models/farmer_profile.dart';

class ProfileAccountHeader extends StatelessWidget {
  const ProfileAccountHeader({
    required this.signedIn,
    this.email,
    this.profile,
    super.key,
  });
  final bool signedIn;
  final String? email;
  final FarmerProfile? profile;
  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.hero),
                child: SizedBox.square(
                  dimension: AppSizing.emblem,
                  child: profile?.avatarUrl == null
                      ? Icon(
                          signedIn
                              ? Icons.person_outline
                              : Icons.person_outline_rounded,
                          size: AppSizing.stateIcon,
                          semanticLabel: signedIn
                              ? 'Farmer account avatar'
                              : 'Guest account',
                        )
                      : PrivateImage(
                          path: profile!.avatarUrl.toString(),
                          width: AppSizing.emblem,
                          height: AppSizing.emblem,
                          semanticLabel: 'Your saved profile photo',
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      signedIn
                          ? profile?.displayName ?? 'Farmer account'
                          : 'Guest explorer',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      signedIn
                          ? 'Signed in as $email'
                          : 'You are exploring as a guest.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            signedIn
                ? 'Your scans are saved to your account'
                : 'Make room for your progress',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            signedIn
                ? 'Review saved model predictions in your private history.'
                : 'Sign in with your farmer account to save new scans. Guest scans remain anonymous.',
          ),
        ],
      ),
    ),
  );
}
