import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models.dart';
import 'demo_repository.dart';
import 'repository.dart';
import 'supabase_repository.dart';

enum AppMode { demo, supabase }

final appModeProvider = Provider<AppMode>((ref) => AppMode.demo);

final repositoryProvider = Provider<PredictorRepository>((ref) {
  final mode = ref.watch(appModeProvider);
  if (mode == AppMode.supabase) {
    return SupabasePredictorRepository(Supabase.instance.client);
  }
  return DemoPredictorRepository();
});

final currentUserProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(repositoryProvider).watchUser();
});

final matchesProvider = StreamProvider<List<MatchWithPrediction>>((ref) {
  return ref.watch(repositoryProvider).watchMatches();
});

final leaguesProvider = StreamProvider<List<LeagueSummary>>((ref) {
  return ref.watch(repositoryProvider).watchLeagues();
});

final leaderboardProvider =
    StreamProvider.family<List<LeaderboardEntry>, String>((ref, leagueId) {
      return ref.watch(repositoryProvider).watchLeaderboard(leagueId);
    });
