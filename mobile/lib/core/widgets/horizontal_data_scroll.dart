import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Explicitly scrollable data grid that keeps the first and final columns
/// reachable on narrow screens, split windows and larger text settings.
class HorizontalDataScroll extends StatefulWidget {
  const HorizontalDataScroll({required this.child, super.key});
  final Widget child;

  @override
  State<HorizontalDataScroll> createState() => _HorizontalDataScrollState();
}

class _HorizontalDataScrollState extends State<HorizontalDataScroll> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
    controller: _controller,
    thumbVisibility: true,
    scrollbarOrientation: ScrollbarOrientation.bottom,
    child: SingleChildScrollView(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: widget.child,
    ),
  );
}
