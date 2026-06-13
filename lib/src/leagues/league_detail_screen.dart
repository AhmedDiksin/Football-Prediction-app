import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/point_gem.dart';
import 'leagues_screen.dart';

class LeagueDetailScreen extends ConsumerWidget {
  const LeagueDetailScreen({
    required this.leagueId,
    required this.leagueName,
    super.key,
  });

  final String leagueId;
  final String leagueName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboard = ref.watch(leaderboardProvider(leagueId));
    return Scaffold(
      body: SafeArea(
        child: leaderboard.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
          data: (entries) => ListView(
            key: const ValueKey('leaderboardList'),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
            children: [
              Row(
                children: [
                  IconButton(
                    key: const ValueKey('backFromLeaderboard'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 32),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          leagueName,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          '${entries.length} participants',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 54),
              const Row(
                children: [
                  Expanded(
                    child: Text(
                      'Position',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _LeaderboardHeaderStats(),
                ],
              ),
              const SizedBox(height: 22),
              for (final entry in entries)
                Container(
                  key: ValueKey('leader_${entry.userId}'),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 46,
                        child: Text(
                          '${entry.rank}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: entry.isCurrentUser
                                ? AppColors.mint
                                : Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Container(width: 1, height: 24, color: Colors.white24),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Text(
                          entry.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: entry.isCurrentUser
                                ? AppColors.mint
                                : Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      LeagueRowStat(
                        points: entry.points,
                        exactScores: entry.exactScores,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardHeaderStats extends StatelessWidget {
  const _LeaderboardHeaderStats();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PointGem(size: 16),
        SizedBox(width: 34),
        PointGem(size: 16, color: AppColors.lime),
        SizedBox(width: 12),
      ],
    );
  }
}
