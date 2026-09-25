import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/domain/entities/enums.dart';
import '../../../../core/domain/entities/program.dart';
import '../../../../core/domain/validation/validators.dart';
import '../../../../core/l10n/enum_labels.dart';
import '../../../../core/l10n/seed_names.dart';
import '../../../../core/presentation/action_outcome.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/view_state_builder.dart';
import '../../domain/entities/exercise_input.dart';
import '../cubits/exercise_cubits.dart';

/// Create a custom exercise or edit an existing one. Pops with the saved
/// exercise's ID.
class ExerciseEditorView extends StatelessWidget {
  const ExerciseEditorView({super.key});

  @override
  Widget build(BuildContext context) {
    final isNew = context.read<ExerciseEditorCubit>().exerciseId == null;
    return Scaffold(
      appBar: AppBar(
        title: Text((isNew ? 'exercise.newExercise' : 'exercise.edit').tr()),
      ),
      body: ViewStateBuilder<ExerciseEditorCubit, Exercise?>(
        onRetry: (cubit) => cubit.load(),
        builder: (context, exercise) => _EditorForm(existing: exercise),
      ),
    );
  }
}

class _EditorForm extends StatefulWidget {
  const _EditorForm({required this.existing});

  final Exercise? existing;

  @override
  State<_EditorForm> createState() => _EditorFormState();
}

class _EditorFormState extends State<_EditorForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _instructions;
  late MuscleGroup _primary;
  late Set<MuscleGroup> _secondary;
  late ExerciseCategory _category;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    // A built-in name is edited in the current language.
    _name = TextEditingController(text: e == null ? '' : seedName(e.name));
    _instructions = TextEditingController(text: e?.instructions ?? '');
    _primary = e?.primaryMuscle ?? MuscleGroup.chest;
    _secondary = {...?e?.secondaryMuscles};
    _category = e?.category ?? ExerciseCategory.compound;
  }

  @override
  void dispose() {
    _name.dispose();
    _instructions.dispose();
    super.dispose();
  }

  /// An unchanged translated built-in name keeps its stored name, so it
  /// stays translated in every language.
  String _storedName() {
    final existing = widget.existing;
    if (existing != null && _name.text.trim() == seedName(existing.name)) {
      return existing.name;
    }
    return _name.text;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final outcome = await context.read<ExerciseEditorCubit>().save(
      ExerciseInput(
        name: _storedName(),
        primaryMuscle: _primary,
        secondaryMuscles: [
          for (final m in MuscleGroup.values)
            if (_secondary.contains(m)) m,
        ],
        category: _category,
        instructions: _instructions.text,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    switch (outcome) {
      case ActionDone(:final value):
        context.pop(value);
      case ActionFailed(:final message):
        showMessage(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: PageBody(
        eager: true,
        children: [
          TextFormField(
            controller: _name,
            maxLength: Validators.maxExerciseName,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: 'exercise.name'.tr()),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'exercise.enterName'.tr() : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          SectionLabel('exercise.type'.tr()),
          SegmentedButton<ExerciseCategory>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: ExerciseCategory.compound,
                label: Text('exercise.compoundShort'.tr()),
              ),
              ButtonSegment(
                value: ExerciseCategory.isolation,
                label: Text('exercise.isolationShort'.tr()),
              ),
            ],
            selected: {_category},
            onSelectionChanged: (s) => setState(() => _category = s.first),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<MuscleGroup>(
            initialValue: _primary,
            decoration: InputDecoration(labelText: 'exercise.mainMuscle'.tr()),
            items: [
              for (final m in MuscleGroup.values)
                DropdownMenuItem(value: m, child: Text(m.label)),
            ],
            onChanged: (m) => setState(() {
              _primary = m ?? _primary;
              _secondary.remove(_primary);
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          SectionLabel('exercise.alsoWorks'.tr()),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final m in MuscleGroup.values)
                if (m != _primary)
                  FilterChip(
                    label: Text(m.label),
                    selected: _secondary.contains(m),
                    onSelected: (on) => setState(
                      () => on ? _secondary.add(m) : _secondary.remove(m),
                    ),
                  ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _instructions,
            minLines: 3,
            maxLines: 8,
            maxLength: Validators.maxNotes,
            decoration: InputDecoration(
              labelText: 'exercise.howTo'.tr(),
              alignLabelWithHint: true,
              hintText: 'exercise.howToHint'.tr(),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'exercise.mediaAfterSave'.tr(),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text('common.save'.tr()),
          ),
        ],
      ),
    );
  }
}
