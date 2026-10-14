import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/responsive.dart';

class AssistantComposer extends StatelessWidget {
  const AssistantComposer({
    required this.controller,
    required this.busy,
    required this.inputError,
    required this.diseaseLabel,
    required this.knowledgeType,
    required this.onSelectDisease,
    required this.onSelectTopic,
    required this.onSubmit,
    super.key,
  });

  final TextEditingController controller;
  final bool busy;
  final String? inputError;
  final String? diseaseLabel;
  final String? knowledgeType;
  final ValueChanged<String?> onSelectDisease;
  final ValueChanged<String?> onSelectTopic;
  final VoidCallback onSubmit;

  static const _diseases = {
    '': 'From my question',
    'Common_Rust': 'Common Rust',
    'Gray_Leaf_Spot': 'Gray Leaf Spot',
    'Healthy': 'Healthy maize',
    'Northern_Corn_Leaf_Blight': 'Northern Corn Leaf Blight',
  };
  static const _topics = {
    '': 'From my question',
    'OVERVIEW': 'Overview',
    'SYMPTOMS': 'Symptoms',
    'CAUSES': 'Causes',
    'CONDITIONS': 'Favorable conditions',
    'MANAGEMENT': 'Treatment / management',
    'PREVENTION': 'Prevention',
    'REFERENCES': 'References',
  };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Ask a question', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.sm),
      const Text(
        'Each question uses its chosen focus. Select a condition or topic for a short follow-up.',
      ),
      const SizedBox(height: AppSpacing.lg),
      ResponsivePair(
        first: _selection(
          key: const Key('assistant-disease'),
          label: 'Condition (optional)',
          selected: diseaseLabel,
          items: _diseases,
          onChange: onSelectDisease,
        ),
        second: _selection(
          key: const Key('assistant-topic'),
          label: 'Topic (optional)',
          selected: knowledgeType,
          items: _topics,
          onChange: onSelectTopic,
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      TextField(
        key: const Key('assistant-question'),
        controller: controller,
        enabled: !busy,
        minLines: 2,
        maxLines: 5,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        decoration: const InputDecoration(
          labelText: 'Your maize question',
          hintText: 'For example: What causes common rust in maize?',
          helperText: '3–1,000 characters. Ask one topic at a time.',
          helperMaxLines: 3,
        ),
      ),
      if (inputError case final message?) ...[
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          liveRegion: true,
          child: Text(
            message,
            key: const Key('assistant-input-error'),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.error),
          ),
        ),
      ],
      const SizedBox(height: AppSpacing.lg),
      FilledButton.icon(
        key: const Key('assistant-send'),
        onPressed: busy ? null : onSubmit,
        icon: const Icon(Icons.send_outlined),
        label: Text(busy ? 'Waiting for answer…' : 'Send question'),
      ),
    ],
  );

  Widget _selection({
    required Key key,
    required String label,
    required String? selected,
    required Map<String, String> items,
    required ValueChanged<String?> onChange,
  }) => DropdownButtonFormField<String>(
    key: ValueKey((key, selected)),
    initialValue: selected ?? '',
    decoration: InputDecoration(labelText: label),
    isExpanded: true,
    itemHeight: null,
    items: [
      for (final entry in items.entries)
        DropdownMenuItem(value: entry.key, child: Text(entry.value)),
    ],
    onChanged: busy ? null : (value) => onChange(value == '' ? null : value),
  );
}
