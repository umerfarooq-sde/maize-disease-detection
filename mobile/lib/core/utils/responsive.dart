import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

abstract final class Responsive {
  static bool useRail(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppSizing.tabletBreakpoint;
  static double pagePadding(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppSizing.twoColumnBreakpoint
      ? AppSpacing.xxl
      : AppSpacing.xl;
}

/// Uses actual available width and text scale, including inside a navigation rail.
class ResponsivePair extends StatelessWidget {
  const ResponsivePair({required this.first, required this.second, super.key});
  final Widget first;
  final Widget second;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final fontSize = Theme.of(context).textTheme.bodyLarge!.fontSize!;
      final comfortableText =
          MediaQuery.textScalerOf(context).scale(fontSize) <=
          fontSize * AppSizing.comfortableTextScale;
      if (constraints.maxWidth >= AppSizing.twoColumnBreakpoint &&
          comfortableText) {
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
