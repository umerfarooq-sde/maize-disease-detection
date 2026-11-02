import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';

class AssistantEmptyState extends StatelessWidget {
  const AssistantEmptyState({
    required this.onAsk,
    this.authenticated = false,
    this.compact = false,
    super.key,
  });
  final ValueChanged<String>? onAsk;
  final bool authenticated;
  final bool compact;

  static const _questions = [
    'What are common rust symptoms in maize?',
    'How can gray leaf spot in maize be managed?',
    'How can northern corn leaf blight in maize be prevented?',
    'What should I look for when scouting healthy maize leaves?',
  ];

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!compact) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                ),
                child: Icon(
                  Icons.auto_stories_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: AppSizing.stateIcon,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Semantics(
            header: true,
            child: Text(
              compact
                  ? 'Ask about maize'
                  : 'Knowledge for your next field decision',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            compact
                ? 'Ask one maize question. Answers cite reviewed knowledge and state when evidence is missing.'
                : 'Start with one maize condition and one topic. Answers use reviewed knowledge and will say when evidence is missing.',
          ),
          if (!authenticated) ...[
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'You can ask questions as a guest. Sign in to explain a saved scan.',
            ),
          ],
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
