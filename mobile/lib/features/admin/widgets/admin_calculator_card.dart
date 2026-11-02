import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/admin_management.dart';
import 'admin_editor_section.dart';

Map<String, dynamic> calculatorMap(Object? value) =>
    value is Map<String, dynamic> ? value : const {};

class AdminCalculatorCard extends StatelessWidget {
  const AdminCalculatorCard({
    required this.area,
    required this.item,
    required this.busy,
    required this.onEdit,
    required this.onCopy,
    required this.onStatus,
    super.key,
  });
  final ManagementArea area;
  final ManagementEntry item;
  final bool busy;
  final VoidCallback onEdit, onCopy;
  final ValueChanged<String> onStatus;
  @override
  Widget build(BuildContext context) {
    final data = item.values, draft = calculatorMap(item.values['draftInput']);
    final product = calculatorMap(draft['product']);
    final rule = area == ManagementArea.fertilizer
        ? calculatorMap(draft['rule'])
        : draft;
    final info = calculatorMap(draft['information']);
    final source = calculatorMap(
      area == ManagementArea.fertilizers ? info['source'] : rule['source'],
    );
    final isProduct = area == ManagementArea.fertilizers,
        specification = area == ManagementArea.modelSpecifications;
    final frozen = isProduct && data['contentEditable'] == false;
    String value(Object? raw) =>
        raw == null || raw == '' ? 'Unavailable' : '$raw';
    return Card(
      key: ValueKey('calculator-${item.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminContentStatus(item.status),
            const SizedBox(height: AppSpacing.md),
            Text(item.title, style: Theme.of(context).textTheme.titleLarge),
            SelectableText(
              '${isProduct
                  ? value(product['slug'])
                  : specification
                  ? value(draft['modelKey'])
                  : value(data['ruleKey'] ?? data['configKey'])} · version ${item.version}',
            ),
            if (isProduct || area == ManagementArea.fertilizer) ...[
              if (!isProduct)
                Text(
                  'Product snapshot · ${value(product['name'] ?? calculatorMap(data['product'])['name'])}',
                ),
              Text(
                'N ${value(product['nitrogenPercent'])}% · P₂O₅ ${value(product['phosphorusPercent'])}% · K₂O ${value(product['potassiumPercent'])}% by mass',
                semanticsLabel:
                    'Composition, percent by mass. Nitrogen ${value(product['nitrogenPercent'])}; phosphate P2O5 ${value(product['phosphorusPercent'])}; potash K2O ${value(product['potassiumPercent'])}. Not application rates.',
              ),
              if (isProduct)
                const Text(
                  'Composition information · not a dosage recommendation.',
                ),
            ],
            if (!isProduct && !specification) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${value(rule[area == ManagementArea.fertilizer ? 'rateKgPerHectare' : 'expectedYieldKgPerHectare'])} kg/ha',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                area == ManagementArea.fertilizer
                    ? 'Reviewed product application rate'
                    : 'Reviewed reference yield · planning only',
              ),
              Text('Applicability · ${value(rule['applicability'])}'),
              if (rule['assumptions'] case final List assumptions)
                for (final assumption in assumptions) Text('• $assumption'),
              Text(
                'Output precision · ${value((area == ManagementArea.fertilizer ? calculatorMap(draft['config']) : draft)['quantityDecimalPlaces'])} decimal places',
              ),
            ],
            if (specification) ...[
              Text('Domain approval · ${value(data['domainApproval'])}'),
              Text('Execution · ${value(data['execution'])}'),
              const Text(
                'Source intake only. No execution or activation is available.',
              ),
            ],
            if (source.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Source · ${value(source['title'])}\nPublisher · ${value(source['publisher'])}',
              ),
              SelectableText(value(source['url'])),
            ] else
              const Text(
                'Source information unavailable in this stored record.',
              ),
            if (data['revision'] case final String revision)
              ExpansionTile(
                key: PageStorageKey('record-revision-${item.id}'),
                title: const Text('Record revision'),
                children: [
                  SelectableText(
                    'Revision · $revision',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            if (frozen)
              const Text(
                'Frozen product: referenced by calculator rules. Copy to a new slug to revise content; existing snapshots are retained.',
              ),
            if (!specification)
              Text(
                item.ready
                    ? 'Server reports activation eligibility; policy is checked again when requested.'
                    : 'Not currently eligible for activation. Review source and configuration requirements.',
              ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                TextButton.icon(
                  onPressed: busy || frozen ? null : onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(
                    isProduct
                        ? 'Edit product metadata'
                        : 'New version from this',
                  ),
                ),
                if (isProduct)
                  OutlinedButton(
                    onPressed: busy ? null : onCopy,
                    child: const Text('Copy product to a new slug'),
                  ),
                if (!specification && item.status != 'ACTIVE')
                  TextButton(
                    onPressed: busy || !item.ready
                        ? null
                        : () => onStatus('ACTIVE'),
                    child: const Text('Activate'),
                  ),
                if (!specification && item.status == 'ACTIVE')
                  TextButton(
                    onPressed: busy ? null : () => onStatus('INACTIVE'),
                    child: const Text('Deactivate'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
