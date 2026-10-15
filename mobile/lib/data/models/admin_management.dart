import '../../core/exceptions/app_exception.dart';
import 'calculator_input.dart';

enum ManagementArea {
  knowledge('Knowledge'),
  diseases('Diseases'),
  fertilizer('Fertilizer rules'),
  yieldRules('Yield rules');

  const ManagementArea(this.label);
  final String label;
}

const managementKnowledgeTypes = [
  'OVERVIEW',
  'SYMPTOMS',
  'CAUSES',
  'CONDITIONS',
  'MANAGEMENT',
  'PREVENTION',
  'REFERENCES',
];
Map<String, dynamic> managementObject(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const AppException(AppErrorKind.invalidResponse);
  }
  return value;
}

class ManagementEntry {
  ManagementEntry._(
    this.id,
    this.title,
    this.status,
    this.version,
    this.values,
  );
  final String id, title, status;
  final int version;
  final Map<String, dynamic> values;
  factory ManagementEntry.fromJson(Object? raw, ManagementArea area) {
    final data = managementObject(raw);
    final id = data['id'], status = data['status'];
    final version = area == ManagementArea.diseases ? 0 : data['version'];
    final title =
        data['title'] ?? data['name'] ?? data['ruleKey'] ?? data['configKey'];
    if (id is! String ||
        !RegExp(r'^[a-f0-9-]{36}$').hasMatch(id) ||
        title is! String ||
        title.length > 255 ||
        version is! int ||
        version < 0 ||
        version > 2147483647 ||
        !['DRAFT', 'ACTIVE', 'INACTIVE', 'ARCHIVED'].contains(status)) {
      throw const AppException(AppErrorKind.invalidResponse);
    }
    if (area == ManagementArea.diseases &&
        (data['revision'] is! String ||
            data['slug'] is! String ||
            data['literalLabel'] is! String)) {
      throw const AppException(AppErrorKind.invalidResponse);
    }
    return ManagementEntry._(
      id,
      title,
      status as String,
      version,
      Map.unmodifiable(data),
    );
  }
  bool get ready =>
      values['validForActivation'] == true || values['indexed'] == true;
}

class ManagementPage {
  ManagementPage(this.items, this.nextCursor);
  final List<ManagementEntry> items;
  final String? nextCursor;
  factory ManagementPage.fromJson(Object? raw, ManagementArea area) {
    final data = managementObject(raw);
    final list = data['items'];
    final cursor = data['nextCursor'];
    if (list is! List ||
        list.length > 100 ||
        (cursor != null &&
            (cursor is! String ||
                !RegExp(r'^[a-f0-9-]{36}$').hasMatch(cursor)))) {
      throw const AppException(AppErrorKind.invalidResponse);
    }
    final items = list
        .map((value) => ManagementEntry.fromJson(value, area))
        .toList();
    if (items.map((item) => item.id).toSet().length != items.length) {
      throw const AppException(AppErrorKind.invalidResponse);
    }
    return ManagementPage(List.unmodifiable(items), cursor as String?);
  }
}

class ManagementEditor {
  ManagementEditor(this.area, this.entry, this.initial);
  final ManagementArea area;
  final ManagementEntry? entry;
  final Map<String, String> initial;
}

