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
import '../../../../core/presentation/action_outcome.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
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
    final updated = await showDialog<UserProfile>(
      context: context,
      builder: (_) => _EditProfileDialog(profile: profile),
    );
    if (updated == null) return;
    final outcome = await cubit.updateProfile(updated);
    if (outcome case ActionFailed(:final message) when context.mounted) {
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
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primary,
                  child: Text(
                    profile.name.characters.first.toUpperCase(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile.name, style: theme.textTheme.titleMedium),
                      Text(
                        '${Formatters.weight(profile.heightCm)} cm · '
                        '${profile.goal.label} · since '
                        '${Formatters.shortDate(profile.trainingStartDate)}',
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
        const ListTile(title: Text('Units'), trailing: Text('kg · cm')),
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

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({required this.profile});

  final UserProfile profile;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _name;
  late final TextEditingController _height;
  late TrainingGoal _goal;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.name);
    _height = TextEditingController(
      text: Formatters.weight(widget.profile.heightCm),
    );
    _goal = widget.profile.goal;
  }

  @override
  void dispose() {
    _name.dispose();
    _height.dispose();
    super.dispose();
  }

  void _save() {
    final height = double.tryParse(_height.text.replaceAll(',', '.'));
    Navigator.pop(
      context,
      widget.profile.copyWith(
        name: _name.text.trim(),
        heightCm: height ?? widget.profile.heightCm,
        goal: _goal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              maxLength: 40,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _height,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Height',
                suffixText: 'cm',
              ),
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
