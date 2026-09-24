import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/app/theme/app_theme.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/domain/entities/program.dart';
import 'package:gainit/core/domain/validation/validators.dart';
import 'package:gainit/core/presentation/view_state.dart';
import 'package:gainit/features/exercises/presentation/cubits/exercise_cubits.dart';
import 'package:gainit/features/exercises/presentation/views/exercise_library_view.dart';
import 'package:gainit/features/exercises/presentation/widgets/exercise_video_player.dart';
import 'package:gainit/features/program/presentation/widgets/exercise_config_sheet.dart';
import 'package:mocktail/mocktail.dart';

class _MockLibraryCubit extends MockCubit<ViewState<List<Exercise>>>
    implements ExerciseLibraryCubit {}

Exercise _exercise(String id, String name) => Exercise(
  id: id,
  name: name,
  primaryMuscle: MuscleGroup.biceps,
  category: ExerciseCategory.isolation,
  createdAt: DateTime(2026),
);

const _entry = ProgramExercise(
  id: 'pe',
  workoutDayId: 'day',
  exerciseId: 'ex',
  orderIndex: 0,
  workingSets: 3,
  repMin: 10,
  repMax: 10,
  restMinSeconds: 60,
  restMaxSeconds: 90,
  rirMin: 0,
  rirMax: 2,
  weightStep: 1,
  supersetGroup: 1,
);

void main() {
  testWidgets('the picker shows exercises already in the day as added', (
    tester,
  ) async {
    final cubit = _MockLibraryCubit();
    when(() => cubit.state).thenReturn(
      ViewLoaded([_exercise('ex_a', 'Curl'), _exercise('ex_b', 'Hammer')]),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: BlocProvider<ExerciseLibraryCubit>.value(
          value: cubit,
          child: const ExerciseLibraryView(
            pickMode: true,
            alreadyAdded: {'ex_a'},
          ),
        ),
      ),
    );

    expect(find.text('In this workout'), findsOneWidget);
    expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
  });

  testWidgets('raising min reps past max raises max too; superset can clear', (
    tester,
  ) async {
    ProgramExercise? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showExerciseConfigSheet(
              context,
              entry: _entry,
              exerciseName: 'Curl',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Increase min reps'));
    await tester.pump();
    final sheet = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(
      find.text('Superset 1'),
      200,
      scrollable: sheet,
    );
    await tester.tap(find.text('Superset 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('None').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Save'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(result!.repMin, 11);
    expect(result!.repMax, 11);
    expect(result!.supersetGroup, isNull);
    expect(Validators.programExercise(result!), isEmpty);
  });

  testWidgets('a video that cannot be opened shows a message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ExerciseVideoPlayer(path: '/missing/demo.mp4')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('This video cannot be played.'), findsOneWidget);
  });

  group('programExercise limits', () {
    test('weight step must be finite and at most 10 kg', () {
      expect(
        Validators.programExercise(_entry.copyWith(weightStep: 12)),
        isNotEmpty,
      );
      expect(
        Validators.programExercise(_entry.copyWith(weightStep: double.nan)),
        isNotEmpty,
      );
    });

    test('superset group must be 1–4', () {
      expect(
        Validators.programExercise(_entry.copyWith(supersetGroup: 5)),
        isNotEmpty,
      );
      expect(Validators.programExercise(_entry), isEmpty);
    });
  });
}
