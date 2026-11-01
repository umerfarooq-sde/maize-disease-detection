import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Wrapping, persistent label for long field names and large system text.
/// The supplied Material field still owns validation, focus and callbacks.
/// Omit its decoration.labelText to avoid a second single-line floating label.
class AppField extends StatelessWidget {
  const AppField({
    required this.label,
    required this.child,
    this.optional = false,
    super.key,
  });
  final String label;
  final Widget child;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final caption = '$label (${optional ? 'optional' : 'required'})';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Text(caption, style: Theme.of(context).textTheme.bodyMedium),
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(label: caption, child: child),
      ],
    );
  }
}
