import '../../../../core/domain/entities/enums.dart';
import '../../../../core/domain/entities/workout_session.dart';
import '../../../../core/result/api_result.dart';
import '../../../../core/storage/hive_storage.dart';
import '../../../../core/storage/local_data_sources/body_weight_local_data_source.dart';
import '../../../../core/storage/local_data_sources/profile_local_data_source.dart';
import '../../../../core/storage/local_data_sources/program_local_data_source.dart';
import '../../../../core/storage/local_data_sources/workout_index.dart';
import '../../../../core/storage/local_data_sources/workout_local_data_source.dart';
import '../../../../core/storage/storage_guard.dart';
import '../../domain/entities/home_dashboard.dart';
import '../../domain/repositories/home_repository.dart';

class HomeRepositoryImpl implements HomeRepository {
  const HomeRepositoryImpl(
    this._profile,
    this._programs,
    this._workouts,
    this._weights,
  );

  static const _recentSessionLimit = 14;

  final ProfileLocalDataSource _profile;
  final ProgramLocalDataSource _programs;
  final WorkoutLocalDataSource _workouts;
  final BodyWeightLocalDataSource _weights;

  @override
  Stream<ApiResult<HomeData>> watchHomeData() => guardStream(
    watchTriggers([
      ..._profile.triggers,
      ..._programs.triggers,
      ..._workouts.triggers,
      ..._weights.triggers,
    ], _load),
  );

  HomeData _load() {
    final program = _programs.requireActiveProgram();
    final days = _programs.days(program.id);
    final configs = {
      for (final d in days) d.id: _programs.programExercisesForDay(d.id),
    };
    final completed = _workouts.sessions(status: SessionStatus.completed);
    final index = _workouts.snapshot();
    return HomeData(
      profile: _profile.profile(),
      program: program,
      days: days,
      plannedSetsPerDay: {
        for (final e in configs.entries)
          e.key: e.value.fold(0, (sum, c) => sum + c.workingSets),
      },
      exerciseCountPerDay: {
        for (final e in configs.entries) e.key: e.value.length,
      },
      completedSessions: completed,
      // The dashboard only looks at the current week; cap the list.
      workingSetsPerSession: {
        for (final s in completed.take(_recentSessionLimit))
          s.id: index.setsOf(s.id).where((set) => !set.isWarmup).length,
      },
      weights: _weights.entries(),
      lastSessionExercises: completed.isEmpty
          ? const []
          : _lastSessionPairs(index, completed.first),
      activeSession: _workouts.activeSession(),
    );
  }

  List<ExercisePerformancePair> _lastSessionPairs(
    WorkoutIndex index,
    WorkoutSession last,
  ) {
    final pairs = <ExercisePerformancePair>[];
    for (final exercise in index.exercisesOf(last.id)) {
      final history = index.performances(exercise.exerciseId);
      final at = history.indexWhere((h) => h.sessionId == last.id);
      if (at < 0) continue;
      pairs.add((
        exerciseId: exercise.exerciseId,
        name: exercise.exerciseName,
        current: history[at],
        previous: at + 1 < history.length ? history[at + 1] : null,
      ));
    }
    return pairs;
  }
}
