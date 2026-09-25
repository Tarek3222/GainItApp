import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../features/body_weight/presentation/cubits/body_weight_cubit.dart';
import '../../features/body_weight/presentation/views/body_weight_view.dart';
import '../../features/daily_goals/presentation/cubits/daily_goal_cubits.dart';
import '../../features/daily_goals/presentation/views/daily_goals_view.dart';
import '../../features/exercises/presentation/cubits/exercise_cubits.dart';
import '../../features/exercises/presentation/views/exercise_detail_view.dart';
import '../../features/exercises/presentation/views/exercise_editor_view.dart';
import '../../features/exercises/presentation/views/exercise_library_view.dart';
import '../../features/history/presentation/cubits/history_cubits.dart';
import '../../features/history/presentation/views/history_view.dart';
import '../../features/history/presentation/views/session_detail_view.dart';
import '../../features/home/presentation/cubits/home_cubit.dart';
import '../../features/home/presentation/views/home_view.dart';
import '../../features/onboarding/presentation/cubits/onboarding_cubit.dart';
import '../../features/onboarding/presentation/views/onboarding_view.dart';
import '../../features/program/presentation/cubits/plan_cubits.dart';
import '../../features/program/presentation/views/plan_view.dart';
import '../../features/program/presentation/views/workout_day_editor_view.dart';
import '../../features/program/presentation/views/workout_overview_view.dart';
import '../../features/progress/presentation/cubits/progress_cubits.dart';
import '../../features/progress/presentation/views/progress_view.dart';
import '../../features/settings/presentation/cubits/settings_cubit.dart';
import '../../features/settings/presentation/views/settings_view.dart';
import '../../features/startup/presentation/cubits/splash_cubit.dart';
import '../../features/startup/presentation/views/splash_view.dart';
import '../../features/workout/presentation/cubits/active_workout_cubit.dart';
import '../../features/workout/presentation/cubits/rest_timer_cubit.dart';
import '../../features/workout/presentation/cubits/workout_summary_cubit.dart';
import '../../features/workout/presentation/views/active_workout_view.dart';
import '../../features/workout/presentation/views/workout_summary_view.dart';
import 'app_shell.dart';
import 'route_paths.dart';

/// All routes. Cubits are provided at the route (never globally), resolved
/// from get_it with route parameters.
GoRouter createRouter({String initialLocation = RoutePaths.splash}) {
  final rootKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: RoutePaths.splash,
        builder: (_, _) => BlocProvider(
          create: (_) => getIt<SplashCubit>()..check(),
          child: const SplashView(),
        ),
      ),
      GoRoute(
        path: RoutePaths.onboarding,
        builder: (_, _) => BlocProvider(
          create: (_) => getIt<OnboardingCubit>(),
          child: const OnboardingView(),
        ),
      ),
      StatefulShellRoute(
        builder: (_, _, shell) => AppShell(shell: shell),
        navigatorContainerBuilder: (_, shell, children) =>
            FadingBranchContainer(
              currentIndex: shell.currentIndex,
              children: children,
            ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.home,
                builder: (_, _) => MultiBlocProvider(
                  providers: [
                    BlocProvider(create: (_) => getIt<HomeCubit>()..start()),
                    BlocProvider(
                      create: (_) => getIt<TodayGoalsCubit>()..start(),
                    ),
                  ],
                  child: const HomeView(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.plan,
                builder: (_, _) => BlocProvider(
                  create: (_) => getIt<PlanCubit>()..start(),
                  child: const PlanView(),
                ),
                routes: [
                  GoRoute(
                    path: 'day/:dayId',
                    builder: (_, state) => BlocProvider(
                      create: (_) => getIt<WorkoutOverviewCubit>(
                        param1: state.pathParameters['dayId'],
                      )..start(),
                      child: const WorkoutOverviewView(),
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (_, state) => BlocProvider(
                          create: (_) => getIt<WorkoutDayEditorCubit>(
                            param1: state.pathParameters['dayId'],
                          )..start(),
                          child: const WorkoutDayEditorView(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.progress,
                builder: (_, _) => BlocProvider(
                  create: (_) => getIt<ProgressCubit>()..start(),
                  child: const ProgressView(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.settings,
                builder: (_, _) => BlocProvider(
                  create: (_) => getIt<SettingsCubit>()..start(),
                  child: const SettingsView(),
                ),
              ),
            ],
          ),
        ],
      ),
      // Declared before `/workout/:sessionId` so the summary never stacks on
      // top of (and re-opens) the finished workout.
      GoRoute(
        path: '/workout/:sessionId/summary',
        builder: (_, state) => BlocProvider(
          create: (_) => getIt<WorkoutSummaryCubit>(
            param1: state.pathParameters['sessionId'],
          )..load(),
          child: const WorkoutSummaryView(),
        ),
      ),
      GoRoute(
        path: '/workout/:sessionId',
        builder: (_, state) => MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => getIt<ActiveWorkoutCubit>(
                param1: state.pathParameters['sessionId'],
              )..start(),
            ),
            BlocProvider(
              create: (_) => getIt<RestTimerCubit>()..loadSettings(),
            ),
          ],
          child: const ActiveWorkoutView(),
        ),
      ),
      GoRoute(
        path: RoutePaths.history,
        builder: (_, _) => BlocProvider(
          create: (_) => getIt<HistoryCubit>()..start(),
          child: const HistoryView(),
        ),
        routes: [
          GoRoute(
            path: ':sessionId',
            builder: (_, state) => BlocProvider(
              create: (_) => getIt<SessionDetailCubit>(
                param1: state.pathParameters['sessionId'],
              )..load(),
              child: const SessionDetailView(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.exercises,
        builder: (_, state) => BlocProvider(
          create: (_) => getIt<ExerciseLibraryCubit>()..start(),
          child: ExerciseLibraryView(
            pickMode: state.uri.queryParameters['pick'] == 'true',
            alreadyAdded: {
              ...?state.uri.queryParameters['exclude']
                  ?.split(',')
                  .where((id) => id.isNotEmpty),
            },
          ),
        ),
        routes: [
          // Declared before the ID route so "new" is never read as an ID.
          GoRoute(
            path: 'new',
            builder: (_, _) => BlocProvider(
              create: (_) => getIt<ExerciseEditorCubit>(param1: null)..load(),
              child: const ExerciseEditorView(),
            ),
          ),
          GoRoute(
            path: ':exerciseId',
            builder: (context, state) => MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (_) => getIt<ExerciseDetailsCubit>(
                    param1: state.pathParameters['exerciseId'],
                    param2: context.locale.languageCode,
                  )..start(),
                ),
                BlocProvider(
                  create: (_) => getIt<ExerciseProgressCubit>(
                    param1: state.pathParameters['exerciseId'],
                  )..load(),
                ),
              ],
              child: const ExerciseDetailView(),
            ),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (_, state) => BlocProvider(
                  create: (_) => getIt<ExerciseEditorCubit>(
                    param1: state.pathParameters['exerciseId'],
                  )..load(),
                  child: const ExerciseEditorView(),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.dailyGoals,
        builder: (_, _) => BlocProvider(
          create: (_) => getIt<DailyGoalsCubit>()..start(),
          child: const DailyGoalsView(),
        ),
      ),
      GoRoute(
        path: RoutePaths.bodyWeight,
        builder: (_, _) => BlocProvider(
          create: (_) => getIt<BodyWeightCubit>()..start(),
          child: const BodyWeightView(),
        ),
      ),
    ],
  );
}
