import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_page.dart';
import '../../../data/models/scan_record.dart';
import '../view_models/assistant_view_model.dart';
import '../widgets/assistant_composer.dart';
import '../widgets/assistant_empty_state.dart';
import '../widgets/assistant_scan_context.dart';
import '../widgets/assistant_turn_card.dart';

class AssistantView extends StatefulWidget {
  const AssistantView({this.onChooseScan, super.key});
  final VoidCallback? onChooseScan;

  @override
  State<AssistantView> createState() => _AssistantViewState();
}

class _AssistantViewState extends State<AssistantView> {
  final _draft = TextEditingController();
  final _latestTurn = GlobalKey();

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<void> _ask(AssistantViewModel model, String question) async {
    final operation = model.ask(question);
    if (model.inputError == null) {
      _draft.clear();
      _showLatestTurn();
    }
    await operation;
  }

  Future<void> _explain(AssistantViewModel model, ScanRecord scan) async {
    final operation = model.explainScan(scan);
    if (model.inputError == null) _showLatestTurn();
    await operation;
  }

  void _showLatestTurn() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_latestTurn.currentContext case final context?) {
        Scrollable.ensureVisible(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<AssistantViewModel>();
    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your field assistant',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Ask about maize leaf conditions using reviewed knowledge. Model predictions are not confirmed diagnoses.',
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            model.hasAuthenticatedSession
                ? 'This conversation stays in this screen. It is not saved to your account and clears when you close this screen, sign out or change accounts.'
                : 'You can ask questions as a guest. This conversation stays in this screen and clears when you close this screen or sign in. Sign in to choose a saved scan.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (model.hasAuthenticatedSession && widget.onChooseScan != null)
                OutlinedButton.icon(
                  key: const Key('assistant-choose-scan'),
                  onPressed: model.busy ? null : widget.onChooseScan,
                  icon: const Icon(Icons.history),
                  label: const Text('Choose my scan'),
                ),
              if (model.turns.isNotEmpty)
                TextButton.icon(
                  key: const Key('assistant-clear'),
                  onPressed: () {
                    _draft.clear();
                    model.clear();
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear conversation'),
                ),
            ],
          ),
          if (model.selectedScan case final scan?) ...[
            const SizedBox(height: AppSpacing.lg),
            AssistantScanContext(
              scan: scan,
              busy: model.busy,
              onExplain: () => _explain(model, scan),
              onClear: model.clearScan,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          if (model.turns.isEmpty)
            AssistantEmptyState(
              onAsk: model.busy ? null : (question) => _ask(model, question),
            ),
          for (var index = 0; index < model.turns.length; index++) ...[
            if (index == model.turns.length - 1)
              SizedBox(key: _latestTurn, height: 0),
            AssistantTurnCard(
              key: ValueKey(model.turns[index].id),
              turn: model.turns[index],
              loading: model.busy && index == model.turns.length - 1,
              onRetry: !model.busy && index == model.turns.length - 1
                  ? model.retry
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          const SizedBox(height: AppSpacing.lg),
          AssistantComposer(
            controller: _draft,
            busy: model.busy,
            inputError: model.inputError,
            diseaseLabel: model.diseaseLabel,
            knowledgeType: model.knowledgeType,
            onSelectDisease: model.selectDisease,
            onSelectTopic: model.selectTopic,
            onSubmit: () => _ask(model, _draft.text),
          ),
        ],
      ),
    );
  }
}
