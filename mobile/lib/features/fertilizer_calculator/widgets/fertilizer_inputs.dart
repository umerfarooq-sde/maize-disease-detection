import 'package:flutter/material.dart';
import '../../../data/models/fertilizer_input.dart';
import '../../tools/widgets/calculator_inputs.dart';

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
  Widget build(BuildContext context) => CalculatorInputs<FertilizerMassUnit>(
    controller: controller,
    busy: busy,
    areaError: areaError,
    areaUnit: areaUnit,
    outputUnit: outputUnit,
    onAreaChanged: onAreaChanged,
    onAreaUnitChanged: onAreaUnitChanged,
    onOutputUnitChanged: onOutputUnitChanged,
    outputUnits: FertilizerMassUnit.values,
    outputUnitLabel: (unit) =>
        unit == FertilizerMassUnit.kg ? 'Kilograms (kg)' : 'Grams (g)',
    keyPrefix: 'fertilizer',
    description:
        'Crop: maize. Enter the area to which the selected rule applies.',
  );
}
