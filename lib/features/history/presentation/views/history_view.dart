import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/domain/entities/enums.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/view_state_builder.dart';
import '../../domain/entities/history_entities.dart';
import '../cubits/history_cubits.dart';

class HistoryView extends StatelessWidget {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: ViewStateBuilder<HistoryCubit, HistoryData>(
        onRetry: (cubit) => cubit.start(),
        builder: (context, data) {
          if (data.totalSessions == 0) {
            return const EmptyState(
              icon: Icons.history,
              title: 'No workouts yet',
              message: 'Completed workouts will appear here.',
            );
          }
          return Column(
            children: [
              _FilterBar(data: data),
              Expanded(
                child: data.items.isEmpty
                    ? const EmptyState(
                        icon: Icons.filter_alt_off_outlined,
                        title: 'No workouts match these filters',
                      )
                    : PageBody(
                        children: [
                          for (final item in data.items) ...[
                            _HistoryTile(item: item),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.data});

  final HistoryData data;

  Future<void> _pickMuscle(BuildContext context) async {
    final cubit = context.read<HistoryCubit>();
    final muscle = await showModalBottomSheet<MuscleGroup?>(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          for (final m in MuscleGroup.values)
            ListTile(
              title: Text(m.label),
              onTap: () => Navigator.pop(context, m),
            ),
        ],
      ),
    );
    if (muscle != null) {
      cubit.applyFilter(cubit.filter.copyWith(muscle: () => muscle));
    }
  }

  Future<void> _pickExercise(BuildContext context) async {
    final cubit = context.read<HistoryCubit>();
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          for (final option in data.exerciseOptions)
            ListTile(
              title: Text(option.name),
              onTap: () => Navigator.pop(context, option.id),
            ),
        ],
      ),
    );
    if (id != null) {
      cubit.applyFilter(cubit.filter.copyWith(exerciseId: () => id));
    }
  }

  Future<void> _pickDates(BuildContext context) async {
    final cubit = context.read<HistoryCubit>();
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (range != null) {
      cubit.applyFilter(
        cubit.filter.copyWith(from: () => range.start, to: () => range.end),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HistoryCubit>();
    final filter = data.filter;
    final exerciseName = data.exerciseOptions
        .where((o) => o.id == filter.exerciseId)
        .map((o) => o.name)
        .firstOrNull;
    return SizedBox(
      height: AppSpacing.minTouchTarget + AppSpacing.sm,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.page,
          vertical: AppSpacing.xs,
        ),
        children: [
          FilterChip(
            label: const Text('All'),
            selected: filter.isEmpty,
            onSelected: (_) => cubit.applyFilter(const HistoryFilter()),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilterChip(
            label: Text(filter.muscle?.label ?? 'Muscle'),
            selected: filter.muscle != null,
            onSelected: (_) => filter.muscle != null
                ? cubit.applyFilter(filter.copyWith(muscle: () => null))
                : _pickMuscle(context),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilterChip(
            label: Text(exerciseName ?? 'Exercise'),
            selected: filter.exerciseId != null,
            onSelected: (_) => filter.exerciseId != null
                ? cubit.applyFilter(filter.copyWith(exerciseId: () => null))
                : _pickExercise(context),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilterChip(
            label: Text(
              filter.from == null
                  ? 'Dates'
                  : '${Formatters.shortDate(filter.from!)} – '
                        '${Formatters.shortDate(filter.to!)}',
            ),
            selected: filter.from != null,
            onSelected: (_) => filter.from != null
                ? cubit.applyFilter(
                    filter.copyWith(from: () => null, to: () => null),
                  )
                : _pickDates(context),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item});

  final HistoryItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: () => context.push(RoutePaths.historySession(item.sessionId)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.workoutName,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Text(
                Formatters.shortDate(item.date),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '${item.workingSets} sets · ${Formatters.duration(item.duration)} · '
            '${item.muscles.map((m) => m.label).join(', ')}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
