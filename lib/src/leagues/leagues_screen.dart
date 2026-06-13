import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/providers.dart';
import '../domain/models.dart';
import '../theme/app_theme.dart';
import '../widgets/point_gem.dart';

class LeaguesScreen extends ConsumerWidget {
  const LeaguesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leagues = ref.watch(leaguesProvider);
    return leagues.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(error.toString())),
      data: (items) => ListView(
        key: const ValueKey('leaguesList'),
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
        children: [
          _LeaguePanel(leagues: items),
          const SizedBox(height: 24),
          _ActionCard(
            key: const ValueKey('createLeagueCard'),
            title: 'Create a new league',
            body: 'Create a league to compete against friends with a unique invite code.',
            icon: Icons.add_rounded,
            onTap: () => _showCreateLeague(context, ref),
          ),
          const SizedBox(height: 16),
          _ActionCard(
            key: const ValueKey('joinLeagueCard'),
            title: 'Join a league',
            body: 'Enter an invite code shared by a friend.',
            icon: Icons.login_rounded,
            onTap: () => _showJoinLeague(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateLeague(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: 'Daxan');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _InputDialog(
        title: 'Create league',
        fieldKey: const ValueKey('leagueNameField'),
        actionKey: const ValueKey('confirmCreateLeague'),
        controller: controller,
        label: 'League name',
        action: 'Create',
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      final league = await ref.read(repositoryProvider).createLeague(name);
      if (context.mounted) {
        context.push('/league/${league.id}?name=${Uri.encodeComponent(league.name)}');
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _showJoinLeague(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: 'DAXAN');
    final code = await showDialog<String>(
      context: context,
      builder: (context) => _InputDialog(
        title: 'Join league',
        fieldKey: const ValueKey('inviteCodeField'),
        actionKey: const ValueKey('confirmJoinLeague'),
        controller: controller,
        label: 'Invite code',
        action: 'Join',
      ),
    );
    if (code == null || code.trim().isEmpty) return;
    try {
      await ref.read(repositoryProvider).joinLeague(code);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('League joined')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _LeaguePanel extends StatelessWidget {
  const _LeaguePanel({required this.leagues});

  final List<LeagueSummary> leagues;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: leagueGradient,
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My leagues',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 24),
          const Row(
            children: [
              Expanded(
                child: Text('League', style: TextStyle(color: Colors.black54, fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              Text('Position', style: TextStyle(color: Colors.black54, fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          for (final league in leagues)
            InkWell(
              key: ValueKey('league_${league.id}'),
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.push('/league/${league.id}?name=${Uri.encodeComponent(league.name)}'),
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(league.isGlobal ? Icons.public_rounded : Icons.flag_rounded, color: Colors.black),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        league.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black, fontSize: 21, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          league.rank.toString(),
                          style: const TextStyle(color: Colors.black, fontSize: 26, fontWeight: FontWeight.w900),
                        ),
                        Text(
                          league.totalPlayers.toString(),
                          style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.body,
    required this.icon,
    required this.onTap,
    super.key,
  });

  final String title;
  final String body;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: cardGradient,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.black, fontSize: 26, height: 1.05, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 18),
                  Text(body, style: const TextStyle(color: Colors.black, fontSize: 17, height: 1.25)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.surface,
              child: Icon(icon, color: AppColors.cyan, size: 34),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputDialog extends StatelessWidget {
  const _InputDialog({
    required this.title,
    required this.fieldKey,
    required this.actionKey,
    required this.controller,
    required this.label,
    required this.action,
  });

  final String title;
  final Key fieldKey;
  final Key actionKey;
  final TextEditingController controller;
  final String label;
  final String action;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(title),
      content: TextField(
        key: fieldKey,
        controller: controller,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          key: actionKey,
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: Text(action),
        ),
      ],
    );
  }
}

class LeagueRowStat extends StatelessWidget {
  const LeagueRowStat({required this.points, required this.exactScores, super.key});

  final int points;
  final int exactScores;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const PointGem(size: 16),
        const SizedBox(width: 8),
        Text('$points', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(width: 22),
        const PointGem(size: 16, color: AppColors.lime),
        const SizedBox(width: 8),
        Text('$exactScores', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      ],
    );
  }
}
