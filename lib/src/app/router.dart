import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_screen.dart';
import '../data/providers.dart';
import '../home/home_screen.dart';
import '../leagues/league_detail_screen.dart';
import '../profile/profile_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final userState = ref.watch(currentUserProvider);
  final user = userState.valueOrNull;

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isAuth = state.matchedLocation == '/auth';
      final isProfile = state.matchedLocation == '/profile';
      if (userState.isLoading) return null;
      if (user == null) return isAuth ? null : '/auth';
      if (!user.hasProfile) return isProfile ? null : '/profile';
      if (isAuth || isProfile) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/league/:id',
        builder: (context, state) => LeagueDetailScreen(
          leagueId: state.pathParameters['id']!,
          leagueName: state.uri.queryParameters['name'] ?? 'League',
        ),
      ),
    ],
  );
});
