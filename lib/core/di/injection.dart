import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

import '../../features/body_weight/data/repositories/body_weight_repository_impl.dart';
import '../../features/body_weight/domain/repositories/body_weight_repository.dart';
import '../../features/body_weight/domain/usecases/body_weight_use_cases.dart';
import '../../features/body_weight/presentation/cubits/body_weight_cubit.dart';
import '../../features/daily_goals/data/repositories/daily_goal_repository_impl.dart';
import '../../features/daily_goals/domain/repositories/daily_goal_repository.dart';
import '../../features/daily_goals/domain/usecases/daily_goal_use_cases.dart';
import '../../features/daily_goals/presentation/cubits/daily_goal_cubits.dart';
import '../../features/exercises/data/repositories/exercise_guide_repository_impl.dart';
import '../../features/exercises/data/repositories/exercise_repository_impl.dart';
import '../../features/exercises/domain/repositories/exercise_guide_repository.dart';
import '../../features/exercises/domain/repositories/exercise_repository.dart';
import '../../features/exercises/domain/usecases/exercise_use_cases.dart';
import '../../features/exercises/presentation/cubits/exercise_cubits.dart';
import '../../features/history/data/repositories/history_repository_impl.dart';
import '../../features/history/domain/repositories/history_repository.dart';
import '../../features/history/domain/usecases/history_use_cases.dart';
import '../../features/history/presentation/cubits/history_cubits.dart';
import '../../features/home/data/repositories/home_repository_impl.dart';
import '../../features/home/domain/repositories/home_repository.dart';
import '../../features/home/domain/usecases/watch_home_dashboard_use_case.dart';
import '../../features/home/presentation/cubits/home_cubit.dart';
import '../../features/onboarding/data/repositories/onboarding_repository_impl.dart';
import '../../features/onboarding/domain/repositories/onboarding_repository.dart';
import '../../features/onboarding/domain/usecases/complete_onboarding_use_case.dart';
import '../../features/onboarding/presentation/cubits/onboarding_cubit.dart';
import '../../features/program/data/repositories/program_repository_impl.dart';
import '../../features/program/domain/repositories/program_repository.dart';
import '../../features/program/domain/usecases/edit_workout_day_use_cases.dart';
import '../../features/program/domain/usecases/watch_weekly_plan_use_case.dart';
import '../../features/program/domain/usecases/watch_workout_overview_use_case.dart';
import '../../features/program/presentation/cubits/plan_cubits.dart';
import '../../features/progress/data/repositories/progress_repository_impl.dart';
import '../../features/progress/domain/repositories/progress_repository.dart';
import '../../features/progress/domain/usecases/progress_use_cases.dart';
import '../../features/progress/presentation/cubits/progress_cubits.dart';
import '../../features/settings/data/repositories/settings_repository_impl.dart';
import '../../features/settings/domain/repositories/settings_repository.dart';
import '../../features/settings/domain/usecases/settings_use_cases.dart';
import '../../features/settings/presentation/cubits/settings_cubit.dart';
import '../../features/startup/data/repositories/startup_repository_impl.dart';
import '../../features/startup/domain/repositories/startup_repository.dart';
import '../../features/startup/domain/usecases/get_startup_status_use_case.dart';
import '../../features/startup/presentation/cubits/splash_cubit.dart';
import '../../features/workout/data/repositories/workout_repository_impl.dart';
import '../../features/workout/domain/repositories/workout_repository.dart';
import '../../features/workout/domain/usecases/get_workout_summary_use_case.dart';
import '../../features/workout/domain/usecases/log_set_use_case.dart';
import '../../features/workout/domain/usecases/rest_timer_use_cases.dart';
import '../../features/workout/domain/usecases/session_actions_use_cases.dart';
import '../../features/workout/domain/usecases/start_workout_use_case.dart';
import '../../features/workout/domain/usecases/watch_active_workout_use_case.dart';
import '../../features/workout/presentation/cubits/active_workout_cubit.dart';
import '../../features/workout/presentation/cubits/rest_timer_cubit.dart';
import '../../features/workout/presentation/cubits/workout_summary_cubit.dart';
import '../domain/repositories/unit_preference_repository.dart';
import '../domain/services/day_change_source.dart';
import '../domain/services/media_store.dart';
import '../domain/services/notification_scheduler.dart';
import '../domain/services/step_counter.dart';
import '../domain/usecases/watch_unit_system_use_case.dart';
import '../presentation/units/units_cubit.dart';
import '../services/app_day_change_source.dart';
import '../services/clock.dart';
import '../services/id_generator.dart';
import '../services/pedometer_step_counter.dart';
import '../storage/hive_storage.dart';
import '../storage/local_data_sources/body_weight_local_data_source.dart';
import '../storage/local_data_sources/daily_goal_local_data_source.dart';
import '../storage/local_data_sources/profile_local_data_source.dart';
import '../storage/local_data_sources/program_local_data_source.dart';
import '../storage/local_data_sources/settings_local_data_source.dart';
import '../storage/local_data_sources/workout_local_data_source.dart';
import '../storage/repositories/unit_preference_repository_impl.dart';

