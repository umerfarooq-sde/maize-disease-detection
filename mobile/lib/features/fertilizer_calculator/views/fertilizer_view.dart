import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_states.dart';
import '../view_models/fertilizer_view_model.dart';
import '../widgets/fertilizer_inputs.dart';
import '../widgets/fertilizer_calculation_error.dart';
import '../widgets/fertilizer_pending_rules.dart';
import '../widgets/fertilizer_result_card.dart';
import '../widgets/fertilizer_rule_details.dart';

class FertilizerView extends StatefulWidget {
  const FertilizerView({super.key});

  @override
  State<FertilizerView> createState() => _FertilizerViewState();
}

class _FertilizerViewState extends State<FertilizerView> {
  final _area = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final value = context.read<FertilizerViewModel>().area;
    if (_area.text != value) {
      _area.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }

  @override
  void dispose() {
    _area.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<FertilizerViewModel>();
    final catalogue = model.catalogue;
    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Fertilizer planning',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Calculate a product quantity from a published rule and your field area.',
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Use a rule only when its field assumptions apply. Check local agricultural '
            'guidance before applying fertilizer. Uses a fixed calculation; '
            'AI does not set the quantity.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (model.loading)
            const AppLoadingState(message: 'Checking approved rules…')
          else if (model.error case final error?)
            AppErrorState(error: error, onRetry: model.load)
          else if (catalogue != null && catalogue.items.isEmpty)
            FertilizerPendingRules(onReload: model.load),
          const SizedBox(height: AppSpacing.xl),
          FertilizerInputs(
            controller: _area,
            busy: model.submitting,
            areaError: model.areaError,
            areaUnit: model.areaUnit,
            outputUnit: model.outputUnit,
            onAreaChanged: model.setArea,
            onAreaUnitChanged: model.selectAreaUnit,
            onOutputUnitChanged: model.selectOutputUnit,
          ),
          if (catalogue != null && catalogue.items.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            KeyedSubtree(
              key: const Key('fertilizer-rule'),
              child: DropdownButtonFormField<String>(
                key: ValueKey(model.selectedRule?.id),
                initialValue: model.selectedRule?.id,
                decoration: const InputDecoration(labelText: 'Approved rule'),
                hint: const Text('Choose a rule'),
                isExpanded: true,
                itemHeight: null,
                items: [
                  for (final rule in catalogue.items)
                    DropdownMenuItem(value: rule.id, child: Text(rule.title)),
                ],
                onChanged: model.submitting ? null : model.selectRule,
              ),
            ),
          ],
          if (model.selectedRule case final rule?) ...[
            const SizedBox(height: AppSpacing.lg),
            FertilizerRuleDetails(rule: rule),
          ],
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            key: const Key('fertilizer-calculate'),
            onPressed: model.canCalculate ? model.calculate : null,
            icon: const Icon(Icons.calculate_outlined),
            label: Text(
              model.submitting ? 'Calculating…' : 'Calculate quantity',
            ),
          ),
          if (model.submitting) ...[
            const SizedBox(height: AppSpacing.lg),
            const AppLoadingState(
              message: 'Calculating from the selected rule…',
            ),
          ],
          if (model.calculationError case final error?) ...[
            const SizedBox(height: AppSpacing.xl),
            FertilizerCalculationError(
              error: error,
              onRetry:
                  model.canRetryCalculation ||
                      error.kind == AppErrorKind.conflict ||
                      error.kind == AppErrorKind.notFound
                  ? model.retry
                  : null,
            ),
          ],
          if (model.result case final result?) ...[
            const SizedBox(height: AppSpacing.xl),
            FertilizerResultCard(result: result),
          ],
        ],
      ),
    );
  }
}