Map<String, String> managementEditorValues(
  ManagementArea area,
  ManagementEntry? entry,
) {
  final data = entry?.values ?? const <String, dynamic>{};
  final result = <String, String>{};
  void text(String key, Object? value) {
    result[key] = value is String
        ? value
        : value is int
        ? '$value'
        : '';
  }

  void source(Object? raw, bool knowledge) {
    final item = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
    for (final key in [
      'title',
      'url',
      'publisher',
      if (knowledge) ...[
        'publishedAt',
        'retrievedAt',
        'rights',
      ] else
        'citation',
    ]) {
      text('source.$key', item[key]);
    }
    if (knowledge) {
      result['source.authors'] = (item['authors'] as List? ?? [])
          .whereType<String>()
          .join('\n');
    }
  }

  if (area == ManagementArea.diseases) {
    for (final key in ['name', 'scientificName', 'description', 'status']) {
      text(key, data[key]);
    }
  } else if (area == ManagementArea.knowledge) {
    for (final key in [
      'documentKey',
      'diseaseSlug',
      'knowledgeType',
      'title',
      'content',
    ]) {
      text(key, data[key]);
    }
    final curation = data['curation'] is Map<String, dynamic>
        ? data['curation'] as Map<String, dynamic>
        : const <String, dynamic>{};
    text('region', curation['region']);
    text('sourceSection', curation['sourceSection']);
    source(data['source'], true);
  } else {
    final draft = data['draftInput'] is Map<String, dynamic>
        ? data['draftInput'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final rule =
        area == ManagementArea.fertilizer &&
            draft['rule'] is Map<String, dynamic>
        ? draft['rule'] as Map<String, dynamic>
        : draft;
    final product = draft['product'] is Map<String, dynamic>
        ? draft['product'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final config = draft['config'] is Map<String, dynamic>
        ? draft['config'] as Map<String, dynamic>
        : draft;
    for (final key in [
      'title',
      'applicability',
      if (area == ManagementArea.fertilizer) 'ruleKey',
    ]) {
      text(key, rule[key]);
    }
    text(
      'rate',
      rule[area == ManagementArea.fertilizer
          ? 'rateKgPerHectare'
          : 'expectedYieldKgPerHectare'],
    );
    result['assumptions'] = (rule['assumptions'] as List? ?? [])
        .whereType<String>()
        .join('\n');
    source(rule['source'], false);
    result['version'] = '${(entry?.version ?? 0) + 1}';
    text('quantityDecimalPlaces', config['quantityDecimalPlaces'] ?? 3);
    result['configVersion'] = '${config['version'] ?? 1}';
    for (final key in [
      'slug',
      'name',
      'description',
      'nitrogenPercent',
      'phosphorusPercent',
      'potassiumPercent',
      'applicationMethod',
      'sourceReference',
    ]) {
      text('product.$key', product[key]);
    }
    result['product.precautions'] = (product['precautions'] as List? ?? [])
        .whereType<String>()
        .join('\n');
  }
  result['reviewNote'] = '';
  return result;
}

String? validateManagementField(
  String key,
  String value, {
  bool required = true,
}) {
  final text = value.trim();
  if (['assumptions', 'product.precautions', 'source.authors'].contains(key) &&
      text.isNotEmpty) {
    final lines = text.split('\n').where((line) => line.trim().isNotEmpty);
    if (lines.length > (key == 'source.authors' ? 16 : 8) ||
        lines.any(
          (line) => line.length > (key == 'source.authors' ? 160 : 400),
        )) {
      return 'Too many or overly long lines. Review the stated limits.';
    }
  }
  if (text.isEmpty) return required ? 'This field is required.' : null;
  if (RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]').hasMatch(text)) {
    return 'Remove control characters.';
  }
  if (key == 'rate') {
    try {
      normalizeCalculatorDecimal(text, allowZero: true);
    } on AppException {
      return 'Use a decimal from 0 to 1,000,000, up to 6 decimal places.';
    }
  }
  if (['version', 'configVersion', 'quantityDecimalPlaces'].contains(key)) {
    final number = int.tryParse(text);
    if (!RegExp(r'^(?:0|[1-9]\d*)$').hasMatch(text) ||
        number == null ||
        number < (key == 'quantityDecimalPlaces' ? 0 : 1) ||
        number > (key == 'quantityDecimalPlaces' ? 6 : 2147483647)) {
      return 'Enter a valid whole number.';
    }
  }
  if (key.endsWith('Percent')) {
    final number = double.tryParse(text);
    if (!RegExp(r'^(?:0|[1-9]\d{0,2})(?:\.\d{1,2})?$').hasMatch(text) ||
        number == null ||
        number > 100) {
      return 'Enter 0–100 with up to 2 decimal places.';
    }
  }
  if (key.endsWith('.url') || key == 'product.sourceReference') {
    final url = Uri.tryParse(text);
    if (url == null ||
        url.scheme != 'https' ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        RegExp(r'\s').hasMatch(text)) {
      return 'Use an HTTPS reference without credentials.';
    }
  }
  if (key.endsWith('At')) {
    final date = DateTime.tryParse('${text}T00:00:00Z');
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text) ||
        date == null ||
        date.year < 1 ||
        date.toIso8601String().substring(0, 10) != text) {
      return 'Use an actual YYYY-MM-DD date.';
    }
  }
  if (['documentKey', 'product.slug', 'ruleKey'].contains(key) &&
      !RegExp(
        key == 'documentKey'
            ? r'^[a-z0-9][a-z0-9._-]*$'
            : r'^[a-z0-9]+(?:-[a-z0-9]+)*$',
      ).hasMatch(text)) {
    return 'Use a stable lowercase identifier.';
  }
  if (key == 'reviewNote' && text.length < 20) {
    return 'Describe the source and applicability review (at least 20 characters).';
  }
  return null;
}

