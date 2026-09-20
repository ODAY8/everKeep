import 'package:everkeep/core/routing/app_router.dart';
import 'package:everkeep/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const EverkeepApp());
}

class EverkeepApp extends StatelessWidget {
  const EverkeepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Everkeep',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: AppRouter.splash,
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