final getIt = GetIt.instance;

/// Single DI setup (CLAUDE.md B6). Singletons: infrastructure, data sources
/// and repositories. Factories: use cases and cubits (route-scoped).
void configureDependencies({
  required HiveStorage storage,
  required NotificationScheduler notifications,
  Clock clock = const Clock(),
  DayChangeSource? dayChanges,
  required MediaStore media,
  StepCounter steps = const PedometerStepCounter(),
}) {
  // Infrastructure
  getIt
    ..registerSingleton<HiveStorage>(storage)
    ..registerSingleton<Clock>(clock)
    ..registerSingleton<IdGenerator>(const IdGenerator())
    ..registerSingleton<NotificationScheduler>(notifications)
    // Lazy: the default implementation needs an initialised WidgetsBinding.
    ..registerLazySingleton<DayChangeSource>(
      () => dayChanges ?? AppDayChangeSource(getIt()),
    )
    ..registerSingleton<MediaStore>(media)
    ..registerSingleton<StepCounter>(steps);

  // Local data sources
  getIt
    ..registerLazySingleton(() => ProgramLocalDataSource(getIt()))
    ..registerLazySingleton(() => WorkoutLocalDataSource(getIt(), getIt()))
    ..registerLazySingleton(() => ProfileLocalDataSource(getIt()))
    ..registerLazySingleton(() => BodyWeightLocalDataSource(getIt()))
    ..registerLazySingleton(() => SettingsLocalDataSource(getIt()))
    ..registerLazySingleton(() => DailyGoalLocalDataSource(getIt()));

  // Repositories
  getIt
    ..registerLazySingleton<UnitPreferenceRepository>(
      () => UnitPreferenceRepositoryImpl(getIt()),
    )
    ..registerLazySingleton<ExerciseRepository>(
      () => ExerciseRepositoryImpl(getIt(), getIt()),
    )
    ..registerLazySingleton<ExerciseGuideRepository>(
      () => ExerciseGuideRepositoryImpl(rootBundle.loadString),
    )
    ..registerLazySingleton<StartupRepository>(
      () => StartupRepositoryImpl(getIt(), getIt()),
    )
    ..registerLazySingleton<OnboardingRepository>(
      () => OnboardingRepositoryImpl(getIt(), getIt(), getIt()),
    )
    ..registerLazySingleton<HomeRepository>(
      () => HomeRepositoryImpl(getIt(), getIt(), getIt(), getIt()),
    )
    ..registerLazySingleton<ProgramRepository>(
      () => ProgramRepositoryImpl(getIt(), getIt()),
    )
    ..registerLazySingleton<WorkoutRepository>(
      () => WorkoutRepositoryImpl(getIt(), getIt(), getIt(), getIt()),
    )
    ..registerLazySingleton<HistoryRepository>(
      () => HistoryRepositoryImpl(getIt()),
    )
    ..registerLazySingleton<ProgressRepository>(
      () => ProgressRepositoryImpl(getIt(), getIt(), getIt()),
    )
    ..registerLazySingleton<DailyGoalRepository>(
      () => DailyGoalRepositoryImpl(getIt()),
    )
    ..registerLazySingleton<BodyWeightRepository>(
      () => BodyWeightRepositoryImpl(getIt()),
    )
    ..registerLazySingleton<SettingsRepository>(
      () => SettingsRepositoryImpl(
        getIt(),
        getIt(),
        getIt(),
        getIt(),
        getIt(),
        getIt(),
      ),
    );

  // Use cases
  getIt
    ..registerFactory(() => GetStartupStatusUseCase(getIt()))
    ..registerFactory(
      () => CompleteOnboardingUseCase(getIt(), getIt(), getIt()),
    )
    ..registerFactory(
      () => WatchHomeDashboardUseCase(getIt(), getIt(), getIt()),
    )
    ..registerFactory(() => WatchWeeklyPlanUseCase(getIt(), getIt(), getIt()))
    ..registerFactory(
      () => WatchWorkoutOverviewUseCase(getIt(), units: getIt()),
    )
    ..registerFactory(() => StartWorkoutUseCase(getIt()))
    ..registerFactory(() => WatchActiveWorkoutUseCase(getIt(), units: getIt()))
    ..registerFactory(() => LogSetUseCase(getIt(), getIt(), getIt()))
    ..registerFactory(() => UndoSetUseCase(getIt()))
    ..registerFactory(() => SkipExerciseUseCase(getIt()))
    ..registerFactory(() => FinishWorkoutUseCase(getIt()))
    ..registerFactory(() => AbandonWorkoutUseCase(getIt()))
    ..registerFactory(() => GetWorkoutSummaryUseCase(getIt()))
    ..registerFactory(() => GetRestTimerSettingsUseCase(getIt()))
    ..registerFactory(() => ScheduleRestAlertUseCase(getIt()))
    ..registerFactory(() => CancelRestAlertUseCase(getIt()))
    ..registerFactory(() => PrepareRestAlertsUseCase(getIt()))
    ..registerFactory(() => WatchHistoryUseCase(getIt()))
    ..registerFactory(() => GetSessionDetailUseCase(getIt()))
    ..registerFactory(
      () => WatchProgressDashboardUseCase(getIt(), getIt(), getIt()),
    )
    ..registerFactory(() => GetExerciseProgressUseCase(getIt()))
    ..registerFactory(() => WatchBodyWeightUseCase(getIt()))
    ..registerFactory(() => AddBodyWeightUseCase(getIt(), getIt(), getIt()))
    ..registerFactory(() => DeleteBodyWeightUseCase(getIt()))
    ..registerFactory(() => WatchSettingsUseCase(getIt(), getIt()))
    ..registerFactory(() => SyncWorkoutRemindersUseCase(getIt(), getIt()))
    ..registerFactory(() => UpdateSettingsUseCase(getIt(), getIt(), getIt()))
    ..registerFactory(() => WatchUnitSystemUseCase(getIt()))
    ..registerFactory(() => WatchExerciseLibraryUseCase(getIt()))
    ..registerFactory(() => WatchExerciseDetailsUseCase(getIt(), getIt()))
    ..registerFactory(() => GetExerciseUseCase(getIt()))
    ..registerFactory(() => SaveExerciseUseCase(getIt(), getIt(), getIt()))
    ..registerFactory(() => ArchiveExerciseUseCase(getIt()))
    ..registerFactory(() => RestoreExerciseUseCase(getIt()))
    ..registerFactory(() => AttachExerciseMediaUseCase(getIt(), getIt()))
    ..registerFactory(() => RemoveExerciseMediaUseCase(getIt(), getIt()))
    ..registerFactory(() => WatchDayEditorUseCase(getIt()))
    ..registerFactory(() => UpdateWorkoutDayUseCase(getIt()))
    ..registerFactory(() => AddExerciseToDayUseCase(getIt(), getIt()))
    ..registerFactory(() => UpdateExerciseConfigUseCase(getIt()))
    ..registerFactory(() => RemoveExerciseFromDayUseCase(getIt()))
    ..registerFactory(() => ReorderDayExercisesUseCase(getIt()))
    ..registerFactory(() => UpdateProfileUseCase(getIt(), getIt()))
    ..registerFactory(
      () => UpdateProfilePhotoUseCase(getIt(), getIt(), getIt()),
    )
    ..registerFactory(
      () => RemoveProfilePhotoUseCase(getIt(), getIt(), getIt()),
    )
    ..registerFactory(() => DeleteAllDataUseCase(getIt(), getIt(), getIt()))
    // One shared instance so reminder syncs are queued, never interleaved.
    ..registerLazySingleton(
      () => SyncGoalRemindersUseCase(getIt(), getIt(), getIt()),
    )
    ..registerFactory(() => WatchTodayStepsUseCase(getIt(), getIt(), getIt()))
    ..registerFactory(
      () => WatchTodayGoalsUseCase(getIt(), getIt(), getIt(), getIt(), getIt()),
    )
    ..registerFactory(() => WatchDailyGoalsUseCase(getIt()))
    ..registerFactory(() => LogGoalProgressUseCase(getIt(), getIt()))
    ..registerFactory(
      () => SaveGoalUseCase(getIt(), getIt(), getIt(), getIt(), getIt()),
    )
    ..registerFactory(() => RemoveGoalUseCase(getIt(), getIt()))
    ..registerFactory(() => StepAccessUseCase(getIt()));

  // Cubits (created per route by BlocProvider; UnitsCubit at the app root)
  getIt
    ..registerFactory(() => UnitsCubit(getIt()))
    ..registerFactory(() => ExerciseLibraryCubit(watchLibrary: getIt()))
    ..registerFactoryParam<ExerciseDetailsCubit, String, String>(
      (exerciseId, languageCode) => ExerciseDetailsCubit(
        exerciseId: exerciseId,
        languageCode: languageCode,
        watchDetails: getIt(),
        attachMedia: getIt(),
        removeMedia: getIt(),
        archive: getIt(),
        restore: getIt(),
      ),
    )
    ..registerFactoryParam<ExerciseEditorCubit, String?, void>(
      (exerciseId, _) => ExerciseEditorCubit(
        exerciseId: exerciseId,
        getExercise: getIt(),
        saveExercise: getIt(),
      ),
    )
    ..registerFactoryParam<WorkoutDayEditorCubit, String, void>(
      (dayId, _) => WorkoutDayEditorCubit(
        dayId: dayId,
        watchDay: getIt(),
        updateDay: getIt(),
        addExercise: getIt(),
        updateConfig: getIt(),
        removeExercise: getIt(),
        reorder: getIt(),
      ),
    )
    ..registerFactory(
      () => SplashCubit(
        getStatus: getIt(),
        abandonWorkout: getIt(),
        syncReminders: getIt(),
        syncWorkoutReminders: getIt(),
      ),
    )
    ..registerFactory(
      () => OnboardingCubit(completeOnboarding: getIt(), clock: getIt()),
    )
    ..registerFactory(
      () => HomeCubit(
        watchDashboard: getIt(),
        startWorkout: getIt(),
        addBodyWeight: getIt(),
      ),
    )
    ..registerFactory(
      () => TodayGoalsCubit(
        watchToday: getIt(),
        logProgress: getIt(),
        stepAccess: getIt(),
      ),
    )
    ..registerFactory(
      () => DailyGoalsCubit(
        watchGoals: getIt(),
        saveGoal: getIt(),
        removeGoal: getIt(),
      ),
    )
    ..registerFactory(() => PlanCubit(watchPlan: getIt()))
    ..registerFactoryParam<WorkoutOverviewCubit, String, void>(
      (dayId, _) => WorkoutOverviewCubit(
        dayId: dayId,
        watchOverview: getIt(),
        startWorkout: getIt(),
      ),
    )
    ..registerFactoryParam<ActiveWorkoutCubit, String, void>(
      (sessionId, _) => ActiveWorkoutCubit(
        sessionId: sessionId,
        watchWorkout: getIt(),
        logSet: getIt(),
        undoSet: getIt(),
        skipExercise: getIt(),
        finishWorkout: getIt(),
        abandonWorkout: getIt(),
      ),
    )
    ..registerFactory(
      () => RestTimerCubit(
        clock: getIt(),
        getSettings: getIt(),
        scheduleAlert: getIt(),
        cancelAlert: getIt(),
        prepareAlerts: getIt(),
      ),
    )
    ..registerFactoryParam<WorkoutSummaryCubit, String, void>(
      (sessionId, _) =>
          WorkoutSummaryCubit(sessionId: sessionId, getSummary: getIt()),
    )
    ..registerFactory(() => HistoryCubit(watchHistory: getIt()))
    ..registerFactoryParam<SessionDetailCubit, String, void>(
      (sessionId, _) =>
          SessionDetailCubit(sessionId: sessionId, getDetail: getIt()),
    )
    ..registerFactory(() => ProgressCubit(watchDashboard: getIt()))
    ..registerFactoryParam<ExerciseProgressCubit, String, void>(
      (exerciseId, _) =>
          ExerciseProgressCubit(exerciseId: exerciseId, getProgress: getIt()),
    )
    ..registerFactory(
      () => BodyWeightCubit(watch: getIt(), add: getIt(), delete: getIt()),
    )
    ..registerFactory(
      () => SettingsCubit(
        watchSettings: getIt(),
        updateSettings: getIt(),
        updateProfile: getIt(),
        updatePhoto: getIt(),
        removePhoto: getIt(),
        deleteAllData: getIt(),
        syncGoalReminders: getIt(),
      ),
    );
}

Future<void> resetDependencies() => getIt.reset();
