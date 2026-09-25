import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/app/theme/app_theme.dart';
import 'package:gainit/core/constants/app_info.dart';
import 'package:gainit/features/startup/presentation/cubits/splash_cubit.dart';
import 'package:gainit/features/startup/presentation/views/splash_view.dart';
import 'package:mocktail/mocktail.dart';

class _MockSplashCubit extends MockCubit<SplashState> implements SplashCubit {}

void main() {
  Future<void> pumpSplash(WidgetTester tester, {bool reduceMotion = false}) {
    final cubit = _MockSplashCubit();
    when(() => cubit.state).thenReturn(const SplashLoading());
    return tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: MaterialApp(
          theme: AppTheme.dark,
          home: BlocProvider<SplashCubit>.value(
            value: cubit,
            child: const SplashView(),
          ),
        ),
      ),
    );
  }

  double nameOpacity(WidgetTester tester) => tester
      .widget<FadeTransition>(
        // The nearest one; the route has its own further up.
        find
            .ancestor(
              of: find.text(AppInfo.name),
              matching: find.byType(FadeTransition),
            )
            .first,
      )
      .opacity
      .value;

  testWidgets('the logo is shown at once and the name rises in', (
    tester,
  ) async {
    await pumpSplash(tester);

    expect(find.image(const AssetImage(AppInfo.logoAsset)), findsOneWidget);
    expect(nameOpacity(tester), 0);

    await tester.pumpAndSettle();
    expect(nameOpacity(tester), 1);
  });

  testWidgets('with reduced motion everything is shown at once', (
    tester,
  ) async {
    await pumpSplash(tester, reduceMotion: true);

    expect(nameOpacity(tester), 1);
  });
}
