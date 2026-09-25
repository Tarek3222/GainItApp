import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_info.dart';
import '../core/di/injection.dart';
import '../core/domain/entities/enums.dart';
import '../core/presentation/units/unit_format.dart';
import '../core/presentation/units/units_cubit.dart';
import 'theme/app_theme.dart';

class GainItApp extends StatelessWidget {
  const GainItApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    final locale = context.locale;
    // Dates and number formats follow the app language.
    Intl.defaultLocale = locale.languageCode;
    return BlocProvider(
      create: (_) => getIt<UnitsCubit>()..start(),
      child: MaterialApp.router(
        // Texts are looked up when widgets build. A new key makes every
        // widget below build again in the new language; the navigators keep
        // their pages and state (they have global keys), so open screens
        // stay open.
        key: ValueKey(locale.languageCode),
        title: AppInfo.name,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: locale,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        // Dark-first training tool (spec §17).
        themeMode: ThemeMode.dark,
        routerConfig: router,
        builder: (context, child) => BlocBuilder<UnitsCubit, UnitSystem>(
          builder: (context, system) =>
              UnitScope(system: system, child: child ?? const SizedBox()),
        ),
      ),
    );
  }
}
