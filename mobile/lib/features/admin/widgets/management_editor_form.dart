import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/app_field.dart';
import 'admin_draft_guard.dart';
import 'admin_editor_section.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_confirmation_dialog.dart';
import '../../../data/models/admin_management.dart';
import 'management_fields.dart';
import 'calculator_editor_sections.dart';
import 'specification_array_editor.dart';
import 'specification_rows.dart';

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
  bool _showErrors = false;
  late final _anchors = {for (final field in _fields) field.key: GlobalKey()};
  late final _focus = {for (final field in _fields) field.key: FocusNode()};

  AdminDraftGuard? _guard;
  bool get _dirty =>
      _approved ||
      _fields.any(
        (field) =>
            _controllers[field.key]!.text !=
            (widget.editor.initial[field.key] ?? ''),
      );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final guard = context.read<AdminDraftGuard?>();
    if (_guard != guard) {
      _guard?.unbind(this);
      _guard = guard;
      guard?.bind(this, () => _dirty, () => widget.busy);
    }
  }

  @override
  void initState() {
    super.initState();
    for (final controller in _controllers.values) {
      controller.addListener(() => _guard?.changed());
    }
  }

  Future<void> _cancel() async {
    if (!_dirty || await confirmDiscardDraft(context)) {
      if (mounted) widget.onCancel();
    }
  }

  @override
  void didUpdateWidget(covariant ManagementEditorForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.busy != widget.busy) _guard?.changed();
  }

  @override
  void dispose() {
    _guard?.unbind(this);
    for (final focus in _focus.values) {
      focus.dispose();
    }
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) {
      setState(() => _showErrors = true);
      for (final field in _fields) {
        final value = _controllers[field.key]!.text;
        final array =
            widget.editor.area == ManagementArea.modelSpecifications &&
            ['inputs', 'outputs', 'coefficients'].contains(field.key);
        final invalid = array
            ? _validateArray(field, value) != null
            : field.options.isNotEmpty
            ? !field.options.containsKey(value)
            : validateManagementField(
                    field.key,
                    value,
                    required: field.required,
                  ) !=
                  null;
        if (invalid) {
          if (!array) _focus[field.key]!.requestFocus();
          final target = _anchors[field.key]!.currentContext;
          if (target != null) {
            await Scrollable.ensureVisible(
              target,
              duration: AppMotion.resolve(context, AppMotion.navigation),
            );
          }
          break;
        }
      }
      return;
    }
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

  String? _validateArray(ManagementField field, String raw) =>
      validateSpecificationRows(
        raw,
        coefficients: field.key == 'coefficients',
        requiredOutputs: field.key != 'outputs'
            ? const []
            : _controllers['kind']!.text == 'YIELD'
            ? const ['minimum', 'expected', 'potential']
            : const ['nitrogen', 'phosphorus', 'potassium'],
      );

  Widget _field(ManagementField field) {
    if (widget.editor.area == ManagementArea.modelSpecifications &&
        ['inputs', 'outputs', 'coefficients'].contains(field.key)) {
      return KeyedSubtree(
        key: _anchors[field.key],
        child: SpecificationArrayEditor(
          name: field.key,
          controller: _controllers[field.key]!,
          busy: widget.busy,
          validator: (raw) => _validateArray(field, raw ?? ''),
        ),
      );
    }
    final numeric =
        field.key == 'rate' ||
        field.key.endsWith('Percent') ||
        [
          'version',
          'configVersion',
          'quantityDecimalPlaces',
        ].contains(field.key);
    final label = field.key == 'rate'
        ? widget.editor.area == ManagementArea.fertilizer
              ? 'Approved product application rate (kg/ha)'
              : 'Reviewed reference yield (kg/ha)'
        : widget.editor.area == ManagementArea.fertilizer &&
              field.key.endsWith('Percent')
        ? switch (field.key) {
            'product.nitrogenPercent' => 'Nitrogen N % by mass',
            'product.phosphorusPercent' => 'Phosphate P₂O₅ % by mass',
            _ => 'Potash K₂O % by mass',
          }
        : field.label;
    final input = field.options.isNotEmpty
        ? DropdownButtonFormField<String>(
            key: ValueKey('management-${field.key}'),
            focusNode: _focus[field.key],
            initialValue:
                field.options.containsKey(_controllers[field.key]!.text)
                ? _controllers[field.key]!.text
                : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: null),
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
        : TextFormField(
            key: ValueKey('management-${field.key}'),
            focusNode: _focus[field.key],
            controller: _controllers[field.key],
            enabled: !widget.busy,
            readOnly: field.fixed,
            maxLength: field.maximum,
            keyboardType: numeric
                ? const TextInputType.numberWithOptions(decimal: true)
                : field.key.endsWith('url')
                ? TextInputType.url
                : field.lines > 1
                ? TextInputType.multiline
                : TextInputType.text,
            minLines: field.lines,
            maxLines: field.lines + 2,
            decoration: InputDecoration(
              labelText: null,
              alignLabelWithHint: field.lines > 1,
            ),
            validator: (value) => validateManagementField(
              field.key,
              value ?? '',
              required: field.required,
            ),
          );
    return AppField(
      key: _anchors[field.key],
      label: label.replaceAll(', optional)', ')').replaceAll(' (optional)', ''),
      optional: !field.required,
      child: input,
    );
  }

  List<Widget> _sections() {
    if (isCalculatorManagement(widget.editor.area)) {
      return [
        if (widget.editor.entry case final entry?) ...[
          AdminContentStatus(entry.status),
          Text(
            widget.editor.area == ManagementArea.fertilizers
                ? 'Product metadata version ${entry.version}. Existing rule snapshots remain unchanged.'
                : 'Based on stored version ${entry.version}. Existing records remain unchanged.',
          ),
        ],
        ...calculatorEditorSections(widget.editor, _fields, _field),
      ];
    }
    final knowledge = widget.editor.area == ManagementArea.knowledge;
    String group(ManagementField field) {
      if (field.key.startsWith('source.') ||
          ['region', 'sourceSection'].contains(field.key)) {
        return 'Source & applicability';
      }
      if (field.key == 'growthStages') return 'Reviewed growth stages';
      if (field.key == 'severityDescriptors') {
        return 'Reviewed severity descriptors';
      }
      if (field.key == 'content') return 'Reviewed knowledge';
      if (field.key == 'reviewNote') return 'Source review';
      return 'Display identity';
    }

    final descriptions = <String, String>{
      'Display identity': knowledge
          ? 'Document series, context and section remain fixed for a new version of an existing document.'
          : 'Display metadata is separate from the immutable trained classifier identity.',
      'Reviewed growth stages':
          'Optional. Leave empty when reviewed source evidence is unavailable. Healthy is a scouting context, not a disease stage.',
      'Reviewed severity descriptors':
          'Optional sourced descriptors only. These do not measure severity from a scan. Do not assign disease severity to Healthy.',
      'Reviewed knowledge':
          'Use reviewed source-backed content. This text is saved as a new immutable version.',
      'Source & applicability':
          'Keep source identity, dates, scope and use restrictions with this version. An approval checkbox is not legal or agricultural certification.',
      'Source review':
          'Record your source and applicability review. Reviewer identity and publication eligibility are confirmed by the server.',
    };
    final groups = <String, List<Widget>>{};
    for (final field in _fields) {
      (groups[group(field)] ??= []).add(_field(field));
    }
    return [
      if (widget.editor.entry case final entry?) ...[
        AdminContentStatus(entry.status),
        Text(
          knowledge
              ? 'Series ${entry.values['documentKey']} · based on version ${entry.version}'
              : 'Protected identity · ${entry.values['literalLabel'] ?? 'Informational entry'} · ${entry.values['slug']}',
        ),
      ],
      for (final group in groups.entries)
        AdminEditorSection(
          title: group.key,
          description: descriptions[group.key]!,
          children: group.value,
        ),
      if (knowledge)
        const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Text(
            'Save Draft → Build Embeddings → Activate\nSaving does not publish. Build and activate are separate, server-confirmed operations.',
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_showErrors)
          Semantics(
            liveRegion: true,
            child: const Text(
              'Review the highlighted fields and source approval before saving.',
            ),
          ),
        Text(
          widget.editor.area == ManagementArea.fertilizers
              ? widget.editor.entry == null
                    ? 'Create reviewed product'
                    : 'Edit product metadata'
              : widget.editor.area == ManagementArea.diseases
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
          ManagementArea.modelSpecifications =>
            'Source-intake only. These immutable specifications remain PENDING_DOMAIN_APPROVAL and DISABLED. No farmer calculation can execute a formula or coefficient entered here. Inputs/outputs use {key, unit, description}; coefficients use {key, value, unit, sourceSection}. Define minimum/expected/potential yield outputs or nitrogen/phosphorus/potassium requirement outputs. Supply only the parameters justified by the cited model.',
          ManagementArea.fertilizers =>
            'Manage sourced product information independently of dosage rules. N/P/K fields represent N/P₂O₅/K₂O percent by mass. Optional stage, conditions and rate text require source review and never enable a numerical recommendation. Products used by calculator rules are frozen; copy them to a new slug to revise content.',
        }),
        ..._sections(),
        ...[
          const SizedBox(height: AppSpacing.lg),
          FormField<bool>(
            initialValue: false,
            validator: (value) =>
                (widget.editor.area == ManagementArea.diseases &&
                        widget.editor.entry != null &&
                        [
                          'growthStages',
                          'severityDescriptors',
                          'reviewNote',
                        ].every(
                          (key) =>
                              (_controllers[key]?.text.trim() ?? '').isEmpty,
                        )) ||
                    value == true
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
                          _guard?.changed();
                        },
                  title: const Text(
                    'I reviewed and approve these sources, use restrictions and local applicability for this project.',
                  ),
                ),
                if (state.errorText != null)
                  Text(
                    state.errorText!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
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
                : widget.editor.area == ManagementArea.fertilizers
                ? 'Save product metadata'
                : widget.editor.area == ManagementArea.diseases
                ? 'Save display metadata'
                : 'Save draft',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: widget.busy ? null : _cancel,
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
) => showAppConfirmation(
  context,
  title: title,
  message: message,
  destructive: true,
);
