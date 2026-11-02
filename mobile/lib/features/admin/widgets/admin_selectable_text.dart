import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';

/// Copyable technical values retain a usable selection target on short lines.
class AdminSelectableText extends StatelessWidget {
  const AdminSelectableText(this.data, {this.style, super.key});
  final String data;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: AppSizing.touchTarget),
    child: SelectableText(data, style: style),
  );
}
