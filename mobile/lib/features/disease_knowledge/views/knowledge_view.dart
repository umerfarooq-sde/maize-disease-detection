import 'package:flutter/material.dart';
import '../../../core/widgets/feature_intro.dart';

class KnowledgeView extends StatelessWidget {
  const KnowledgeView({super.key});
  @override
  Widget build(BuildContext context) => const FeatureIntro(
    title: 'Maize knowledge',
    subtitle: 'Clear information. Trusted sources.',
    icon: Icons.menu_book_outlined,
    message:
        'The disease library is being prepared. Reviewed symptoms, prevention and care information will appear here when available.',
  );
}
