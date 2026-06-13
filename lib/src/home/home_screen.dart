import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../leagues/leagues_screen.dart';
import '../matches/matches_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/point_gem.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  var _tab = 0;

  @override
  Widget build(BuildContext context) {
    final leagues = ref.watch(leaguesProvider).valueOrNull ?? const [];
    final points = leagues.isEmpty ? 0 : leagues.first.points;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: () {},
                        icon: const Icon(Icons.arrow_back_rounded, size: 30),
                      ),
                      const Spacer(),
                      const AppLogo(size: 48),
                      const Spacer(),
                      IconButton(
                        key: const ValueKey('signOutButton'),
                        tooltip: 'Sign out',
                        onPressed: () => ref.read(repositoryProvider).signOut(),
                        icon: const Icon(Icons.settings_rounded, size: 28),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _SegmentedTabs(value: _tab, onChanged: (value) => setState(() => _tab = value))),
                      const SizedBox(width: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(
                          children: [
                            const PointGem(size: 18, color: AppColors.cyan),
                            const SizedBox(width: 8),
                            Text('$points pts', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: const [
                  MatchesScreen(),
                  LeaguesScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(23),
      ),
      child: Row(
        children: [
          _SegmentButton(label: 'Matches', selected: value == 0, onTap: () => onChanged(0)),
          _SegmentButton(label: 'Leagues', selected: value == 1, onTap: () => onChanged(1)),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white.withValues(alpha: 0.34) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}