Map<String, Object?> managementWrite(
  ManagementEditor editor,
  Map<String, String> fields,
) {
  String value(String key) => fields[key]?.trim() ?? '';
  List<String> lines(String key) => value(key)
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  int integer(String key) => int.tryParse(value(key)) ?? -1;
  if (editor.area == ManagementArea.diseases) {
    return {
      'name': value('name'),
      'scientificName': value('scientificName').isEmpty
          ? null
          : value('scientificName'),
      'description': value('description'),
      'status': value('status'),
      'expectedRevision': editor.entry!.values['revision'],
    };
  }
  if (value('approved') != 'true') {
    throw const AppException(AppErrorKind.validation);
  }
  final source = <String, Object?>{
    for (final key in ['title', 'publisher', 'url']) key: value('source.$key'),
  };
  if (editor.area == ManagementArea.knowledge) {
    source.addAll({
      'authors': lines('source.authors'),
      'publishedAt': value('source.publishedAt').isEmpty
          ? null
          : value('source.publishedAt'),
      'retrievedAt': value('source.retrievedAt'),
      'rights': value('source.rights'),
    });
    return {
      'documentKey': value('documentKey'),
      'expectedVersion': editor.entry?.version ?? 0,
      'diseaseSlug': value('diseaseSlug'),
      'knowledgeType': value('knowledgeType'),
      'title': value('title'),
      'content': value('content'),
      'source': source,
      'region': value('region'),
      'sourceSection': value('sourceSection'),
      'reviewNote': value('reviewNote'),
      'approved': true,
    };
  }
  source['citation'] = value('source.citation');
  final rule = <String, Object?>{
    'version': integer('version'),
    'title': value('title'),
    'applicability': value('applicability'),
    'assumptions': lines('assumptions'),
    'source': source,
    'reviewNote': value('reviewNote'),
  };
  final rate = normalizeCalculatorDecimal(value('rate'), allowZero: true);
  if (editor.area == ManagementArea.yieldRules) {
    return {
      ...rule,
      'expectedYieldKgPerHectare': rate,
      'quantityDecimalPlaces': integer('quantityDecimalPlaces'),
    };
  }
  return {
    'rule': {...rule, 'ruleKey': value('ruleKey'), 'rateKgPerHectare': rate},
    'config': {
      'version': integer('configVersion'),
      'quantityDecimalPlaces': integer('quantityDecimalPlaces'),
    },
    'product': {
      for (final key in [
        'slug',
        'name',
        'description',
        'nitrogenPercent',
        'phosphorusPercent',
        'potassiumPercent',
        'sourceReference',
      ])
        key: value('product.$key'),
      'applicationMethod': value('product.applicationMethod').isEmpty
          ? null
          : value('product.applicationMethod'),
      'precautions': lines('product.precautions'),
    },
  };
}
