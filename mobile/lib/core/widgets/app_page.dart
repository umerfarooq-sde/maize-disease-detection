import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../utils/responsive.dart';

/// Safe, scrollable, width-aware page surface for compact phones, split-screen
/// layouts, desktop windows and the content pane alongside a navigation rail.
class AppPage extends StatelessWidget {
  const AppPage({required this.child, this.storageKey, super.key});
  final Widget child;
  final String? storageKey;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final padding = Responsive.paddingForWidth(constraints.maxWidth);
        return SingleChildScrollView(
          key: storageKey == null ? null : PageStorageKey(storageKey),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.all(padding),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizing.contentMaxWidth,
              ),
              child: SizedBox(width: double.infinity, child: child),
            ),
          ),
        );
      },
    ),
  );
}
