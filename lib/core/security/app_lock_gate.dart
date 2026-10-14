import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/security/app_security.dart';

final appLockEnabledProvider = FutureProvider<bool>((ref) => AppSecurity.hasPin());

/// Wraps the whole app. Shows the PIN/fingerprint screen whenever a lock
/// is set — on cold start and every time the app returns to the
/// foreground.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  bool _locked = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkLock() async {
    final has = await AppSecurity.hasPin();
    if (mounted) {
      setState(() {
        _locked = has;
        _checked = true;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkLock();
  }

  void _unlock() => setState(() => _locked = false);

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    if (_locked) return LockScreen(onUnlocked: _unlock);
    return widget.child;
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _entered = '';
  String? _error;
  bool _bioAvailable = false;

  @override
  void initState() {
    super.initState();
    _tryBiometricOnStart();
  }

  Future<void> _tryBiometricOnStart() async {
    final enabled = await AppSecurity.biometricEnabled();
    if (!enabled) return;
    final auth = LocalAuthentication();
    try {
      final can = await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (!can) return;
      if (!mounted) return;
      setState(() => _bioAvailable = true);
      final ok = await auth.authenticate(
        localizedReason: 'Unlock Hisab Master',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (ok && mounted) widget.onUnlocked();
    } catch (_) {}
  }

  Future<void> _onDigit(String d) async {
    if (_entered.length >= 6) return;
    setState(() {
      _entered += d;
      _error = null;
    });
    if (_entered.length >= 4) {
      final ok = await AppSecurity.verifyPin(_entered);
      if (!mounted) return;
      if (ok) {
        widget.onUnlocked();
      } else if (_entered.length >= 6) {
        setState(() {
          _entered = '';
          _error = 'Wrong PIN';
        });
      }
    }
  }

  void _backspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 48),
              Icon(Icons.lock_outline, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text('Hisab Master locked', style: theme.textTheme.titleMedium),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) {
                  final filled = i < _entered.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                    ),
                  );
                }),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const Spacer(),
              if (_bioAvailable)
                IconButton(
                  onPressed: _tryBiometricOnStart,
                  icon: const Icon(Icons.fingerprint, size: 40),
                  tooltip: 'Use fingerprint',
                ),
              _Keypad(
                onDigit: _onDigit,
                onBackspace: _backspace,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onDigit, required this.onBackspace});

  final void Function(String) onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    Widget key(String label, {VoidCallback? onTap, IconData? icon}) => SizedBox(
          width: 72,
          height: 64,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Center(
              child: icon != null
                  ? Icon(icon, size: 26)
                  : Text(label, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
            ),
          ),
        );

    return Column(
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', '<'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final d in row)
                d == ''
                    ? key('')
                    : d == '<'
                        ? key('', icon: Icons.backspace_outlined, onTap: onBackspace)
                        : key(d, onTap: () => onDigit(d)),
            ],
          ),
      ],
    );
  }
}
