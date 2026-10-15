import '../../../data/models/admin_management.dart';
import '../../../data/models/scan_prediction.dart';

class ManagementField {
  const ManagementField(
    this.key,
    this.label, {
    this.maximum = 255,
    this.lines = 1,
    this.required = true,
    this.options = const {},
    this.fixed = false,
  });
  final String key, label;
  final int maximum, lines;
  final bool required, fixed;
  final Map<String, String> options;
}

List<ManagementField> managementFields(ManagementEditor editor) {
  final disease = editor.area == ManagementArea.diseases;
  final knowledge = editor.area == ManagementArea.knowledge;
  final fertilizer = editor.area == ManagementArea.fertilizer;
  if (disease) {
    return const [
      ManagementField('name', 'Display name', maximum: 160),
      ManagementField(
        'scientificName',
        'Scientific name',
        maximum: 200,
        required: false,
      ),
      ManagementField(
        'description',
        'Display description',
        maximum: 2000,
        lines: 4,
      ),
      ManagementField(
        'status',
        'Catalogue visibility',
        options: {'ACTIVE': 'Active', 'INACTIVE': 'Inactive'},
      ),
    ];
  }
  return [
    if (knowledge) ...[
      ManagementField(
        'documentKey',
        'Document series key',
        maximum: 100,
        fixed: editor.entry != null,
      ),
      ManagementField(
        'diseaseSlug',
        'Fixed classifier context',
        options: {
          for (final label in ScanPrediction.classLabels)
            label.toLowerCase().replaceAll('_', '-'): label,
        },
        fixed: editor.entry != null,
      ),
      ManagementField(
        'knowledgeType',
        'Knowledge section',
        options: {for (final kind in managementKnowledgeTypes) kind: kind},
        fixed: editor.entry != null,
      ),
    ] else ...[
      const ManagementField('version', 'New rule version', maximum: 10),
      if (fertilizer) ...const [
        ManagementField('ruleKey', 'Rule series key', maximum: 120),
        ManagementField(
          'configVersion',
          'Calculator configuration version',
          maximum: 10,
        ),
      ],
    ],
    const ManagementField('title', 'Title', maximum: 160),
    if (knowledge) ...const [
      ManagementField(
        'content',
        'Reviewed knowledge text',
        maximum: 4000,
        lines: 8,
      ),
      ManagementField('region', 'Source region / applicability', maximum: 255),
      ManagementField(
        'sourceSection',
        'Source section / page reference',
        maximum: 600,
        lines: 2,
      ),
    ] else ...const [
      ManagementField('rate', 'Reviewed kg/ha value', maximum: 14),
      ManagementField(
        'applicability',
        'Applicable crop, region and conditions',
        maximum: 2000,
        lines: 3,
      ),
      ManagementField(
        'assumptions',
        'Assumptions (one per line, up to 8)',
        maximum: 3200,
        lines: 3,
      ),
      ManagementField(
        'quantityDecimalPlaces',
        'Output decimal places (0–6)',
        maximum: 1,
      ),
    ],
    ...const [
      ManagementField('source.title', 'Source title'),
      ManagementField('source.publisher', 'Source publisher'),
      ManagementField('source.url', 'HTTPS source reference', maximum: 2048),
    ],
    if (knowledge) ...const [
      ManagementField(
        'source.authors',
        'Authors (one per line, up to 16)',
        maximum: 2576,
        lines: 2,
        required: false,
      ),
      ManagementField(
        'source.publishedAt',
        'Publication date (YYYY-MM-DD, optional)',
        maximum: 10,
        required: false,
      ),
      ManagementField(
        'source.retrievedAt',
        'Source retrieval date (YYYY-MM-DD)',
        maximum: 10,
      ),
      ManagementField(
        'source.rights',
        'Source rights / use restrictions',
        maximum: 1000,
        lines: 3,
      ),
    ] else
      const ManagementField(
        'source.citation',
        'Source citation / recommendation reference',
        maximum: 1000,
        lines: 3,
      ),
    if (fertilizer) ...const [
      ManagementField('product.slug', 'Fertilizer product slug', maximum: 120),
      ManagementField('product.name', 'Fertilizer product name', maximum: 160),
      ManagementField(
        'product.description',
        'Product description',
        maximum: 2000,
        lines: 3,
      ),
      ManagementField('product.nitrogenPercent', 'Nitrogen %', maximum: 6),
      ManagementField('product.phosphorusPercent', 'Phosphorus %', maximum: 6),
      ManagementField('product.potassiumPercent', 'Potassium %', maximum: 6),
      ManagementField(
        'product.applicationMethod',
        'Application method (optional)',
        maximum: 1600,
        lines: 2,
        required: false,
      ),
      ManagementField(
        'product.precautions',
        'Precautions (one per line, up to 8)',
        maximum: 3200,
        lines: 3,
        required: false,
      ),
      ManagementField(
        'product.sourceReference',
        'HTTPS product information source',
        maximum: 2048,
      ),
    ],
    const ManagementField(
      'reviewNote',
      'Source and applicability review note',
      maximum: 2000,
      lines: 3,
    ),
  ];
}
