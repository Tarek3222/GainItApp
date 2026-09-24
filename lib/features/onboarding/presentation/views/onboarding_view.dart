import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/domain/entities/enums.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/onboarding_input.dart';
import '../cubits/onboarding_cubit.dart';

/// First-launch profile form. No login (spec §4.A).
class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  TrainingGoal _goal = TrainingGoal.gainMuscle;
  late DateTime _startDate;

  @override
  void initState() {
    super.initState();
    _startDate = context.read<OnboardingCubit>().today;
    _name = TextEditingController();
    _height = TextEditingController();
    _weight = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  static double? _parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  String? _requiredNumber(String? value) =>
      _parse(value ?? '') == null ? 'Enter a number' : null;

  Future<void> _pickStartDate() async {
    final now = context.read<OnboardingCubit>().today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    context.read<OnboardingCubit>().submit(
      OnboardingInput(
        name: _name.text,
        heightCm: _parse(_height.text)!,
        weightKg: _parse(_weight.text)!,
        goal: _goal,
        trainingStartDate: _startDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decimal = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    return BlocListener<OnboardingCubit, OnboardingState>(
      listener: (context, state) {
        switch (state) {
          case OnboardingSuccess():
            context.go(RoutePaths.home);
          case OnboardingFailure(:final message):
            showMessage(context, message);
          default:
            break;
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: PageBody(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(
                  'Welcome to GainIt',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'A few details to personalise your training. '
                  'Everything stays on this device.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  maxLength: 40,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Enter your name' : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _height,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: decimal,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Height',
                          suffixText: 'cm',
                        ),
                        validator: _requiredNumber,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextFormField(
                        controller: _weight,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: decimal,
                        decoration: const InputDecoration(
                          labelText: 'Weight',
                          suffixText: 'kg',
                        ),
                        validator: _requiredNumber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Goal', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<TrainingGoal>(
                  segments: [
                    for (final goal in TrainingGoal.values)
                      ButtonSegment(value: goal, label: Text(goal.label)),
                  ],
                  selected: {_goal},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _goal = s.first),
                ),
                const SizedBox(height: AppSpacing.lg),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Training start date'),
                  subtitle: Text(Formatters.fullDate(_startDate)),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: _pickStartDate,
                ),
                const SizedBox(height: AppSpacing.lg),
                BlocBuilder<OnboardingCubit, OnboardingState>(
                  builder: (context, state) => FilledButton(
                    onPressed: state is OnboardingSubmitting ? null : _submit,
                    child: const Text('Start training'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
