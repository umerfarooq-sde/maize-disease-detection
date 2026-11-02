import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_cards.dart';

/// Intrinsic-height rows keep long numbers/labels readable at large text sizes.
class AdminMetricGrid extends StatelessWidget {
  const AdminMetricGrid({
    required this.children,
    this.minimumColumnWidth = AppSizing.emblem * 2,
    super.key,
  });
  final List<Widget> children;
  final double minimumColumnWidth;
  @override
  Widget build(BuildContext context) =>
      AppMetricGrid(minimumColumnWidth: minimumColumnWidth, children: children);
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
