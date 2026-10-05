import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../utils/responsive.dart';

/// Common scrolling, safe-area and constrained content surface for all screens.
class AppPage extends StatelessWidget {
  const AppPage({required this.child, this.storageKey, super.key});
  final Widget child;
  final String? storageKey;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      key: storageKey == null ? null : PageStorageKey(storageKey),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSizing.contentMaxWidth,
          ),
          child: SizedBox(width: double.infinity, child: child),
        ),
      ),
    ),
  );
}
