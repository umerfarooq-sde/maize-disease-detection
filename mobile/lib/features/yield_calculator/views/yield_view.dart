import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_states.dart';
import '../../../data/models/yield_models.dart';
import '../../tools/widgets/calculator_inputs.dart';
import '../view_models/yield_view_model.dart';
import '../widgets/yield_details.dart';

class YieldView extends StatefulWidget {
  const YieldView({super.key});
  @override
  State<YieldView> createState() => _YieldViewState();
}

class _YieldViewState extends State<YieldView> {
  final _area = TextEditingController();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final value = context.read<YieldViewModel>().area;
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
    final model = context.watch<YieldViewModel>();
    final catalogue = model.catalogue;
    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Expected yield',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Plan from your cultivated area and a reviewed yield scenario. Actual harvest may differ.',
          ),
          const SizedBox(height: AppSpacing.lg),
          if (model.loading)
            const AppLoadingState(
              message: 'Checking reviewed yield configurations…',
            )
          else if (model.error case final error?)
            AppErrorState(error: error, onRetry: model.load)
          else if (catalogue?.status ==
              YieldCatalogueStatus.pendingConfiguration)
            Card(
              color: AppColors.wheat,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Yield configuration pending',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'An authoritative maize yield model and applicable rates have not been approved. '
                      'No expected yield is generated until a reviewed configuration is published.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: model.load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Check again'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
          CalculatorInputs<YieldMassUnit>(
            controller: _area,
            busy: model.submitting,
            areaError: model.areaError,
            areaUnit: model.areaUnit,
            outputUnit: model.outputUnit,
            onAreaChanged: model.setArea,
            onAreaUnitChanged: model.selectAreaUnit,
            onOutputUnitChanged: model.selectOutputUnit,
            outputUnits: YieldMassUnit.values,
            outputUnitLabel: (unit) => unit.description,
            keyPrefix: 'yield',
            description:
                'Crop: maize. Enter the cultivated area covered by the reviewed scenario.',
          ),
          if (catalogue != null && catalogue.items.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            KeyedSubtree(
              key: const Key('yield-configuration'),
              child: DropdownButtonFormField<String>(
                key: ValueKey(model.selected?.id),
                initialValue: model.selected?.id,
                decoration: const InputDecoration(
                  labelText: 'Reviewed yield scenario',
                ),
                hint: const Text('Choose a configuration'),
                isExpanded: true,
                itemHeight: null,
                items: [
                  for (final configuration in catalogue.items)
                    DropdownMenuItem(
                      value: configuration.id,
                      child: Text(configuration.title),
                    ),
                ],
                onChanged: model.submitting ? null : model.selectConfiguration,
              ),
            ),
          ],
          if (model.selected case final configuration?
              when model.result == null) ...[
            const SizedBox(height: AppSpacing.lg),
            YieldConfigurationDetails(configuration: configuration),
          ],
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            key: const Key('yield-calculate'),
            onPressed: model.canCalculate ? model.calculate : null,
            icon: const Icon(Icons.bar_chart_outlined),
            label: const Text('Calculate expected yield'),
          ),
          if (model.submitting)
            const AppLoadingState(
              message: 'Calculating your planning estimate…',
            ),
          if (model.calculationError case final error?) ...[
            const SizedBox(height: AppSpacing.lg),
            if (model.needsRefresh) ...[
              const Text(
                'The configuration changed. Refresh the choices, review the conditions, then calculate again.',
              ),
              OutlinedButton(
                onPressed: model.retry,
                child: const Text('Refresh configurations'),
              ),
            ] else if (model.canRetry)
              AppErrorState(error: error, onRetry: model.retry)
            else
              AppEmptyState(
                title: 'Check the calculation inputs',
                message: error.message,
              ),
          ],
          if (model.result case final result?) ...[
            const SizedBox(height: AppSpacing.xl),
            YieldResultCard(result: result),
          ],
        ],
      ),
    );
  }
}
