import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';

/// Presentation only. The existing ViewModel owns validation and submission.
class AssistantComposer extends StatelessWidget {
  const AssistantComposer({
    required this.controller,
    required this.busy,
    required this.onSubmit,
    super.key,
  });
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(
        top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('assistant-question'),
                  controller: controller,
                  enabled: !busy,
                  minLines: 1,
                  maxLines: 3,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    hintText: 'Your maize question',
                    hintMaxLines: 2,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Tooltip(
                message: busy ? 'Waiting for answer' : 'Send question',
                child: SizedBox(
                  width: AppSizing.primaryButtonHeight,
                  height: AppSizing.primaryButtonHeight,
                  child: FilledButton(
                    key: const Key('assistant-send'),
                    onPressed: busy ? null : onSubmit,
                    style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                    child: Icon(
                      busy ? Icons.hourglass_empty : Icons.arrow_upward,
                      semanticLabel: busy
                          ? 'Waiting for answer'
                          : 'Send question',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
