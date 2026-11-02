import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_states.dart';
import '../../../core/widgets/app_field.dart';
import '../../../core/widgets/app_confirmation_dialog.dart';
import '../../../data/models/admin_accounts.dart';
import '../view_models/farmer_management_view_model.dart';
import '../widgets/admin_record_page.dart';
import '../widgets/farmer_account_card.dart';

class FarmerManagementView extends StatefulWidget {
  const FarmerManagementView({super.key});
  @override
  State<FarmerManagementView> createState() => _FarmerManagementViewState();
}

class _FarmerManagementViewState extends State<FarmerManagementView> {
  final _email = TextEditingController();
  String? _selectedStatus;
  bool _confirming = false;
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
    if (model.busy || _confirming) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _confirming = true);
    try {
      final confirmed = await showAppConfirmation(
        context,
        title: 'Change farmer status to $status?',
        message:
            'Account: ${farmer.email}\nCurrent loaded status: ${farmer.status}\nRequested status: $status\nAll existing sessions will be revoked. ${status == 'ACTIVE' ? 'The farmer must sign in again.' : 'Sign-in and authenticated access will be blocked.'} Records and scan ownership will be preserved. This action is recorded for audit.',
        confirmLabel: 'Confirm status change',
        destructive: status != 'ACTIVE',
        useRootNavigator: false,
      );
      if (mounted && confirmed) await model.changeStatus(farmer, status);
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<FarmerManagementViewModel>();
    return AdminRecordPage(
      storageKey: 'admin-farmer-accounts',
      count: model.items.length,
      itemBuilder: (_, index) {
        final farmer = model.items[index];
        return FarmerAccountCard(
          key: ValueKey(farmer.id),
          farmer: farmer,
          busy: model.busy || _confirming || model.error != null,
          onStatus: (status) => _status(model, farmer, status),
        );
      },
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Farmer accounts',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Manage account access with recorded, confirmed status changes. Roles, passwords and private field details are not editable here.',
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: ExpansionTile(
              key: const PageStorageKey('farmer-filter-panel'),
              initiallyExpanded: true,
              title: const Text('Filter accounts'),
              subtitle: Text(
                'Applied: ${model.status ?? 'All statuses'} · ${model.email ?? 'Any email'}',
              ),
              expansionAnimationStyle: AnimationStyle(
                duration: AppMotion.resolve(context, AppMotion.reveal),
              ),
              children: [
                KeyedSubtree(
                  key: const PageStorageKey('farmer-filter-fields'),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppField(
                          label: 'Exact email',
                          optional: true,
                          child: TextField(
                            key: const Key('farmer-account-email'),
                            controller: _email,
                            enabled: !model.busy,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            decoration: const InputDecoration(
                              helperText:
                                  'Exact address only. This is not a name or partial-email search.',
                              helperMaxLines: 3,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            ChoiceChip(
                              label: const Text('All statuses'),
                              selected: _selectedStatus == null,
                              onSelected: model.busy
                                  ? null
                                  : (_) =>
                                        setState(() => _selectedStatus = null),
                            ),
                            for (final status in farmerAccountStatuses)
                              ChoiceChip(
                                label: Text(status),
                                selected: _selectedStatus == status,
                                onSelected: model.busy
                                    ? null
                                    : (_) => setState(
                                        () => _selectedStatus = status,
                                      ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            FilledButton.icon(
                              onPressed: model.busy
                                  ? null
                                  : () => model.filter(
                                      _selectedStatus,
                                      _email.text,
                                    ),
                              icon: const Icon(Icons.filter_alt_outlined),
                              label: const Text('Apply / refresh accounts'),
                            ),
                            OutlinedButton(
                              onPressed: model.busy
                                  ? null
                                  : () {
                                      _email.clear();
                                      setState(() => _selectedStatus = null);
                                      model.filter(null, '');
                                    },
                              child: const Text('Clear filters'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (model.message case final message?)
            Semantics(
              liveRegion: true,
              child: Text(
                message,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          if (model.error case final error?) ...[
            AppErrorState(error: error, onRetry: model.load),
            if (error.kind.name == 'conflict')
              const Text(
                'Refresh and review the current account status before retrying.',
              ),
            if (['network', 'timeout'].contains(error.kind.name))
              const Text(
                'If a status change was submitted, its outcome may be uncertain. Refresh the authoritative account record before repeating it.',
              ),
          ],
          if (model.busy)
            const AppLoadingState(
              message: 'Updating farmer accounts…',
              inline: true,
            ),
          if (!model.busy && model.error == null && model.items.isEmpty)
            const AppEmptyState(
              title: 'No farmer accounts match',
              message:
                  'Change the status or exact-email filter, or refresh after registration.',
            ),
          if (!model.busy && model.error == null && model.items.isNotEmpty)
            Text(
              '${model.items.length} loaded accounts · newest registrations first',
              style: Theme.of(context).textTheme.labelLarge,
            ),
        ],
      ),
      footer: model.nextCursor == null
          ? const SizedBox.shrink()
          : OutlinedButton(
              onPressed: model.busy ? null : () => model.load(more: true),
              child: const Text('Load more accounts'),
            ),
    );
  }
}
