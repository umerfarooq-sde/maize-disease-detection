import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/admin_management.dart';
import 'management_fields.dart';

class ManagementEditorForm extends StatefulWidget {
  const ManagementEditorForm({
    required this.editor,
    required this.busy,
    required this.onSave,
    required this.onCancel,
    super.key,
  });
  final ManagementEditor editor;
  final bool busy;
  final Future<void> Function(Map<String, String>) onSave;
  final VoidCallback onCancel;
  @override
  State<ManagementEditorForm> createState() => _ManagementEditorFormState();
}

class _ManagementEditorFormState extends State<ManagementEditorForm> {
  final _form = GlobalKey<FormState>();
  late final List<ManagementField> _fields = managementFields(widget.editor);
  late final Map<String, TextEditingController> _controllers = {
    for (final field in _fields)
      field.key: TextEditingController(
        text: widget.editor.initial[field.key] ?? '',
      ),
  };
  bool _approved = false;
  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final values = {
      for (final field in _fields) field.key: _controllers[field.key]!.text,
      'approved': '$_approved',
    };
    if (widget.editor.area == ManagementArea.diseases &&
        values['status'] == 'INACTIVE') {
      final confirmed = await confirmManagement(
        context,
        'Hide disease knowledge?',
        'This hides the disease catalogue entry and its knowledge from retrieval. Historical documents and model labels are retained.',
      );
      if (!mounted || !confirmed) return;
    }
    await widget.onSave(values);
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.editor.area == ManagementArea.diseases
              ? 'Edit display metadata'
              : 'Create immutable draft version',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(switch (widget.editor.area) {
          ManagementArea.diseases =>
            'Classifier labels and slugs are fixed. Display edits do not retrain or rename an ML class.',
          ManagementArea.knowledge =>
            'Source information belongs to this version. Build embeddings, then explicitly activate. Previous active knowledge stays available until replacement succeeds.',
          ManagementArea.fertilizer =>
            'No dose is suggested. Use only project-approved product kg/ha sources. Product snapshots cannot change under an existing slug; use a new slug for revised product information.',
          ManagementArea.yieldRules =>
            'No yield formula or default rate is invented. This framework requires a reviewed, applicable kg/ha scenario.',
        }),
        for (final field in _fields) ...[
          const SizedBox(height: AppSpacing.lg),
          if (field.options.isNotEmpty)
            DropdownButtonFormField<String>(
              key: ValueKey('management-${field.key}'),
              initialValue:
                  field.options.containsKey(_controllers[field.key]!.text)
                  ? _controllers[field.key]!.text
                  : null,
              isExpanded: true,
              decoration: InputDecoration(labelText: field.label),
              items: [
                for (final item in field.options.entries)
                  DropdownMenuItem(
                    value: item.key,
                    child: Text(item.value, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: widget.busy || field.fixed
                  ? null
                  : (value) {
                      _controllers[field.key]!.text = value ?? '';
                    },
              validator: (value) => value == null ? 'Choose a value.' : null,
            )
          else
            TextFormField(
              key: ValueKey('management-${field.key}'),
              controller: _controllers[field.key],
              enabled: !widget.busy,
              readOnly: field.fixed,
              maxLength: field.maximum,
              minLines: field.lines,
              maxLines: field.lines + 2,
              decoration: InputDecoration(
                labelText: field.label,
                alignLabelWithHint: field.lines > 1,
              ),
              validator: (value) => validateManagementField(
                field.key,
                value ?? '',
                required: field.required,
              ),
            ),
        ],
        if (widget.editor.area != ManagementArea.diseases) ...[
          const SizedBox(height: AppSpacing.lg),
          FormField<bool>(
            initialValue: false,
            validator: (value) => value == true
                ? null
                : 'Review and approve the source before saving.',
            builder: (state) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: state.value,
                  onChanged: widget.busy
                      ? null
                      : (value) {
                          _approved = value ?? false;
                          state.didChange(value);
                        },
                  title: const Text(
                    'I reviewed and approve these sources, use restrictions and local applicability for this project.',
                  ),
                ),
                if (state.errorText != null)
                  Text(
                    state.errorText!,
                    style: const TextStyle(color: AppColors.error),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: widget.busy ? null : _submit,
          child: Text(
            widget.busy
                ? 'Saving…'
                : widget.editor.area == ManagementArea.diseases
                ? 'Save display metadata'
                : 'Save draft',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: widget.busy ? null : widget.onCancel,
          child: const Text('Cancel editing'),
        ),
      ],
    ),
  );
}

Future<bool> confirmManagement(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ??
    false;
