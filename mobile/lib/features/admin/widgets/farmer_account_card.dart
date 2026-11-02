import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/admin_accounts.dart';
import 'admin_record_presentation.dart';
import 'admin_selectable_text.dart';

class FarmerAccountCard extends StatelessWidget {
  const FarmerAccountCard({
    required this.farmer,
    required this.busy,
    required this.onStatus,
    super.key,
  });
  final ManagedFarmer farmer;
  final bool busy;
  final ValueChanged<String> onStatus;
  @override
  Widget build(BuildContext context) => Card(
    key: ValueKey('managed-farmer-${farmer.id}'),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            farmer.displayName ?? farmer.email,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          AdminSelectableText(farmer.email),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(switch (farmer.status) {
                'ACTIVE' => Icons.check_circle_outline,
                'SUSPENDED' => Icons.pause_circle_outline,
                _ => Icons.block,
              }),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Status: ${farmer.status}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Registered ${adminUtc(farmer.createdAt)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          ExpansionTile(
            key: PageStorageKey('farmer-details-${farmer.id}'),
            title: const Text('Account details'),
            expansionAnimationStyle: AnimationStyle(
              duration: AppMotion.resolve(context, AppMotion.reveal),
            ),
            children: [
              KeyedSubtree(
                key: PageStorageKey('farmer-details-body-${farmer.id}'),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AdminSelectableText(
                        'Account ID: ${farmer.id}\nRevision: ${farmer.revision}\nRegistered timestamp: ${farmer.createdAt.toUtc().toIso8601String()}',
                      ),
                      const Text(
                        'Details from the loaded account record. Passwords, roles and private field data cannot be edited here.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final status in farmerAccountStatuses)
                if (status != farmer.status)
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => onStatus(status),
                    icon: Icon(
                      status == 'ACTIVE'
                          ? Icons.check_circle_outline
                          : Icons.manage_accounts_outlined,
                    ),
                    label: Text('Set $status'),
                  ),
            ],
          ),
        ],
      ),
    ),
  );
}
