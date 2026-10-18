import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_states.dart';
import '../view_models/privacy_view_model.dart';

class PrivacyView extends StatelessWidget {
  const PrivacyView({super.key});
  @override
  Widget build(BuildContext context) {
    final model = context.watch<PrivacyViewModel>();
    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your account data',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'You can request deletion of your Farmer account, profile, saved scans and associated private images. A request does not immediately delete your data. An administrator must review it under an approved privacy policy. Audit and backup handling is governed separately by that policy.',
          ),
          const SizedBox(height: AppSpacing.lg),
          if (!model.signedIn)
            const AppEmptyState(
              title: 'Sign in with your Farmer account',
              message:
                  'Only the signed-in account can request its own data deletion.',
            )
          else if (model.busy)
            const AppLoadingState(message: 'Checking your deletion request…')
          else ...[
            if (model.error case final error?)
              AppErrorState(error: error, onRetry: model.load),
            if (model.request case final request?) ...[
              Semantics(liveRegion: true, child: Text(request.description)),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Requested ${MaterialLocalizations.of(context).formatFullDate(request.requestedAt.toLocal())}',
              ),
            ] else if (model.loaded)
              FilledButton.tonal(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialog) => AlertDialog(
                      title: const Text('Request account-data deletion?'),
                      content: const Text(
                        'This sends a review request for your account. No data is automatically erased now. After approval, account access will be suspended before erasure begins.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialog, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialog, true),
                          child: const Text('Send request'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    await model.submit();
                  }
                },
                child: const Text('Request data deletion'),
              ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: model.load,
              child: const Text('Refresh request status'),
            ),
          ],
        ],
      ),
    );
  }
}
