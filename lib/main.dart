import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app/app.dart';
import 'src/data/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env.example', isOptional: true);
  const appModeOverride = String.fromEnvironment('APP_MODE');
  final appMode = appModeOverride.isNotEmpty
      ? appModeOverride
      : dotenv.maybeGet('APP_MODE', fallback: 'demo') ?? 'demo';

  const supabaseUrlOverride = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKeyOverride = String.fromEnvironment('SUPABASE_ANON_KEY');
  final supabaseUrl = supabaseUrlOverride.isNotEmpty ? supabaseUrlOverride : dotenv.maybeGet('SUPABASE_URL');
  final supabaseAnonKey = supabaseAnonKeyOverride.isNotEmpty ? supabaseAnonKeyOverride : dotenv.maybeGet('SUPABASE_ANON_KEY');
  final canUseSupabase = appMode == 'supabase' &&
      supabaseUrl != null &&
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey != null &&
      supabaseAnonKey.isNotEmpty;

  if (canUseSupabase) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  runApp(
    ProviderScope(
      overrides: [
        appModeProvider.overrideWithValue(canUseSupabase ? AppMode.supabase : AppMode.demo),
      ],
      child: const PredictorApp(),
    ),
  );
}
