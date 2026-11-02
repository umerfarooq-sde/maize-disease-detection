import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';

/// Shared, always-visible sections keep validation errors reachable in long forms.
class AdminEditorSection extends StatelessWidget {
  const AdminEditorSection({
    required this.title,
    required this.description,
    required this.children,
    super.key,
  });
  final String title, description;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(description, style: Theme.of(context).textTheme.bodyMedium),
          for (final child in children) ...[
            const SizedBox(height: AppSpacing.lg),
            child,
          ],
        ],
      ),
    ),
  );
}

class AdminContentStatus extends StatelessWidget {
  const AdminContentStatus(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Text(
        'Status · $status',
        style: Theme.of(context).textTheme.labelLarge,
      ),
    ),
  );
}
