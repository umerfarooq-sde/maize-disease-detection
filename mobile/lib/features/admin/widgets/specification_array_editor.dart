import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_field.dart';
import 'specification_rows.dart';

/// Presentation adapter over the original JSON-string controller and serializer.
class SpecificationArrayEditor extends StatefulWidget {
  const SpecificationArrayEditor({
    required this.name,
    required this.controller,
    required this.busy,
    required this.validator,
    super.key,
  });
  final String name;
  final TextEditingController controller;
  final bool busy;
  final FormFieldValidator<String> validator;
  @override
  State<SpecificationArrayEditor> createState() =>
      _SpecificationArrayEditorState();
}

class _SpecificationArrayEditorState extends State<SpecificationArrayEditor> {
  bool _advanced = false;
  int _generation = 0;
  bool get coefficients => widget.name == 'coefficients';
  List<Map<String, String>>? get rows => structuredSpecificationRows(
    widget.controller.text,
    coefficients: coefficients,
  );
  void _write(List<Map<String, String>> values) {
    widget.controller.text = jsonEncode(values);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final values = rows;
    final advanced = _advanced || values == null;
    return FormField<String>(
      validator: (_) => widget.controller.text.characters.length > 12000
          ? 'Specification JSON may contain at most 12000 characters.'
          : widget.validator(widget.controller.text),
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: widget.busy || values == null
                    ? null
                    : () => setState(() {
                        _advanced = false;
                        _generation++;
                      }),
                icon: const Icon(Icons.view_list_outlined),
                label: Text('Structured ${widget.name}'),
              ),
              TextButton(
                onPressed: widget.busy
                    ? null
                    : () => setState(() => _advanced = true),
                child: Text('Advanced JSON · ${widget.name}'),
              ),
            ],
          ),
          if (values == null)
            const Text(
              'This JSON cannot be represented losslessly by the supported row controls. Advanced JSON retains all fields; correct syntax/schema errors before saving.',
            ),
          if (advanced)
            AppField(
              label: '${widget.name}: reviewed JSON specification',
              child: TextFormField(
                key: ValueKey('management-${widget.name}'),
                controller: widget.controller,
                enabled: !widget.busy,
                maxLength: 12000,
                minLines: 5,
                maxLines: 12,
                decoration: const InputDecoration(
                  helperText:
                      'Exact contract JSON. Coefficient values are strings, never floating-point numbers.',
                  helperMaxLines: 4,
                ),
                keyboardType: TextInputType.multiline,
                onChanged: (_) => setState(() {}),
              ),
            )
          else ...[
            Text(
              '${values.length} ${widget.name} · maximum ${coefficients ? 32 : 16}',
            ),
            for (var index = 0; index < values.length; index++)
              _SpecificationRow(
                key: ValueKey('${widget.name}-$_generation-$index'),
                name: widget.name,
                index: index,
                initial: values[index],
                coefficients: coefficients,
                busy: widget.busy,
                onChanged: (key, value) {
                  final next = [
                    for (final row in values) {...row},
                  ];
                  next[index][key] = value;
                  _write(next);
                },
                onRemove: () {
                  final next = [
                    for (final row in values) {...row},
                  ]..removeAt(index);
                  _generation++;
                  _write(next);
                },
              ),
            OutlinedButton.icon(
              onPressed:
                  widget.busy || values.length >= (coefficients ? 32 : 16)
                  ? null
                  : () {
                      _generation++;
                      _write([
                        ...values,
                        {
                          for (final key in specificationRowKeys(coefficients))
                            key: key == 'unit' ? 'DIMENSIONLESS' : '',
                        },
                      ]);
                    },
              icon: const Icon(Icons.add),
              label: Text(
                'Add ${widget.name == 'coefficients'
                    ? 'coefficient'
                    : widget.name == 'inputs'
                    ? 'input'
                    : 'output'}',
              ),
            ),
          ],
          if (field.errorText != null)
            Semantics(
              liveRegion: true,
              child: Text(
                field.errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}

class _SpecificationRow extends StatefulWidget {
  const _SpecificationRow({
    required this.name,
    required this.index,
    required this.initial,
    required this.coefficients,
    required this.busy,
    required this.onChanged,
    required this.onRemove,
    super.key,
  });
  final String name;
  final int index;
  final Map<String, String> initial;
  final bool coefficients, busy;
  final void Function(String, String) onChanged;
  final VoidCallback onRemove;
  @override
  State<_SpecificationRow> createState() => _SpecificationRowState();
}

class _SpecificationRowState extends State<_SpecificationRow> {
  late final _controllers = {
    for (final entry in widget.initial.entries)
      entry.key: TextEditingController(text: entry.value),
  };
  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${widget.name} · definition ${widget.index + 1}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final key in specificationRowKeys(widget.coefficients))
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: AppField(
              label: switch (key) {
                'value' => 'Coefficient decimal value (string)',
                'sourceSection' => 'Source section',
                _ => key,
              },
              child: key == 'unit'
                  ? DropdownButtonFormField<String>(
                      initialValue: widget.initial[key],
                      isExpanded: true,
                      items: [
                        for (final unit in specificationUnits)
                          DropdownMenuItem(
                            value: unit,
                            child: Text(unit, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: widget.busy
                          ? null
                          : (value) {
                              if (value != null) widget.onChanged(key, value);
                            },
                    )
                  : TextFormField(
                      key: ValueKey('spec-${widget.name}-${widget.index}-$key'),
                      controller: _controllers[key],
                      enabled: !widget.busy,
                      maxLength: key == 'key'
                          ? 48
                          : key == 'value'
                          ? 64
                          : 600,
                      minLines: 1,
                      maxLines: key == 'description' || key == 'sourceSection'
                          ? 4
                          : 1,
                      keyboardType: key == 'value'
                          ? const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            )
                          : TextInputType.text,
                      onChanged: (value) => widget.onChanged(key, value),
                    ),
            ),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: widget.busy ? null : widget.onRemove,
            icon: const Icon(Icons.remove_circle_outline),
            label: Text('Remove ${widget.name} definition ${widget.index + 1}'),
          ),
        ),
        const Divider(),
      ],
    ),
  );
}
