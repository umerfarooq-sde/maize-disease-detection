import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_states.dart';

class AssistantEmptyState extends StatelessWidget {
  const AssistantEmptyState({required this.onAsk, super.key});
  final ValueChanged<String>? onAsk;

  static const _questions = [
    'What are common rust symptoms in maize?',
    'How can gray leaf spot in maize be managed?',
    'How can northern corn leaf blight in maize be prevented?',
  ];

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppEmptyState(
            title: 'Knowledge for your next field decision',
            message:
                'Start with one maize condition and one topic, such as symptoms, management or prevention. When evidence is missing, the assistant will say so.',
            icon: Icons.chat_bubble_outline,
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final question in _questions) ...[
            OutlinedButton(
              onPressed: onAsk == null ? null : () => onAsk!(question),
              child: Text(question, textAlign: TextAlign.center),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    ),
  );
}
