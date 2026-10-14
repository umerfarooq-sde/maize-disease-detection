import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_states.dart';
import '../../disease_detection/utils/scan_presentation.dart';
import '../view_models/assistant_view_model.dart';
import 'assistant_answer_card.dart';

class AssistantTurnCard extends StatelessWidget {
  const AssistantTurnCard({
    required this.turn,
    required this.loading,
    required this.onRetry,
    super.key,
  });
  final AssistantTurn turn;
  final bool loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Card(
        color: AppColors.mist,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('You asked', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(turn.question),
              if (turn.scan case final scan?) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('Scan from ${scanDate(scan.createdAt)}'),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      if (loading)
        const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: AppLoadingState(message: 'Checking reviewed knowledge…'),
        ),
      if (turn.answer case final answer?) AssistantAnswerCard(answer: answer),
      if (turn.error case final error?)
        Card(
          color: AppColors.errorSurface,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'The answer could not be completed',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(error.message),
                if (onRetry != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    key: const Key('assistant-retry'),
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ],
            ),
          ),
        ),
    ],
  );
}
