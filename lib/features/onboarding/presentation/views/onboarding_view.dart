import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/domain/entities/enums.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/measure_wheel_picker.dart';
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
  TrainingGoal _goal = TrainingGoal.gainMuscle;
  UnitSystem _units = UnitSystem.metric;
  // Wheels start on typical values but count as "not set" until the user
  // scrolls or confirms them, so a default is never saved by accident.
  double _heightCm = 170;
  double _weightKg = 70;
  int _age = AgePicker.defaultAge;
  bool _heightSet = false;
  bool _weightSet = false;
  bool _ageSet = false;
  bool _showMissing = false;
  late DateTime _startDate;

  @override
  void initState() {
    super.initState();
    _startDate = context.read<OnboardingCubit>().today;
    _name = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

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

  bool get _measurementsSet => _heightSet && _weightSet && _ageSet;

  String? _missing(bool isSet, String what) =>
      _showMissing && !isSet ? 'Choose your $what' : null;

  void _submit() {
    final formValid = _formKey.currentState!.validate();
    if (!_measurementsSet) setState(() => _showMissing = true);
    if (!formValid || !_measurementsSet) return;
    FocusScope.of(context).unfocus();
    context.read<OnboardingCubit>().submit(
      OnboardingInput(
        name: _name.text,
        heightCm: _heightCm,
        weightKg: _weightKg,
        age: _age,
        goal: _goal,
        trainingStartDate: _startDate,
        unitSystem: _units,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              eager: true,
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
                Text('Units', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                UnitSystemToggle(
                  value: _units,
                  onChanged: (u) => setState(() => _units = u),
                ),
                const SizedBox(height: AppSpacing.md),
                HeightPicker(
                  heightCm: _heightCm,
                  system: _units,
                  isSet: _heightSet,
                  errorText: _missing(_heightSet, 'height'),
                  onConfirm: () => setState(() => _heightSet = true),
                  onChanged: (cm) => setState(() {
                    _heightCm = cm;
                    _heightSet = true;
                  }),
                ),
                const SizedBox(height: AppSpacing.sm),
                BodyWeightPicker(
                  weightKg: _weightKg,
                  system: _units,
                  isSet: _weightSet,
                  errorText: _missing(_weightSet, 'weight'),
                  onConfirm: () => setState(() => _weightSet = true),
                  onChanged: (kg) => setState(() {
                    _weightKg = kg;
                    _weightSet = true;
                  }),
                ),
                const SizedBox(height: AppSpacing.sm),
                AgePicker(
                  age: _age,
                  isSet: _ageSet,
                  errorText: _missing(_ageSet, 'age'),
                  onConfirm: () => setState(() => _ageSet = true),
                  onChanged: (age) => setState(() {
                    _age = age;
                    _ageSet = true;
                  }),
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
