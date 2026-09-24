import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/constants/app_info.dart';
import '../../../../core/domain/entities/app_settings.dart';
import '../../../../core/domain/entities/enums.dart';
import '../../../../core/domain/entities/user_profile.dart';
import '../../../../core/domain/services/media_store.dart';
import '../../../../core/domain/validation/validators.dart';
import '../../../../core/presentation/action_outcome.dart';
import '../../../../core/presentation/units/unit_format.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/measure_wheel_picker.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/view_state_builder.dart';
import '../../domain/entities/settings_overview.dart';
import '../cubits/settings_cubit.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ViewStateBuilder<SettingsCubit, SettingsOverview>(
        onRetry: (cubit) => cubit.start(),
        builder: (context, overview) => _SettingsBody(overview: overview),
      ),
    );
  }
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody({required this.overview});

  final SettingsOverview overview;

  Future<void> _update(
    BuildContext context,
    AppSettings Function(AppSettings) change,
  ) async {
    final outcome = await context.read<SettingsCubit>().updateSettings(change);
    if (outcome case ActionFailed(:final message) when context.mounted) {
      showMessage(context, message);
    }
  }

  Future<void> _pickReminderTime(BuildContext context) async {
    final minutes = overview.settings.reminderMinutesOfDay;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked != null && context.mounted) {
      await _update(
        context,
        (s) =>
            s.copyWith(reminderMinutesOfDay: picked.hour * 60 + picked.minute),
      );
    }
  }

  Future<void> _editProfile(BuildContext context, UserProfile profile) async {
    final cubit = context.read<SettingsCubit>();
    final edit = await showModalBottomSheet<_ProfileEdit>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EditProfileSheet(profile: profile, age: overview.age),
    );
    if (edit == null) return;
    final outcome = await cubit.updateProfile(edit.profile, age: edit.age);
    if (context.mounted) _report(context, outcome);
  }

  Future<void> _changeUnits(
    BuildContext context,
    UserProfile profile,
    UnitSystem units,
  ) async {
    final cubit = context.read<SettingsCubit>();
    final outcome = await cubit.updateProfile(
      profile.copyWith(unitSystem: units),
    );
    if (context.mounted) _report(context, outcome);
  }

  Future<void> _editPhoto(BuildContext context, UserProfile profile) async {
    final cubit = context.read<SettingsCubit>();
    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(context, _PhotoAction.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, _PhotoAction.gallery),
            ),
            if (profile.photoPath != null)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: context.semanticColors.danger,
                ),
                title: const Text('Remove photo'),
                onTap: () => Navigator.pop(context, _PhotoAction.remove),
              ),
          ],
        ),
      ),
    );
    if (action == null) return;
    final outcome = switch (action) {
      _PhotoAction.camera => await cubit.updatePhoto(
        profile,
        MediaSource.camera,
      ),
      _PhotoAction.gallery => await cubit.updatePhoto(
        profile,
        MediaSource.gallery,
      ),
      _PhotoAction.remove => await cubit.removePhoto(profile),
    };
    if (context.mounted) _report(context, outcome);
  }

  void _report(BuildContext context, ActionOutcome<void> outcome) {
    if (outcome case ActionFailed(:final message)) {
      showMessage(context, message);
    }
  }

  Future<void> _deleteAll(BuildContext context) async {
    final cubit = context.read<SettingsCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all local data?'),
        content: const Text(
          'Your profile, workouts, sets and body-weight logs will be '
          'permanently deleted from this device. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: context.semanticColors.danger,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final outcome = await cubit.deleteAllData();
    if (!context.mounted) return;
    switch (outcome) {
      case ActionDone():
        context.go(RoutePaths.onboarding);
      case ActionFailed(:final message):
        showMessage(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = overview.settings;
    final profile = overview.profile;
    return PageBody(
      children: [
        if (profile != null)
          AppCard(
            onTap: () => _editProfile(context, profile),
            child: Row(
              children: [
                ProfileAvatar(
                  profile: profile,
                  photoFile: overview.photoFile,
                  onTap: () => _editPhoto(context, profile),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile.name, style: theme.textTheme.titleMedium),
                      Text(
                        [
                          context.units.height(profile.heightCm),
                          if (overview.age case final age?) '$age years',
                          profile.goal.label,
                          'since '
                              '${Formatters.shortDate(profile.trainingStartDate)}',
                        ].join(' · '),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.edit_outlined),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        const SectionLabel('Rest timer'),
        SwitchListTile(
          title: const Text('Start automatically after a set'),
          value: settings.autoStartRestTimer,
          onChanged: (v) =>
              _update(context, (s) => s.copyWith(autoStartRestTimer: v)),
        ),
        SwitchListTile(
          title: const Text('Alert when rest is over'),
          subtitle: const Text(
            'Notification while the app is in the background',
          ),
          value: settings.restAlertsEnabled,
          onChanged: (v) =>
              _update(context, (s) => s.copyWith(restAlertsEnabled: v)),
        ),
        SwitchListTile(
          title: const Text('Sound'),
          value: settings.soundEnabled,
          onChanged: (v) =>
              _update(context, (s) => s.copyWith(soundEnabled: v)),
        ),
        SwitchListTile(
          title: const Text('Vibration'),
          value: settings.vibrationEnabled,
          onChanged: (v) =>
              _update(context, (s) => s.copyWith(vibrationEnabled: v)),
        ),
        const SizedBox(height: AppSpacing.md),
        const SectionLabel('Notifications'),
        SwitchListTile(
          title: const Text('Workout reminders'),
          subtitle: const Text('On scheduled training days'),
          value: settings.remindersEnabled,
          onChanged: (v) =>
              _update(context, (s) => s.copyWith(remindersEnabled: v)),
        ),
        ListTile(
          enabled: settings.remindersEnabled,
          title: const Text('Reminder time'),
          trailing: Text(Formatters.timeOfDay(settings.reminderMinutesOfDay)),
          onTap: () => _pickReminderTime(context),
        ),
        const SizedBox(height: AppSpacing.md),
        const SectionLabel('General'),
        if (profile != null)
          ListTile(
            title: const Text('Units'),
            trailing: UnitSystemToggle(
              value: profile.unitSystem,
              onChanged: (u) => _changeUnits(context, profile, u),
            ),
          ),
        ListTile(
          title: const Text('Body weight log'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(RoutePaths.bodyWeight),
        ),
        ListTile(
          title: const Text('Workout history'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(RoutePaths.history),
        ),
        const SizedBox(height: AppSpacing.md),
        const SectionLabel('Data'),
        ListTile(
          title: Text(
            'Delete local data',
            style: TextStyle(color: context.semanticColors.danger),
          ),
          subtitle: const Text('Removes everything stored on this device'),
          onTap: () => _deleteAll(context),
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Text(
            '${AppInfo.name} v${AppInfo.version}',
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

enum _PhotoAction { camera, gallery, remove }

/// Circular profile photo, or the name's initial when there is none. Shows
/// a small camera badge and opens the photo menu on tap.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.profile,
    this.photoFile,
    this.onTap,
  });

  final UserProfile profile;

  /// Resolved absolute path of the photo, if there is one.
  final String? photoFile;
  final VoidCallback? onTap;

  static const radius = 28.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final path = photoFile;
    final initial = profile.name.isEmpty
        ? '?'
        : profile.name.characters.first.toUpperCase();
    return Semantics(
      button: onTap != null,
      label: 'Profile photo. Tap to change.',
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: radius,
              backgroundColor: theme.colorScheme.primary,
              // Decode at display size, not the full photo resolution.
              foregroundImage: path == null
                  ? null
                  : ResizeImage(
                      FileImage(File(path)),
                      width: (radius * 2 * 3).round(),
                    ),
              // A missing or unreadable file falls back to the initial.
              onForegroundImageError: path == null ? null : (_, _) {},
              child: Text(
                initial,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
            PositionedDirectional(
              end: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.photo_camera,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [age] is `null` when the user never set one and left the wheel alone,
/// so no birth year is invented.
typedef _ProfileEdit = ({UserProfile profile, int? age});

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.profile, this.age});

  final UserProfile profile;

  /// Current age, or `null` when never entered.
  final int? age;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _name;
  late double _heightCm;

  /// Starts inside the allowed range, so an age that drifted past the
  /// maximum never blocks saving other changes.
  late int _age;
  bool _ageChosen = false;
  late TrainingGoal _goal;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.name);
    _heightCm = widget.profile.heightCm;
    _age = (widget.age ?? AgePicker.defaultAge).clamp(
      Validators.minAge,
      Validators.maxAge,
    );
    _ageChosen = widget.age != null;
    _goal = widget.profile.goal;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.pop<_ProfileEdit>(context, (
      profile: widget.profile.copyWith(
        name: _name.text.trim(),
        heightCm: _heightCm,
        goal: _goal,
      ),
      age: _ageChosen ? _age : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('Edit profile', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _name,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: AppSpacing.sm),
          HeightPicker(
            heightCm: _heightCm,
            system: widget.profile.unitSystem,
            onChanged: (cm) => setState(() => _heightCm = cm),
          ),
          const SizedBox(height: AppSpacing.sm),
          AgePicker(
            age: _age,
            isSet: _ageChosen,
            onConfirm: () => setState(() => _ageChosen = true),
            onChanged: (a) => setState(() {
              _age = a;
              _ageChosen = true;
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<TrainingGoal>(
            initialValue: _goal,
            decoration: const InputDecoration(labelText: 'Goal'),
            items: [
              for (final goal in TrainingGoal.values)
                DropdownMenuItem(value: goal, child: Text(goal.label)),
            ],
            onChanged: (g) => setState(() => _goal = g ?? _goal),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: _save, child: const Text('Save')),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
