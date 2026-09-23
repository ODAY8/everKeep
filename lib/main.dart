import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config/startup_error_app.dart';
import 'core/config/supabase_config.dart';
import 'core/routing/app_router.dart';
import 'core/session/session_sync.dart';
import 'core/supabase/app_supabase.dart';
import 'core/theme/app_fonts.dart';
import 'core/theme/app_theme.dart';
import 'providers/account_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/document_provider.dart';
import 'providers/memory_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/trusted_contact_provider.dart';
import 'providers/user_provider.dart';
import 'providers/vault_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureFonts();

  // The backend is required: with no (or a bad) Supabase configuration there
  // is nothing real to show, so say so instead of running on fake data.
  final configProblem = SupabaseConfig.problem;
  if (configProblem != null) {
    runApp(
      StartupErrorApp(
        title: 'Everkeep isn\'t connected yet',
        message:
            '$configProblem\n\nCopy .env.example to .env, fill in your Supabase '
            'project URL and publishable key, and run with '
            '--dart-define-from-file=.env.',
      ),
    );
    return;
  }

  try {
    await AppSupabase.initialize();
  } catch (_) {
    runApp(
      const StartupErrorApp(
        title: 'Couldn\'t start Everkeep',
        message:
            'The connection to Supabase could not be initialised. Check the '
            'project URL in your .env file and try again.',
      ),
    );
    return;
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => VaultProvider()),
        ChangeNotifierProvider(create: (_) => DocumentProvider()),
        ChangeNotifierProvider(create: (_) => MemoryProvider()),
        ChangeNotifierProvider(create: (_) => AccountProvider()),
        ChangeNotifierProvider(create: (_) => TrustedContactProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: const SessionSync(child: EverkeepApp()),
    ),
  );
}

class EverkeepApp extends StatelessWidget {
  const EverkeepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Everkeep',
      navigatorKey: AppRouter.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: AppRouter.splash,
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
