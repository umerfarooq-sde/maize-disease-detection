import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';

class FertilizerSource extends StatelessWidget {
  const FertilizerSource({
    required this.title,
    required this.publisher,
    required this.url,
    required this.citation,
    super.key,
  });

  final String title;
  final String publisher;
  final String url;
  final String citation;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Rule source', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppSpacing.sm),
      Text(title),
      Text(publisher, style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: AppSpacing.sm),
      SelectableText(citation),
      const SizedBox(height: AppSpacing.sm),
      SelectableText(url),
    ],
  );
}
