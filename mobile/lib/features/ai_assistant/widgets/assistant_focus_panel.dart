import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_field.dart';
import '../view_models/assistant_view_model.dart';

class AssistantFocusPanel extends StatelessWidget {
  const AssistantFocusPanel({super.key});
  static const diseases = {
    '': 'From my question',
    'Common_Rust': 'Common Rust',
    'Gray_Leaf_Spot': 'Gray Leaf Spot',
    'Healthy': 'Healthy maize',
    'Northern_Corn_Leaf_Blight': 'Northern Corn Leaf Blight',
  };
  static const topics = {
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
  Widget build(BuildContext context) {
    final model = context.watch<AssistantViewModel>();
    Widget selection(
      String id,
      String label,
      String? value,
      Map<String, String> items,
      ValueChanged<String?> change,
    ) => AppField(
      label: label,
      optional: true,
      child: DropdownButtonFormField<String>(
        key: ValueKey((id, value)),
        initialValue: value ?? '',
        isExpanded: true,
        itemHeight: null,
        items: [
          for (final entry in items.entries)
            DropdownMenuItem(value: entry.key, child: Text(entry.value)),
        ],
        onChanged: model.busy
            ? null
            : (value) => change(value == '' ? null : value),
      ),
    );
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Question focus',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close focus controls',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Each question uses its chosen focus. Previous conversation is not sent. Select a condition or topic for a short follow-up.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ResponsivePair(
                    first: selection(
                      'assistant-disease',
                      'Condition',
                      model.diseaseLabel,
                      diseases,
                      model.selectDisease,
                    ),
                    second: selection(
                      'assistant-topic',
                      'Topic',
                      model.knowledgeType,
                      topics,
                      model.selectTopic,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    model.hasAuthenticatedSession
                        ? 'Up to 12 temporary turns stay available as you switch tabs. Nothing is saved to your account. Clear the conversation, sign out or close the app to discard it.'
                        : 'You can ask questions as a guest. Up to 12 temporary turns stay available as you switch tabs and clear when you sign in or close the app. Sign in to choose a saved scan.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'Questions: 3–1,000 characters and at most 1,800 UTF-8 bytes. Model predictions are not confirmed diagnoses.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
