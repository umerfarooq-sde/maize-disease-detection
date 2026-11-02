import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_cards.dart';

/// Intrinsic-height rows keep long numbers/labels readable at large text sizes.
class AdminMetricGrid extends StatelessWidget {
  const AdminMetricGrid({required this.children, super.key});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final minimum = AppSizing.emblem * 2 * scale;
      final columns =
          ((constraints.maxWidth + AppSpacing.md) / (minimum + AppSpacing.md))
              .floor()
              .clamp(1, 4);
      return Column(
        children: [
          for (var start = 0; start < children.length; start += columns) ...[
            if (start != 0) const SizedBox(height: AppSpacing.md),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var column = 0; column < columns; column++) ...[
                    if (column != 0) const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: start + column < children.length
                          ? children[start + column]
                          : const SizedBox(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}

class AdminMetricCard extends StatelessWidget {
  const AdminMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.note,
    super.key,
  });
  final String label;
  final String? value, note;
  final IconData icon;
  @override
  Widget build(BuildContext context) =>
      AppMetricCard(label: label, value: value, note: note, icon: icon);
}
