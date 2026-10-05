import 'package:flutter/material.dart';
import '../../../core/widgets/feature_intro.dart';

class AssistantView extends StatelessWidget {
  const AssistantView({super.key});
  @override
  Widget build(BuildContext context) => const FeatureIntro(
    title: 'Your field assistant',
    subtitle: 'Knowledge first. Clear explanations.',
    icon: Icons.chat_bubble_outline,
    message:
        'The assistant is not connected yet. Answers will rely on reviewed agricultural knowledge when this service is available.',
  );
}
