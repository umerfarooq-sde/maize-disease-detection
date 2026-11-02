import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_field.dart';
import '../../../data/models/calculator_input.dart';

class CalculatorInputs<Unit> extends StatelessWidget {
  const CalculatorInputs({
    required this.controller,
    required this.busy,
    required this.areaError,
    required this.areaUnit,
    required this.outputUnit,
    required this.onAreaChanged,
    required this.onAreaUnitChanged,
    required this.onOutputUnitChanged,
    required this.outputUnits,
    required this.outputUnitLabel,
    required this.keyPrefix,
    required this.description,
    super.key,
  });

  final List<Unit> outputUnits;
  final String Function(Unit) outputUnitLabel;
  final String keyPrefix;
  final String description;
  final TextEditingController controller;
  final bool busy;
  final String? areaError;
  final CalculatorAreaUnit areaUnit;
  final Unit outputUnit;
  final ValueChanged<String> onAreaChanged;
  final ValueChanged<CalculatorAreaUnit> onAreaUnitChanged;
  final ValueChanged<Unit> onOutputUnitChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Your field', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(description),
          const SizedBox(height: AppSpacing.lg),
          ResponsivePair(
            first: AppField(
              label: 'Land area',
              child: TextField(
                key: Key('$keyPrefix-area'),
                controller: controller,
                enabled: !busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                onChanged: onAreaChanged,
                decoration: InputDecoration(
                  hintText: 'Enter area',
                  helperText:
                      'Use a decimal point, without separators. Up to 6 decimal places.',
                  helperMaxLines: 4,
                  errorText: areaError,
                  errorMaxLines: 4,
                ),
              ),
            ),
            second: KeyedSubtree(
              key: Key('$keyPrefix-area-unit'),
              child: AppField(
                label: 'Area unit',
                child: DropdownButtonFormField<CalculatorAreaUnit>(
                  key: ValueKey(areaUnit),
                  initialValue: areaUnit,
                  isExpanded: true,
                  itemHeight: null,
                  items: [
                    for (final unit in CalculatorAreaUnit.values)
                      DropdownMenuItem(value: unit, child: Text(unit.label)),
                  ],
                  onChanged: busy
                      ? null
                      : (unit) {
                          if (unit != null) onAreaUnitChanged(unit);
                        },
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          KeyedSubtree(
            key: Key('$keyPrefix-output-unit'),
            child: AppField(
              label: 'Result unit',
              child: DropdownButtonFormField<Unit>(
                key: ValueKey(outputUnit),
                initialValue: outputUnit,
                isExpanded: true,
                itemHeight: null,
                items: [
                  for (final unit in outputUnits)
                    DropdownMenuItem(
                      value: unit,
                      child: Text(outputUnitLabel(unit)),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (unit) {
                        if (unit != null) onOutputUnitChanged(unit);
                      },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
