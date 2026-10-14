import 'calculator_contract.dart';

enum FertilizerCatalogueStatus { ready, pendingRules }

class FertilizerCatalogue {
  FertilizerCatalogue._({
    required this.status,
    required this.message,
    required this.engineVersion,
    required List<FertilizerRule> items,
  }) : items = List.unmodifiable(items);

  final FertilizerCatalogueStatus status;
  final String message;
  final String engineVersion;
  final List<FertilizerRule> items;

  factory FertilizerCatalogue.fromJson(Object? value) {
    final data = calculatorObject(value, const {
      'status',
      'message',
      'engineVersion',
      'items',
    });
    final status = switch (data['status']) {
      'READY' => FertilizerCatalogueStatus.ready,
      'PENDING_RULES' => FertilizerCatalogueStatus.pendingRules,
      _ => throw invalidCalculatorResponse(),
    };
    final items = calculatorList(
      data['items'],
      100,
    ).map(FertilizerRule.fromJson).toList();
    if (data['engineVersion'] != 'area-rate-v1' ||
        (status == FertilizerCatalogueStatus.ready
            ? items.isEmpty
            : items.isNotEmpty) ||
        items.map((rule) => rule.id).toSet().length != items.length) {
      throw invalidCalculatorResponse();
    }
    return FertilizerCatalogue._(
      status: status,
      message: calculatorText(data['message'], 2000),
      engineVersion: data['engineVersion'] as String,
      items: items,
    );
  }
}

class FertilizerRule {
  FertilizerRule._({
    required this.id,
    required this.ruleKey,
    required this.version,
    required this.title,
    required this.crop,
    required this.fertilizer,
    required this.rateKgPerHectare,
    required this.applicability,
    required List<String> assumptions,
    required this.source,
    required this.config,
  }) : assumptions = List.unmodifiable(assumptions);

  final String id;
  final String ruleKey;
  final int version;
  final String title;
  final String crop;
  final FertilizerProduct fertilizer;
  final String rateKgPerHectare;
  final String applicability;
  final List<String> assumptions;
  final FertilizerRuleSource source;
  final FertilizerRuleConfig config;

  factory FertilizerRule.fromJson(Object? value) {
    final data = calculatorObject(value, const {
      'id',
      'ruleKey',
      'version',
      'title',
      'crop',
      'fertilizer',
      'rateKgPerHectare',
      'applicability',
      'assumptions',
      'source',
      'config',
    });
    if (data['crop'] != 'MAIZE') throw invalidCalculatorResponse();
    final rate = calculatorDecimal(
      data['rateKgPerHectare'],
      maximumDecimalPlaces: 6,
    );
    final parts = rate.split('.');
    if (BigInt.parse(parts.first) > BigInt.from(1000000) ||
        (parts.first == '1000000' &&
            parts.length > 1 &&
            BigInt.parse(parts.last) > BigInt.zero)) {
      throw invalidCalculatorResponse();
    }
    return FertilizerRule._(
      id: calculatorPattern(
        data['id'],
        36,
        r'^[a-f0-9]{8}-[a-f0-9]{4}-[1-8][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
      ),
      ruleKey: calculatorPattern(
        data['ruleKey'],
        120,
        r'^[a-z0-9][a-z0-9._-]*$',
      ),
      version: calculatorInteger(data['version']),
      title: calculatorText(data['title'], 255),
      crop: data['crop'] as String,
      fertilizer: FertilizerProduct._fromJson(data['fertilizer']),
      rateKgPerHectare: rate,
      applicability: calculatorText(data['applicability'], 2000),
      assumptions: _assumptions(data['assumptions']),
      source: FertilizerRuleSource.fromJson(data['source']),
      config: FertilizerRuleConfig._fromJson(data['config']),
    );
  }
}

class FertilizerProduct {
  const FertilizerProduct._(this.slug, this.name);
  final String slug;
  final String name;
  factory FertilizerProduct._fromJson(Object? value) {
    final data = calculatorObject(value, const {'slug', 'name'});
    return FertilizerProduct._(
      calculatorPattern(data['slug'], 120, r'^[a-z0-9][a-z0-9-]*$'),
      calculatorText(data['name'], 160),
    );
  }
}

typedef FertilizerRuleSource = CalculatorSource;

List<String> _assumptions(Object? value) {
  final assumptions = calculatorList(value, 8);
  if (assumptions.isEmpty) throw invalidCalculatorResponse();
  return assumptions.map((value) => calculatorText(value, 400)).toList();
}

class FertilizerRuleConfig {
  const FertilizerRuleConfig._({
    required this.key,
    required this.version,
    required this.engineVersion,
    required this.quantityDecimalPlaces,
    required this.roundingMode,
  });
  final String key;
  final int version;
  final String engineVersion;
  final int quantityDecimalPlaces;
  final String roundingMode;
  factory FertilizerRuleConfig._fromJson(Object? value) {
    final data = calculatorObject(value, const {
      'key',
      'version',
      'engineVersion',
      'quantityDecimalPlaces',
      'roundingMode',
    });
    if (data['key'] != 'maize-area-rate' ||
        data['engineVersion'] != 'area-rate-v1' ||
        data['roundingMode'] != 'HALF_UP') {
      throw invalidCalculatorResponse();
    }
    return FertilizerRuleConfig._(
      key: data['key'] as String,
      version: calculatorInteger(data['version']),
      engineVersion: data['engineVersion'] as String,
      quantityDecimalPlaces: calculatorInteger(
        data['quantityDecimalPlaces'],
        minimum: 0,
        maximum: 6,
      ),
      roundingMode: data['roundingMode'] as String,
    );
  }
}
