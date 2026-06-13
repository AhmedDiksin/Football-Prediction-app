import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/providers.dart';
import '../domain/models.dart';
import '../theme/app_theme.dart';
import '../widgets/point_gem.dart';

class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(matchesProvider);
    return matches.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(error.toString())),
      data: (items) {
        final grouped = _groupByDay(items);
        return ListView(
          key: const ValueKey('matchesList'),
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 28),
          children: [
            for (final entry in grouped.entries) ...[
              Text(
                _dayLabel(entry.key),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              for (final item in entry.value) ...[
                MatchCard(item: item),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 18),
            ],
          ],
        );
      },
    );
  }

  Map<DateTime, List<MatchWithPrediction>> _groupByDay(
    List<MatchWithPrediction> items,
  ) {
    final grouped = <DateTime, List<MatchWithPrediction>>{};
    for (final item in items) {
      final local = item.match.kickoffAt.toLocal();
      final key = DateTime(local.year, local.month, local.day);
      grouped.putIfAbsent(key, () => []).add(item);
    }
    return grouped;
  }

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));
    if (day == today) return 'Today';
    if (day == yesterday) return 'Yesterday';
    if (day == tomorrow) return 'Tomorrow';
    return DateFormat('EEEE d MMMM').format(day);
  }
}

class MatchCard extends ConsumerStatefulWidget {
  const MatchCard({required this.item, super.key});

  final MatchWithPrediction item;

  @override
  ConsumerState<MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends ConsumerState<MatchCard> {
  late int _home;
  late int _away;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _home = widget.item.prediction?.homeScore ?? 0;
    _away = widget.item.prediction?.awayScore ?? 0;
  }

  @override
  void didUpdateWidget(covariant MatchCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.prediction != widget.item.prediction) {
      _home = widget.item.prediction?.homeScore ?? _home;
      _away = widget.item.prediction?.awayScore ?? _away;
    }
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.item.match;
    final prediction = widget.item.prediction;
    final locked = match.isLocked || match.status != MatchStatus.scheduled;
    final appMode = ref.watch(appModeProvider);

    return Container(
      key: ValueKey('matchCard_${match.id}'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _TeamColumn(team: match.homeTeam)),
              _ScoreColumn(
                home: _home,
                away: _away,
                locked: locked,
                actualHome: match.homeScore,
                actualAway: match.awayScore,
                points: prediction?.points,
                exact: prediction?.exact ?? false,
                onHomeChanged: (value) => setState(() => _home = value),
                onAwayChanged: (value) => setState(() => _away = value),
              ),
              Expanded(
                child: _TeamColumn(team: match.awayTeam, alignEnd: true),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${DateFormat.Hm().format(match.kickoffAt.toLocal())} • ${match.stage}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!locked)
                TextButton.icon(
                  key: ValueKey('savePrediction_${match.id}'),
                  onPressed: _busy ? null : _save,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(prediction == null ? 'Place' : 'Update'),
                )
              else
                _StatusPill(match: match, prediction: prediction),
            ],
          ),
          const SizedBox(height: 12),
          _PickSplit(item: widget.item),
          if (appMode == AppMode.demo &&
              match.status != MatchStatus.finished) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              key: ValueKey('simulateFinal_${match.id}'),
              onPressed:
                  () => ref
                      .read(repositoryProvider)
                      .simulateFinalScore(
                        matchId: match.id,
                        homeScore: _home,
                        awayScore: _away,
                      ),
              icon: const Icon(Icons.sports_score_rounded),
              label: const Text('Simulate final'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(repositoryProvider)
          .upsertPrediction(
            matchId: widget.item.match.id,
            homeScore: _home,
            awayScore: _away,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Prediction saved')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _TeamColumn extends StatelessWidget {
  const _TeamColumn({required this.team, this.alignEnd = false});

  final Team team;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: Colors.white,
          child: Text(
            team.countryCode,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          team.name,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _ScoreColumn extends StatelessWidget {
  const _ScoreColumn({
    required this.home,
    required this.away,
    required this.locked,
    required this.onHomeChanged,
    required this.onAwayChanged,
    this.actualHome,
    this.actualAway,
    this.points,
    this.exact = false,
  });

  final int home;
  final int away;
  final bool locked;
  final int? actualHome;
  final int? actualAway;
  final int? points;
  final bool exact;
  final ValueChanged<int> onHomeChanged;
  final ValueChanged<int> onAwayChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 138,
      child: Column(
        children: [
          if (points != null)
            Container(
              transform: Matrix4.translationValues(0, -8, 0),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: exact ? AppColors.lime : AppColors.mint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '$points',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ScoreStepper(
                value: home,
                locked: locked,
                onChanged: onHomeChanged,
                keyPrefix: 'home',
              ),
              const SizedBox(width: 8),
              _ScoreStepper(
                value: away,
                locked: locked,
                onChanged: onAwayChanged,
                keyPrefix: 'away',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            actualHome == null ? 'Prediction' : '$actualHome - $actualAway',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _ScoreStepper extends StatelessWidget {
  const _ScoreStepper({
    required this.value,
    required this.locked,
    required this.onChanged,
    required this.keyPrefix,
  });

  final int value;
  final bool locked;
  final ValueChanged<int> onChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          key: ValueKey('${keyPrefix}ScoreUp'),
          onPressed:
              locked ? null : () => onChanged((value + 1).clamp(0, 12).toInt()),
          icon: const Icon(Icons.keyboard_arrow_up_rounded),
        ),
        Container(
          width: 54,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$value',
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
        ),
        IconButton(
          key: ValueKey('${keyPrefix}ScoreDown'),
          onPressed:
              locked ? null : () => onChanged((value - 1).clamp(0, 12).toInt()),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.match, required this.prediction});

  final FixtureMatch match;
  final Prediction? prediction;

  @override
  Widget build(BuildContext context) {
    final text = switch (match.status) {
      MatchStatus.finished =>
        prediction?.points == null ? 'Final' : '${prediction!.points} pts',
      MatchStatus.live => 'Live',
      MatchStatus.postponed => 'Postponed',
      MatchStatus.scheduled => 'Locked',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class _PickSplit extends StatelessWidget {
  const _PickSplit({required this.item});

  final MatchWithPrediction item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const PointGem(size: 14, color: AppColors.lime),
        const SizedBox(width: 6),
        Text(
          '${item.homePickPercent}% home',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(width: 14),
        const PointGem(size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '${item.awayPickPercent}% away • ${item.drawPickPercent}% draw',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }
}
