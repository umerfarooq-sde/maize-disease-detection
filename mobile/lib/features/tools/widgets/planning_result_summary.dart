import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';

/// Formats no arithmetic: every value is supplied by the typed server result.
class PlanningResultSummary extends StatefulWidget {
  const PlanningResultSummary({
    required this.title,
    required this.quantity,
    required this.area,
    required this.quantityKey,
    this.product,
    this.revealIdentity,
    super.key,
  });
  final String title, quantity, area;
  final String? product;
  final Key quantityKey;
  final Object? revealIdentity;
  @override
  State<PlanningResultSummary> createState() => _PlanningResultSummaryState();
}

class _PlanningResultSummaryState extends State<PlanningResultSummary> {
  final _quantityAnchor = GlobalKey();
  @override
  void initState() {
    super.initState();
    _reveal();
  }

  @override
  void didUpdateWidget(covariant PlanningResultSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.revealIdentity, widget.revealIdentity)) _reveal();
  }

  void _reveal() {
    if (widget.revealIdentity == null) return;
    final identity = widget.revealIdentity;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !identical(identity, widget.revealIdentity) ||
          !TickerMode.valuesOf(context).enabled) {
        return;
      }
      final target = _quantityAnchor.currentContext;
      if (target == null) return;
      FocusManager.instance.primaryFocus?.unfocus();
      Scrollable.ensureVisible(
        target,
        alignment: 0.45,
        duration: AppMotion.resolve(context, AppMotion.reveal),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title,
        quantity = widget.quantity,
        area = widget.area,
        product = widget.product;
    final quantityKey = widget.quantityKey;
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calculate_outlined,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (product != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(product),
            ],
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              key: _quantityAnchor,
              liveRegion: true,
              child: SelectableText(
                quantity,
                key: quantityKey,
                style: AppTypography.metric.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontFamily: AppTypography.family,
                  fontFamilyFallback: AppTypography.fallback,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(area),
          ],
        ),
      ),
    );
  }
}
