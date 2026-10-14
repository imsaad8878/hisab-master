import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app.dart' show kBrandGradient;
import '../../../core/firebase/firebase_bootstrap.dart';
import '../../../providers/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _registerMode = false;
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    if (msg.isEmpty || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  Future<void> _google() async {
    setState(() => _busy = true);
    final err = await ref.read(authRepositoryProvider).signInWithGoogle();
    if (mounted) setState(() => _busy = false);
    _showError(err);
  }

  Future<void> _email() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || !email.contains('@')) {
      _showError('Ekta thik email din.');
      return;
    }
    if (password.length < 6) {
      _showError('Password kom-pakhe 6 ta hote hobe.');
      return;
    }
    setState(() => _busy = true);
    final repo = ref.read(authRepositoryProvider);
    final err = _registerMode
        ? await repo.registerWithEmail(_nameCtrl.text, email, password)
        : await repo.signInWithEmail(email, password);
    if (mounted) setState(() => _busy = false);
    if (err.isNotEmpty) {
      _showError(err);
    } else if (_registerMode && mounted) {
      setState(() => _registerMode = false);
      _showError('Account toiri hoyeche. Verify email ta, tarpor login korun.');
    }
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _emailCtrl.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Forgot password?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Apnar account er email likhun. Amra ekta password reset '
              'link email e pathabo.',
              style: TextStyle(fontSize: 13.5),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.alternate_email, size: 20),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Send link')),
        ],
      ),
    );
    if (email == null || !mounted) return;
    final err =
        await ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
    if (!mounted) return;
    if (err.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2E7D32),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            const Icon(Icons.mark_email_read_outlined,
                color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Reset link $email e pathano hoyeche. Inbox ba Spam dekhen.',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ));
    } else {
      _showError(err);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateChangesProvider, (prev, next) {
      if (next.valueOrNull != null &&
          ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
      }
    });

    final theme = Theme.of(context);
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(gradient: kBrandGradient),
          ),
          Positioned(
            top: -110,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -90,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.08),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.calculate_rounded,
                          size: 58, color: Colors.white.withValues(alpha: 0.95)),
                      const SizedBox(height: 10),
                      const Text('Hisab Master',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5)),
                      const SizedBox(height: 4),
                      Text('Ayar khoroch — shob hisab ek app e',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 13.5)),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 30,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!FirebaseService.ready)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.info_outline,
                                          size: 18, color: Colors.amber),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Firebase configure kora nei — demo '
                                          'mode e cholate paran. (SETUP_GUIDE.md)',
                                          style: TextStyle(fontSize: 11.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            FilledButton.tonalIcon(
                              onPressed: _busy ? null : _google,
                              icon: const Icon(Icons.g_mobiledata, size: 26),
                              label: const Text('Continue with Google'),
                              style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15),
                                backgroundColor:
                                    theme.colorScheme.surfaceContainerHighest,
                                foregroundColor: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                const Expanded(child: Divider()),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('or',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: Colors.grey)),
                                ),
                                const Expanded(child: Divider()),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (_registerMode)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: TextField(
                                  controller: _nameCtrl,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: const InputDecoration(
                                    labelText: 'Your name',
                                    prefixIcon: Icon(Icons.person_outline,
                                        size: 20),
                                  ),
                                ),
                              ),
                            TextField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.alternate_email,
                                    size: 20),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _passwordCtrl,
                              obscureText: _obscure,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline,
                                    size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                      _obscure
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      size: 20),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                            ),
                            if (!_registerMode)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: _busy ? null : _forgotPassword,
                                  icon: const Icon(Icons.help_outline,
                                      size: 16),
                                  label: const Text('Forgot password?'),
                                ),
                              ),
                            const SizedBox(height: 8),
                            FilledButton(
                              onPressed: _busy ? null : _email,
                              style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15),
                              ),
                              child: _busy
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white))
                                  : Text(_registerMode
                                      ? 'Create account'
                                      : 'Login'),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => setState(
                                    () => _registerMode = !_registerMode),
                                child: Text(_registerMode
                                    ? 'Already have an account? Login'
                                    : "Don't have an account? Sign up"),
                              ),
                            ),
                            if (!FirebaseService.ready)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: OutlinedButton.icon(
                                  onPressed: () => ref
                                      .read(authRepositoryProvider)
                                      .continueAsDemo(),
                                  icon:
                                      const Icon(Icons.phone_android_outlined),
                                  label: const Text('Continue offline'),
                                ),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: TextButton.icon(
                                  onPressed: () => ref
                                      .read(authRepositoryProvider)
                                      .continueAsDemo(),
                                  icon: const Icon(Icons.cloud_off_outlined,
                                      size: 18),
                                  label: const Text(
                                      'Continue offline (data stays on this device)'),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
