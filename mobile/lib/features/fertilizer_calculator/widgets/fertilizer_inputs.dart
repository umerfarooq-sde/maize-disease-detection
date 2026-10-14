import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/fertilizer_input.dart';

class FertilizerInputs extends StatelessWidget {
  const FertilizerInputs({
    required this.controller,
    required this.busy,
    required this.areaError,
    required this.areaUnit,
    required this.outputUnit,
    required this.onAreaChanged,
    required this.onAreaUnitChanged,
    required this.onOutputUnitChanged,
    super.key,
  });

  final TextEditingController controller;
  final bool busy;
  final String? areaError;
  final FertilizerAreaUnit areaUnit;
  final FertilizerMassUnit outputUnit;
  final ValueChanged<String> onAreaChanged;
  final ValueChanged<FertilizerAreaUnit> onAreaUnitChanged;
  final ValueChanged<FertilizerMassUnit> onOutputUnitChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Your field', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Crop: maize. Enter the area to which the selected rule applies.',
          ),
          const SizedBox(height: AppSpacing.lg),
          ResponsivePair(
            first: TextField(
              key: const Key('fertilizer-area'),
              controller: controller,
              enabled: !busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              onChanged: onAreaChanged,
              decoration: InputDecoration(
                labelText: 'Land area',
                hintText: 'Enter area',
                helperText:
                    'Use a decimal point, without separators. Up to 6 decimal places.',
                helperMaxLines: 4,
                errorText: areaError,
                errorMaxLines: 4,
              ),
            ),
            second: KeyedSubtree(
              key: const Key('fertilizer-area-unit'),
              child: DropdownButtonFormField<FertilizerAreaUnit>(
                key: ValueKey(areaUnit),
                initialValue: areaUnit,
                decoration: const InputDecoration(labelText: 'Area unit'),
                isExpanded: true,
                itemHeight: null,
                items: [
                  for (final unit in FertilizerAreaUnit.values)
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
          const SizedBox(height: AppSpacing.lg),
          KeyedSubtree(
            key: const Key('fertilizer-output-unit'),
            child: DropdownButtonFormField<FertilizerMassUnit>(
              key: ValueKey(outputUnit),
              initialValue: outputUnit,
              decoration: const InputDecoration(labelText: 'Result unit'),
              isExpanded: true,
              itemHeight: null,
              items: [
                for (final unit in FertilizerMassUnit.values)
                  DropdownMenuItem(
                    value: unit,
                    child: Text(
                      unit == FertilizerMassUnit.kg
                          ? 'Kilograms (kg)'
                          : 'Grams (g)',
                    ),
                  ),
              ],
              onChanged: busy
                  ? null
                  : (unit) {
                      if (unit != null) onOutputUnitChanged(unit);
                    },
            ),
          ),
        ],
      ),
    ),
  );
}
