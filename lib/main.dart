import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/auth_service.dart';
import 'core/localization/app_language.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pre-load saved language for instant zero-flicker reactive localization
  String initialLanguage = 'English';
  try {
    initialLanguage = await AppLanguageNotifier.getPersistedLanguage();
  } catch (_) {}

  // Initialize Cloud Supabase when keys are provided via --dart-define-from-file=.env
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: supabaseAnonKey,
      );
      AuthService.markSupabaseInitialized();
    } catch (_) {
      // Fallback cleanly to mock/offline session mode
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        appLanguageProvider.overrideWith(() => AppLanguageNotifier(initialLanguage)),
      ],
      child: const SmartMoveApp(),
    ),
  );
}

class SmartMoveApp extends ConsumerWidget {
  const SmartMoveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(appLanguageProvider);

    return MaterialApp.router(
      key: ValueKey('smartmove_root_$language'),
      title: 'SmartMove',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
    );
  }
}
