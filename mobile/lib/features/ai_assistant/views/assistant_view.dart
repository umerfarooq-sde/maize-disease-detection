import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_confirmation_dialog.dart';
import '../../../data/models/scan_record.dart';
import '../../auth/view_models/farmer_session_view_model.dart';
import '../view_models/assistant_view_model.dart';
import '../widgets/assistant_composer.dart';
import '../widgets/assistant_empty_state.dart';
import '../widgets/assistant_focus_panel.dart';
import '../widgets/assistant_scan_context.dart';
import '../widgets/assistant_turn_card.dart';

class AssistantView extends StatefulWidget {
  const AssistantView({
    this.onChooseScan,
    this.handoff,
    this.handoffIdentity,
    super.key,
  });
  final VoidCallback? onChooseScan;
  final ScanRecord? handoff;
  final Object? handoffIdentity;
  @override
  State<AssistantView> createState() => _AssistantViewState();
}

class _AssistantViewState extends State<AssistantView> {
  final _draft = TextEditingController();
  final _scroll = ScrollController();
  Object? _consumedHandoff;
  int? _lastTurnId;
  Object? _lastAnswer;
  bool _lastBusy = false;
  bool _nearBottom = true;
  bool _unseen = false;
  bool _scrollScheduled = false;
  bool _forceLatest = false;
  ModalRoute<void>? _focusRoute;
  NavigatorState? _focusNavigator;
  bool _focusOpen = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _scheduleHandoff();
  }

  @override
  void didUpdateWidget(covariant AssistantView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleHandoff();
  }

  void _scheduleHandoff() {
    final identity = widget.handoffIdentity;
    final scan = widget.handoff;
    if (identity == null ||
        scan == null ||
        identical(identity, _consumedHandoff)) {
      return;
    }
    _consumedHandoff = identity;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(identity, widget.handoffIdentity)) return;
      final model = context.read<AssistantViewModel>();
      model.clear();
      _draft.clear();
      model.explainScan(scan);
    });
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final near = _scroll.position.extentAfter < AppSpacing.section * 2;
    _nearBottom = near;
    if (near && _unseen && mounted) setState(() => _unseen = false);
  }

  void _scheduleLatest({bool force = false}) {
    _forceLatest = _forceLatest || force;
    if (_scrollScheduled) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (!mounted || !_scroll.hasClients) return;
      final shouldFollow = _forceLatest || _nearBottom;
      _forceLatest = false;
      if (!shouldFollow) {
        if (!_unseen) setState(() => _unseen = true);
        return;
      }
      final duration = AppMotion.resolve(context, AppMotion.navigation);
      if (duration == Duration.zero) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      } else {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: duration,
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _ask(AssistantViewModel model, String question) async {
    if (model.busy) return;
    final operation = model.ask(question);
    if (model.inputError == null) {
      _draft.clear();
    }
    _scheduleLatest(force: true);
    await operation;
  }

  Future<void> _clear(AssistantViewModel model) async {
    if (!await showAppConfirmation(
      context,
      title: 'Clear temporary conversation?',
      message:
          'Remove these local turns, your draft and selected scan. Nothing is saved to your account.',
      confirmLabel: 'Clear conversation',
    )) {
      return;
    }
    if (!mounted) return;
    _draft.clear();
    model.clear();
  }

  void _dismissFocus() {
    final route = _focusRoute;
    final navigator = _focusNavigator;
    if (route != null &&
        route.isActive &&
        navigator != null &&
        navigator.mounted) {
      navigator.removeRoute(route);
    }
  }

  Future<void> _focus(AssistantViewModel model) async {
    if (_focusOpen) return;
    _focusOpen = true;
    final revision = context.read<FarmerSessionViewModel?>()?.revision;
    FocusManager.instance.primaryFocus?.unfocus();
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: AppSizing.formMaxWidth),
      builder: (sheetContext) {
        _focusRoute = ModalRoute.of<void>(sheetContext);
        _focusNavigator = Navigator.of(sheetContext);
        final currentRevision = sheetContext
            .watch<FarmerSessionViewModel?>()
            ?.revision;
        if (!mounted || currentRevision != revision) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _dismissFocus());
          return const SizedBox.shrink();
        }
        return ChangeNotifierProvider.value(
          value: model,
          child: const AssistantFocusPanel(),
        );
      },
    );
    _focusOpen = false;
    _focusRoute = null;
    _focusNavigator = null;
  }

  @override
  void dispose() {
    // The root modal belongs to this identity-scoped view, not the whole app.
    WidgetsBinding.instance.addPostFrameCallback((_) => _dismissFocus());
    _draft.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<AssistantViewModel>();
    final turns = model.turns;
    final last = turns.isEmpty ? null : turns.last;
    if (last != null &&
        (last.id != _lastTurnId ||
            last.answer != _lastAnswer ||
            model.busy != _lastBusy)) {
      _scheduleLatest(force: last.id != _lastTurnId);
    }
    _lastTurnId = last?.id;
    _lastAnswer = last?.answer;
    _lastBusy = model.busy;
    final focusLabel = [
      if (model.diseaseLabel != null)
        AssistantFocusPanel.diseases[model.diseaseLabel]!,
      if (model.knowledgeType != null)
        AssistantFocusPanel.topics[model.knowledgeType]!,
    ].join(' · ');
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSizing.readingMaxWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              'AI Assistant',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                        ),
                        IconButton(
                          key: const Key('assistant-focus'),
                          tooltip: 'Question focus and privacy',
                          onPressed: () => _focus(model),
                          icon: const Icon(Icons.tune),
                        ),
                        if (turns.isNotEmpty)
                          IconButton(
                            key: const Key('assistant-clear'),
                            tooltip: 'Clear conversation',
                            onPressed: () => _clear(model),
                            icon: const Icon(Icons.delete_outline),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    children: [
                      SingleChildScrollView(
                        key: const PageStorageKey('assistant-conversation'),
                        controller: _scroll,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (focusLabel.isNotEmpty) ...[
                              Text(
                                'Question focus · $focusLabel',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            if (model.selectedScan case final scan?) ...[
                              AssistantScanContext(
                                scan: scan,
                                busy: model.busy,
                                onExplain: () => model.explainScan(scan),
                                onClear: model.clearScan,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                            ],
                            if (turns.isEmpty)
                              AssistantEmptyState(
                                compact: constraints.maxHeight < 480,
                                authenticated: model.hasAuthenticatedSession,
                                onAsk: model.busy
                                    ? null
                                    : (question) => _ask(model, question),
                              ),
                            if (model.hasAuthenticatedSession &&
                                widget.onChooseScan != null) ...[
                              Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton.icon(
                                  key: const Key('assistant-choose-scan'),
                                  onPressed: model.busy
                                      ? null
                                      : widget.onChooseScan,
                                  icon: const Icon(Icons.history),
                                  label: const Text('Choose my scan'),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                            ],
                            for (
                              var index = 0;
                              index < turns.length;
                              index++
                            ) ...[
                              AssistantTurnCard(
                                key: ValueKey(turns[index].id),
                                turn: turns[index],
                                loading:
                                    model.busy && index == turns.length - 1,
                                onRetry:
                                    !model.busy && index == turns.length - 1
                                    ? model.retry
                                    : null,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                            ],
                            if (model.inputError case final message?)
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  message,
                                  key: const Key('assistant-input-error'),
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_unseen)
                        Positioned(
                          bottom: AppSpacing.sm,
                          left: AppSpacing.lg,
                          right: AppSpacing.lg,
                          child: Center(
                            child: FilledButton.tonalIcon(
                              key: const Key('assistant-jump-latest'),
                              onPressed: () {
                                _scheduleLatest(force: true);
                              },
                              icon: const Icon(Icons.arrow_downward),
                              label: const Text('Latest response'),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              AssistantComposer(
                controller: _draft,
                busy: model.busy,
                onSubmit: () => _ask(model, _draft.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
