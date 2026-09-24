import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_info.dart';
import 'theme/app_theme.dart';

class GainItApp extends StatelessWidget {
  const GainItApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Dark-first training tool (spec §17).
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
