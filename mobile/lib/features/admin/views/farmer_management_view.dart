import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_states.dart';
import '../../../data/models/admin_accounts.dart';
import '../view_models/farmer_management_view_model.dart';

class FarmerManagementView extends StatefulWidget {
  const FarmerManagementView({super.key});
  @override
  State<FarmerManagementView> createState() => _FarmerManagementViewState();
}

class _FarmerManagementViewState extends State<FarmerManagementView> {
  final _email = TextEditingController();
  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _status(
    FarmerManagementViewModel model,
    ManagedFarmer farmer,
    String status,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change farmer status to $status?'),
        content: Text(
          'Account: ${farmer.email}\nAll existing sessions will be revoked. ${status == 'ACTIVE' ? 'The farmer must sign in again.' : 'Sign-in and authenticated access will be blocked.'} Records and scan ownership will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm status change'),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) await model.changeStatus(farmer, status);
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<FarmerManagementViewModel>();
    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Farmer accounts',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Review registered farmer accounts and manage access. Roles, passwords and private field details are not editable here. Deactivation preserves account records.',
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            key: const Key('farmer-account-email'),
            controller: _email,
            enabled: !model.busy,
            decoration: const InputDecoration(
              labelText: 'Exact email (optional)',
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              ChoiceChip(
                label: const Text('All statuses'),
                selected: model.status == null,
                onSelected: model.busy
                    ? null
                    : (_) => model.filter(null, _email.text),
              ),
              for (final status in farmerAccountStatuses)
                ChoiceChip(
                  label: Text(status),
                  selected: model.status == status,
                  onSelected: model.busy
                      ? null
                      : (_) => model.filter(status, _email.text),
                ),
              OutlinedButton(
                onPressed: model.busy
                    ? null
                    : () => model.filter(model.status, _email.text),
                child: const Text('Apply / refresh accounts'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          if (model.message case final message?) ...[
            Semantics(liveRegion: true, child: Text(message)),
            const SizedBox(height: AppSpacing.md),
          ],
          if (model.error case final error?) ...[
            AppErrorState(error: error, onRetry: model.load),
            if (error.kind.name == 'conflict')
              const Text(
                'Refresh and review the current account status before retrying.',
              ),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (model.busy)
            const AppLoadingState(message: 'Updating farmer accounts…'),
          if (!model.busy && model.error == null && model.items.isEmpty)
            const AppEmptyState(
              title: 'No farmer accounts match',
              message:
                  'Change the status or exact-email filter, or refresh after registration.',
            ),
          for (final farmer in model.items) ...[
            Card(
              key: ValueKey('managed-farmer-${farmer.id}'),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      farmer.displayName ?? farmer.email,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SelectableText(farmer.email),
                    Text('Status: ${farmer.status}'),
                    Text(
                      'Registered ${farmer.createdAt.toUtc().toIso8601String()}',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final status in farmerAccountStatuses)
                          if (status != farmer.status)
                            OutlinedButton(
                              onPressed: model.busy
                                  ? null
                                  : () => _status(model, farmer, status),
                              child: Text('Set $status'),
                            ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (model.nextCursor != null)
            OutlinedButton(
              onPressed: model.busy ? null : () => model.load(more: true),
              child: const Text('Load more accounts'),
            ),
        ],
      ),
    );
  }
}
