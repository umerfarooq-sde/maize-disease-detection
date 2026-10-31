import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Breakpoints are evaluated against the space granted to a widget, not
/// necessarily the full window (e.g. beside a navigation rail).
abstract final class Responsive {
  static bool useRail(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppSizing.tabletBreakpoint;

  static double paddingForWidth(double availableWidth) {
    if (availableWidth < AppSizing.compactBreakpoint) return AppSpacing.md;
    if (availableWidth < AppSizing.twoColumnBreakpoint) return AppSpacing.lg;
    if (availableWidth < AppSizing.tabletBreakpoint) return AppSpacing.xl;
    return AppSpacing.xxl;
  }

  /// Retained for callers outside a LayoutBuilder; AppPage uses local width.
  static double pagePadding(BuildContext context) =>
      paddingForWidth(MediaQuery.sizeOf(context).width);

  static bool compactNavigation(BuildContext context) {
    // Five destinations share the available bottom-bar width. Reserve enough
    // horizontal space for the longest label at the current dynamic text size.
    final widthPerDestination = MediaQuery.sizeOf(context).width / 5;
    final labelScale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return widthPerDestination < 72 * labelScale;
  }

  static bool preferStacked(BuildContext context, double availableWidth) {
    final scaledBody = MediaQuery.textScalerOf(context).scale(16);
    return availableWidth < AppSizing.twoColumnBreakpoint ||
        scaledBody > 16 * AppSizing.comfortableTextScale;
  }
}

/// Always stacks when the allocated width or dynamic type makes two columns
/// inappropriate. This also works inside modal sheets and split-screen views.
class ResponsivePair extends StatelessWidget {
  const ResponsivePair({required this.first, required this.second, super.key});
  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (!Responsive.preferStacked(context, constraints.maxWidth)) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: AppSpacing.xl),
            Expanded(child: second),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          first,
          const SizedBox(height: AppSpacing.lg),
          second,
        ],
      );
    },
  );
}
