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
  if (editor.area == ManagementArea.fertilizers) {
    return [
      ManagementField(
        'product.slug',
        'Stable product slug',
        maximum: 120,
        fixed: editor.entry != null,
      ),
      const ManagementField('product.name', 'Product name', maximum: 160),
      const ManagementField(
        'product.description',
        'Reviewed product description',
        maximum: 2000,
        lines: 3,
      ),
      const ManagementField(
        'product.nitrogenPercent',
        'Nitrogen N % by mass',
        maximum: 6,
      ),
      const ManagementField(
        'product.phosphorusPercent',
        'Phosphate P₂O₅ % by mass',
        maximum: 6,
      ),
      const ManagementField(
        'product.potassiumPercent',
        'Potash K₂O % by mass',
        maximum: 6,
      ),
      const ManagementField(
        'product.applicationMethod',
        'Source-backed application method (optional)',
        maximum: 1600,
        lines: 2,
        required: false,
      ),
      const ManagementField(
        'product.precautions',
        'Precautions (one per line, optional)',
        maximum: 3200,
        lines: 3,
        required: false,
      ),
      const ManagementField(
        'type',
        'Product type (optional)',
        maximum: 160,
        required: false,
      ),
      const ManagementField(
        'growthStages',
        'Reviewed crop-stage applicability (one per line, optional)',
        maximum: 1932,
        lines: 2,
        required: false,
      ),
      const ManagementField(
        'suitableConditions',
        'Reviewed suitable conditions (one per line, optional)',
        maximum: 4800,
        lines: 3,
        required: false,
      ),
      const ManagementField(
        'applicationRateText',
        'Source rate reference (optional text, never a calculation rule)',
        maximum: 1000,
        lines: 2,
        required: false,
      ),
      const ManagementField('source.title', 'Source title'),
      const ManagementField('source.publisher', 'Source publisher'),
      const ManagementField('source.url', 'HTTPS source', maximum: 2048),
      const ManagementField(
        'source.citation',
        'Exact source reference',
        maximum: 1000,
        lines: 3,
      ),
      const ManagementField(
        'status',
        'Catalogue visibility',
        options: {'DRAFT': 'Draft', 'ACTIVE': 'Active', 'INACTIVE': 'Inactive'},
      ),
      const ManagementField(
        'reviewNote',
        'Source and applicability review note',
        maximum: 2000,
        lines: 3,
      ),
    ];
  }
  if (editor.area == ManagementArea.modelSpecifications) {
    return [
      ManagementField(
        'modelKey',
        'Stable model specification key',
        maximum: 80,
        fixed: editor.entry != null,
      ),
      ManagementField(
        'kind',
        'Calculation domain',
        options: const {
          'FERTILIZER': 'Fertilizer requirements',
          'YIELD': 'Yield scenarios',
        },
        fixed: editor.entry != null,
      ),
      const ManagementField('title', 'Specification title', maximum: 160),
      const ManagementField(
        'mathematicalDefinition',
        'Source-backed mathematical definition (review only; never executed)',
        maximum: 6000,
        lines: 6,
      ),
      const ManagementField(
        'applicability',
        'Applicable region, conditions and restrictions',
        maximum: 2000,
        lines: 3,
      ),
      const ManagementField(
        'assumptions',
        'Explicit assumptions (one per line)',
        maximum: 3200,
        lines: 3,
      ),
      for (final key in ['inputs', 'outputs', 'coefficients'])
        ManagementField(
          key,
          '$key: reviewed JSON specification',
          maximum: 12000,
          lines: 4,
        ),
      const ManagementField('source.title', 'Source title'),
      const ManagementField('source.publisher', 'Source publisher'),
      const ManagementField('source.url', 'HTTPS source', maximum: 2048),
      const ManagementField(
        'source.citation',
        'Exact model/source reference',
        maximum: 1000,
        lines: 3,
      ),
      const ManagementField(
        'reviewNote',
        'Source review note',
        maximum: 2000,
        lines: 3,
      ),
    ];
  }
  final disease = editor.area == ManagementArea.diseases;
  final knowledge = editor.area == ManagementArea.knowledge;
  final fertilizer = editor.area == ManagementArea.fertilizer;
  if (disease) {
    return [
      if (editor.entry == null)
        const ManagementField(
          'slug',
          'Informational catalogue slug (never an ML class)',
          maximum: 120,
        ),
      ...const [
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
        ManagementField(
          'growthStages',
          'Reviewed growth-stage applicability (one per line)',
          maximum: 1932,
          lines: 3,
          required: false,
        ),
        ManagementField(
          'severityDescriptors',
          'Reviewed severity descriptions (one per line)',
          maximum: 4808,
          lines: 3,
          required: false,
        ),
        ManagementField(
          'source.title',
          'Metadata source title',
          required: false,
        ),
        ManagementField(
          'source.publisher',
          'Metadata source publisher',
          required: false,
        ),
        ManagementField(
          'source.url',
          'Metadata HTTPS source',
          maximum: 2048,
          required: false,
        ),
        ManagementField(
          'source.authors',
          'Authors (one per line)',
          maximum: 2576,
          required: false,
        ),
        ManagementField(
          'source.publishedAt',
          'Publication date (optional)',
          maximum: 10,
          required: false,
        ),
        ManagementField(
          'source.retrievedAt',
          'Source review date (YYYY-MM-DD)',
          maximum: 10,
          required: false,
        ),
        ManagementField(
          'source.rights',
          'Source rights / attribution',
          maximum: 1000,
          required: false,
        ),
        ManagementField(
          'reviewNote',
          'Review note (required for sourced changes or new entries)',
          maximum: 2000,
          lines: 3,
          required: false,
        ),
      ],
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
