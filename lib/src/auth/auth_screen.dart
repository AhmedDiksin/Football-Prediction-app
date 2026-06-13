import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController(text: 'friend@example.com');
  final _passwordController = TextEditingController(text: 'password123');
  var _isSignUp = true;
  var _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
          children: [
            const Center(child: AppLogo(size: 64)),
            const SizedBox(height: 42),
            Text(
              _isSignUp ? 'Create account' : 'Welcome back',
              style: Theme.of(
                context,
              ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            const Text(
              'Predict World Cup scores with your friends.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 17),
            ),
            const SizedBox(height: 32),
            TextField(
              key: const ValueKey('emailField'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('passwordField'),
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 22),
            ElevatedButton(
              key: const ValueKey('authSubmitButton'),
              onPressed: _busy ? null : _submit,
              child: Text(
                _busy ? 'Please wait' : (_isSignUp ? 'Sign up' : 'Sign in'),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed:
                  _busy ? null : () => setState(() => _isSignUp = !_isSignUp),
              child: Text(
                _isSignUp
                    ? 'I already have an account'
                    : 'Create a new account',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final repo = ref.read(repositoryProvider);
    try {
      if (_isSignUp) {
        await repo.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await repo.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
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
