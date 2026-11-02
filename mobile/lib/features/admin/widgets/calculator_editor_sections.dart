import 'package:flutter/material.dart';
import '../../../data/models/admin_management.dart';
import 'admin_editor_section.dart';
import 'management_fields.dart';

bool isCalculatorManagement(ManagementArea area) =>
    ![ManagementArea.diseases, ManagementArea.knowledge].contains(area);

String calculatorHeading(ManagementArea area) => switch (area) {
  ManagementArea.fertilizers => 'Fertilizer catalogue',
  ManagementArea.fertilizer => 'Fertilizer application rules',
  ManagementArea.yieldRules => 'Yield planning configurations',
  _ => 'Agronomic model specifications',
};

String calculatorPurpose(ManagementArea area) => switch (area) {
  ManagementArea.fertilizers =>
    'Product composition is information, not a recommended application rate. Manage reviewed product records separately from dosage rules.',
  ManagementArea.fertilizer =>
    'A reviewed product kg/ha rate is scaled by field area. This does not estimate soil nutrient needs or create an application schedule.',
  ManagementArea.yieldRules =>
    'Area × reviewed reference yield provides a conditional planning estimate, not a field-specific forecast or guaranteed harvest.',
  _ =>
    'Source intake only · Pending domain approval / Disabled. Saving a specification does not make it executable.',
};

List<Widget> calculatorEditorSections(
  ManagementEditor editor,
  List<ManagementField> fields,
  Widget Function(ManagementField) buildField,
) {
  final product = editor.area == ManagementArea.fertilizers;
  final specification = editor.area == ManagementArea.modelSpecifications;
  String group(ManagementField field) {
    final key = field.key;
    if (key.startsWith('source.')) return 'Source provenance';
    if (key == 'reviewNote' || key == 'status') return 'Review & status';
    if (key == 'mathematicalDefinition') return 'Mathematical specification';
    if (['inputs', 'outputs', 'coefficients'].contains(key)) {
      return switch (key) {
        'inputs' => 'Input definitions',
        'outputs' => 'Output definitions',
        _ => 'Coefficients',
      };
    }
    if (key.endsWith('Percent')) {
      return product ? 'Nutrient composition' : 'Fertilizer product snapshot';
    }
    if (key.startsWith('product.')) {
      return product &&
              [
                'product.slug',
                'product.name',
                'product.description',
              ].contains(key)
          ? 'Product identity'
          : product
          ? 'Product context'
          : 'Fertilizer product snapshot';
    }
    if (key == 'rate' || key == 'quantityDecimalPlaces') {
      return editor.area == ManagementArea.fertilizer
          ? 'Application rate'
          : 'Reference yield';
    }
    if (key == 'assumptions') return 'Assumptions & limitations';
    if (key == 'applicability') return 'Applicability';
    if ([
      'type',
      'growthStages',
      'suitableConditions',
      'applicationRateText',
    ].contains(key)) {
      return 'Product context';
    }
    return specification ? 'Specification identity' : 'Configuration identity';
  }

  final descriptions = <String, String>{
    'Product identity':
        'Retain stable product identity. A copied product requires a new slug.',
    'Nutrient composition':
        'Percent by mass: nitrogen N, phosphate P₂O₅ (P2O5), potash K₂O (K2O). These percentages are not kg/ha recommendations. Range 0–100; up to 2 decimals. No silent rounding.',
    'Product context':
        'Optional source-backed context. Text about application rates never enables a numerical recommendation.',
    'Configuration identity':
        'Create a new version using the existing identifiers. Stored historical configurations remain unchanged.',
    'Specification identity':
        'The model key and calculation domain remain fixed for an existing specification series.',
    'Mathematical specification':
        'Reviewed mathematical description only. No formula interpreter executes this text.',
    'Fertilizer product snapshot':
        'Exact product snapshot used by this rule. Composition is N/P₂O₅/K₂O percent by mass, not product kg/ha. Existing slugs cannot silently change their snapshot.',
    'Application rate':
        'Reviewed product mass per hectare. Farmer calculations scale this rate by entered field area. Up to 6 decimals; 0–1,000,000 kg/ha. No rate is supplied here.',
    'Reference yield':
        'Reviewed reference kg/ha for conditional planning only. Up to 6 decimals; 0–1,000,000 kg/ha. No field-specific, minimum or potential forecast is enabled.',
    'Applicability':
        'Enter only the crop, region and conditions justified by the reviewed source; no additional prescription fields are implied.',
    'Assumptions & limitations':
        'Record the source limitations and intended scope, one assumption per line.',
    'Source provenance':
        'Keep the source title, publisher, HTTPS reference and exact citation with this version. No extra dates or rights fields are required by this contract.',
    'Review & status':
        'Explicit source/applicability review. Reviewer identity and eligibility remain server-controlled; approval is not independent scientific certification.',
    'Input definitions':
        'Source-justified inputs only: key, unit and description. Maximum 16. No required/type flags exist in this contract.',
    'Output definitions':
        'Define reviewed outputs. Yield requires minimum/expected/potential; fertilizer requires nitrogen/phosphorus/potassium keys. This does not enable their calculation.',
    'Coefficients':
        'Source-backed signed decimal strings, units and source sections. Maximum 32. Values are preserved as strings, never parsed or rounded numerically.',
  };
  final groups = <String, List<Widget>>{};
  for (final field in fields) {
    (groups[group(field)] ??= []).add(buildField(field));
  }
  return [
    for (final group in groups.entries)
      AdminEditorSection(
        title: group.key,
        description: descriptions[group.key]!,
        children: group.value,
      ),
  ];
}
