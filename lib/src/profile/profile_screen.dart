import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController(text: 'Ahmed Diksin');
  int _selectedColor = AppColors.mint.value;
  var _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const colors = [
      AppColors.mint,
      AppColors.cyan,
      AppColors.lime,
      AppColors.blue,
      Color(0xffff6bcb),
    ];
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
          children: [
            const Center(child: AppLogo(size: 64)),
            const SizedBox(height: 42),
            Text(
              'Choose your name',
              style: Theme.of(
                context,
              ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            const Text(
              'This is what your friends will see on the leaderboard.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 17),
            ),
            const SizedBox(height: 30),
            TextField(
              key: const ValueKey('displayNameField'),
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              children: [
                for (final color in colors)
                  ChoiceChip(
                    key: ValueKey('avatarColor_${color.value}'),
                    selected: _selectedColor == color.value,
                    label: const SizedBox(width: 22, height: 22),
                    avatar: CircleAvatar(backgroundColor: color),
                    onSelected: (_) =>
                        setState(() => _selectedColor = color.value),
                  ),
              ],
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              key: const ValueKey('saveProfileButton'),
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Saving' : 'Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(repositoryProvider)
          .saveProfile(
            displayName: _nameController.text.trim(),
            avatarColor: _selectedColor,
          );
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
