import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/app/theme/app_theme.dart';
import 'package:gainit/core/domain/entities/app_settings.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/domain/entities/user_profile.dart';
import 'package:gainit/core/presentation/action_outcome.dart';
import 'package:gainit/core/presentation/view_state.dart';
import 'package:gainit/features/settings/domain/entities/settings_overview.dart';
import 'package:gainit/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:gainit/features/settings/presentation/views/settings_view.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettingsCubit extends MockCubit<ViewState<SettingsOverview>>
    implements SettingsCubit {}

void main() {
  late _MockSettingsCubit cubit;

  final profile = UserProfile(
    id: 'me',
    name: 'Sam',
    heightCm: 180,
    goal: TrainingGoal.gainMuscle,
    trainingStartDate: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUpAll(() => registerFallbackValue(profile));

  setUp(() {
    cubit = _MockSettingsCubit();
    when(
      () => cubit.updateProfile(any(), age: any(named: 'age')),
    ).thenAnswer((_) async => const ActionDone<void>(null));
  });

  Future<void> openEditSheet(WidgetTester tester, {int? age}) async {
    await tester.binding.setSurfaceSize(const Size(420, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    when(() => cubit.state).thenReturn(
      ViewLoaded(
        SettingsOverview(
          settings: const AppSettings(),
          profile: profile,
          age: age,
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: BlocProvider<SettingsCubit>.value(
          value: cubit,
          child: const SettingsView(),
        ),
      ),
    );
    await tester.tap(find.text('Sam'));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('a profile without an age saves without inventing one', (
    tester,
  ) async {
    await openEditSheet(tester);

    expect(find.text('Not set'), findsOneWidget);
    await save(tester);

    verify(() => cubit.updateProfile(any(), age: null)).called(1);
  });

  testWidgets('an age past 90 starts at 90 so saving still works', (
    tester,
  ) async {
    await openEditSheet(tester, age: 92);

    expect(find.text('90 years'), findsOneWidget);
    await save(tester);

    verify(() => cubit.updateProfile(any(), age: 90)).called(1);
  });
}
