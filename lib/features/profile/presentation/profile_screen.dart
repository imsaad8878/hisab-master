import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app.dart' show kBrandGradient, kBrandText;
import '../../../core/firebase/firebase_bootstrap.dart';
import '../../../core/firebase/firebase_options_fallback.dart';
import '../../../core/security/app_security.dart';
import '../../../data/repositories/user_profile_repository.dart';
import '../../../models/loan.dart';
import '../../../models/transaction.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/loan_providers.dart';
import '../../../providers/profile_providers.dart';
import '../../../providers/transaction_providers.dart';
import '../../../utils/avatar.dart';
import '../../../utils/export.dart';
import '../../../utils/format.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _rechecking = false;
  bool _hasPin = false;

  @override
  void initState() {
    super.initState();
    // Email verify korle app e status ta cache thake — agei ekbar reload
    // nite hobe, nahole verify koreo "Email not verified" dekhay.
    Future.microtask(() => ref.read(authRepositoryProvider).refreshUser());
    AppSecurity.hasPin().then((v) {
      if (mounted) setState(() => _hasPin = v);
    });
  }

  /// Re-reads the account from Firebase so a verified Gmail shows as
  /// verified here immediately.
  Future<void> _recheckVerification() async {
    if (_rechecking) return;
    setState(() => _rechecking = true);
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(authRepositoryProvider).refreshUser();
    if (!mounted) return;
    setState(() => _rechecking = false);
    final verified =
        ref.read(authStateChangesProvider).valueOrNull?.emailVerified ?? false;
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: verified ? const Color(0xFF2E7D32) : Colors.blueGrey,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      content: Row(
        children: [
          Icon(verified ? Icons.verified : Icons.mail_outline,
              color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              verified
                  ? 'Email verified — thank you!'
                  : 'Email ekhono verify hoyni. Inbox ba Spam folder e '
                      'verification link e click korun, tarpor abar recheck korun.',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(displayUserProvider);
    final pending = ref.watch(pendingSyncProvider).valueOrNull ?? 0;
    final budgetValue =
        (ref.watch(profileDocProvider).valueOrNull?['monthlyBudget'] as num?)
                ?.toDouble() ??
            0;
    final theme = Theme.of(context);

    Future<void> logout() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Logout?'),
          content: const Text(
              'Make sure you are online so all data is synced to Firebase '
              'first. Unsynced offline data can be lost if you log out now.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Logout')),
          ],
        ),
      );
      if (ok == true) {
        await ref.read(authRepositoryProvider).signOut();
        if (context.mounted) {
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/login', (r) => false);
        }
      }
    }

    Future<void> editName() async {
      final controller = TextEditingController(text: user?.displayName ?? '');
      final name = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Change name'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            maxLength: 40,
            decoration: const InputDecoration(hintText: 'Your name'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, controller.text),
                child: const Text('Save')),
          ],
        ),
      );
      if (name == null || name.trim().isEmpty || user == null) return;
      await ref
          .read(userProfileRepositoryProvider)
          .setName(ref.read(dataUidProvider), name);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Name updated.')));
      }
    }

    Future<void> changePassword() async {
      final newCtrl = TextEditingController();
      final confirmCtrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Change password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm password'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Change')),
          ],
        ),
      );
      if (ok != true) return;
      if (newCtrl.text != confirmCtrl.text) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Duibar password ekhono alada.')));
        }
        return;
      }
      final err =
          await ref.read(authRepositoryProvider).updatePassword(newCtrl.text);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(err ?? 'Password changed successfully.')));
      }
    }

    Future<void> pickPhoto() async {
      if (user == null) return;
      final choice = await showModalBottomSheet<int>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(ctx, 1),
              ),
              if (kIsWeb)
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose from files'),
                  onTap: () => Navigator.pop(ctx, 1),
                )
              else
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Take a photo'),
                  onTap: () => Navigator.pop(ctx, 2),
                ),
              if (user.photoBase64 != null)
                ListTile(
                  leading: Icon(Icons.delete_outline,
                      color: theme.colorScheme.error),
                  title: Text('Remove custom photo',
                      style: TextStyle(color: theme.colorScheme.error)),
                  onTap: () => Navigator.pop(ctx, 3),
                ),
            ],
          ),
        ),
      );
      if (choice == null) return;
      final repo = ref.read(userProfileRepositoryProvider);
      final uid = ref.read(dataUidProvider);
      if (choice == 3) {
        await repo.setPhoto(uid, null);
        return;
      }
      try {
        final picked = await ImagePicker().pickImage(
          source: choice == 2 ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 600,
          maxHeight: 600,
          imageQuality: 70,
        );
        if (picked == null) return;
        final bytes = await picked.readAsBytes();
        final b64 = UserProfileRepository.encodeBase64(bytes);
        if (b64.length > 700000) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text(
                    'Image beshi boro — choto kore abar try korun.')));
          }
          return;
        }
        await repo.setPhoto(uid, b64);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Photo neoa jay ni: $e')));
        }
      }
    }

    Future<void> setBudget() async {
      final current =
          (ref.read(profileDocProvider).valueOrNull?['monthlyBudget'] as num?)
                  ?.toDouble() ??
              0;
      final controller = TextEditingController(
          text: current > 0 ? current.toStringAsFixed(0) : '');
      final value = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Monthly budget'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              prefixText: '৳ ',
              labelText: 'This month you can spend',
              helperText: 'Limit er agei warning pabe. 0 dile budget off.',
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, controller.text),
                child: const Text('Save')),
          ],
        ),
      );
      if (value == null) return;
      final amount = double.tryParse(value.trim()) ?? 0;
      await ref
          .read(userProfileRepositoryProvider)
          .setBudget(ref.read(dataUidProvider), amount);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                amount > 0 ? 'Budget set: ${Format.tk(amount)}/month' : 'Budget off.')));
      }
    }

    Future<void> setupPin({bool change = false}) async {
      final ctrl = TextEditingController();
      final pin = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(change ? 'Change PIN' : 'Set app lock PIN'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            decoration: const InputDecoration(
                hintText: '4–6 digit PIN', counterText: ''),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text),
                child: const Text('Save')),
          ],
        ),
      );
      if (pin == null) return;
      if (pin.length < 4 || pin.length > 6 || int.tryParse(pin) == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('PIN 4–6 digit er hote hobe.')));
        }
        return;
      }
      await AppSecurity.setPin(pin);
      if (mounted) setState(() => _hasPin = true);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('App lock চালু!')));
      }
    }

    Future<void> removePin() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Remove app lock?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Remove')),
          ],
        ),
      );
      if (ok == true) {
        await AppSecurity.clearPin();
        if (mounted) setState(() => _hasPin = false);
      }
    }

    Future<void> toggleBiometric(bool on) async {
      await AppSecurity.setBiometricEnabled(on);
      if (context.mounted) setState(() {});
    }

    Future<void> exportBackup() async {
      final txs = ref.read(transactionsProvider).valueOrNull ?? const [];
      final loans = ref.read(loansProvider).valueOrNull ?? const [];
      final rules = ref.read(recurringRulesProvider).valueOrNull ?? const [];
      final profile =
          ref.read(profileDocProvider).valueOrNull ?? const <String, dynamic>{};
      final json = buildBackupJson(
          transactions: txs, loans: loans, recurring: rules, profile: profile);
      await shareBackupFile(json);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Backup file share/save kore rakhun.')));
      }
    }

    Future<void> restoreBackup() async {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      final file = picked?.files.first;
      if (file == null) return;
      try {
        final text = utf8.decode(file.bytes ?? const <int>[]);
        final data = jsonDecode(text) as Map<String, dynamic>;
        if (data['app'] != 'hisab_master') {
          throw const FormatException('not a Hisab Master backup');
        }
        final uid = ref.read(dataUidProvider);
        final txRepo = ref.read(transactionRepositoryProvider);
        final loanRepo = ref.read(loanRepositoryProvider);
        final recRepo = ref.read(recurringRepositoryProvider);
        var count = 0;
        for (final m in (data['transactions'] as List? ?? const [])) {
          if (m is! Map) continue;
          final map = m.cast<String, dynamic>();
          final id = (map['id'] as String?) ?? '';
          if (id.isEmpty) continue;
          if (await txRepo.exists(uid, id)) continue;
          await txRepo.addTransaction(
              uid, TransactionModel.fromMap(id, map));
          count++;
        }
        for (final m in (data['loans'] as List? ?? const [])) {
          if (m is! Map) continue;
          final map = m.cast<String, dynamic>();
          final id = (map['id'] as String?) ?? '';
          if (id.isEmpty) continue;
          await loanRepo.saveLoan(uid, LoanRecord.fromMap(id, map));
        }
        for (final m in (data['recurring'] as List? ?? const [])) {
          if (m is! Map) continue;
          final map = m.cast<String, dynamic>();
          final id = (map['id'] as String?) ?? '';
          if (id.isEmpty) continue;
          await recRepo.saveRule(uid, RecurringRule.fromMap(id, map));
        }
        final profile = data['profile'];
        if (profile is Map && profile['name'] != null) {
          await ref
              .read(userProfileRepositoryProvider)
              .setName(uid, profile['name'] as String);
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Restore complete — $count notun entry added.')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Restore kaj koreni: $e')));
        }
      }
    }

    Future<void> manageRecurring() async {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Recurring entries'),
          content: SizedBox(
            width: double.maxFinite,
            child: Consumer(builder: (ctx, ref2, _) {
              final rules =
                  ref2.watch(recurringRulesProvider).valueOrNull ?? const [];
              if (rules.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                      'Add transaction e "Repeat every month" on korle '
                      'rule ekhane dekhabe.',
                      style: TextStyle(fontSize: 13)),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                itemCount: rules.length,
                itemBuilder: (_, i) {
                  final r = rules[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.repeat),
                    title: Text(
                        '${r.category} — ${Format.tk(r.amount)}/month'),
                    subtitle:
                        Text('Day ${r.dayOfMonth} • ${r.type}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => ref2
                          .read(recurringRepositoryProvider)
                          .deleteRule(ref2.read(dataUidProvider), r.id),
                    ),
                  );
                },
              );
            }),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close')),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: kBrandGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF146C43).withValues(alpha: 0.35),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -40,
                  right: -30,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.22),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: pickPhoto,
                            child: Stack(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color:
                                            Colors.white.withValues(alpha: 0.6),
                                        width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.25),
                                        blurRadius: 12,
                                      ),
                                    ],
                                  ),
                                  child: userAvatar(user, radius: 30),
                                ),
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: kBrandText, width: 1.5),
                                    ),
                                    child: Icon(Icons.photo_camera,
                                        size: 12, color: kBrandText),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user?.displayName ?? 'Your name',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text(
                                  user?.email ??
                                      (user?.isAnonymous == true
                                          ? 'Guest (demo mode)'
                                          : ''),
                                  style: TextStyle(
                                      color: Colors.white
                                          .withValues(alpha: 0.75),
                                      fontSize: 12.5),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (user?.isAnonymous == true &&
                          FirebaseService.ready)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.5)),
                            ),
                            onPressed: () =>
                                Navigator.of(context).pushNamed('/login'),
                            icon: const Icon(Icons.login, size: 16),
                            label: const Text('Sign in to sync'),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Change name'),
                  subtitle: Text(user?.displayName ?? 'Set your name'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: editName,
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.face_retouching_natural_outlined),
                  title: const Text('Change profile picture'),
                  subtitle: const Text('From gallery or camera'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: pickPhoto,
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.password_outlined),
                  title: const Text('Change password'),
                  subtitle: Text(FirebaseService.ready
                      ? 'For email/password account'
                      : 'Firebase setup er por available'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: changePassword,
                ),
              ],
            ),
          ),
          if (user?.email != null &&
              user!.isAnonymous != true &&
              FirebaseService.ready) ...[
            if (!user.emailVerified) ...[
              const SizedBox(height: 12),
              Card(
                color: Colors.blue.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading:
                        const Icon(Icons.email_outlined, color: Colors.blue),
                    title: const Text('Email not verified'),
                    subtitle: const Text(
                        'Verify your email to protect your account.'),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        TextButton(
                          onPressed: _rechecking
                              ? null
                              : () async {
                                  final repo = ref.read(authRepositoryProvider);
                                  final messenger =
                                      ScaffoldMessenger.of(context);
                                  try {
                                    await repo.sendEmailVerification();
                                    messenger.showSnackBar(const SnackBar(
                                        content: Text(
                                            'Verification email sent. Inbox ba Spam dekhen.')));
                                  } catch (e) {
                                    messenger.showSnackBar(
                                        SnackBar(content: Text('Error: $e')));
                                  }
                                },
                          child: const Text('Send'),
                        ),
                        FilledButton.tonal(
                          onPressed:
                              _rechecking ? null : _recheckVerification,
                          child: _rechecking
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : const Text('Recheck'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Card(
                color: Colors.green.withValues(alpha: 0.08),
                child: const ListTile(
                  leading:
                      Icon(Icons.verified_user_outlined, color: Colors.green),
                  title: Text('Email verified'),
                  subtitle: Text('Your account is protected.'),
                ),
              ),
            ],
          ],
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_done_outlined),
                  title: const Text('Sync status'),
                  subtitle: Text(FirebaseService.demoMode
                      ? 'Offline mode — data saved on this device only'
                      : pending > 0
                          ? '$pending change(s) waiting for internet'
                          : FirebaseService.ready
                              ? 'All data synced with Firebase'
                              : 'Demo mode — data saved on this device only'),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.cloud_outlined),
                  title: const Text('Backend'),
                  subtitle: Text(FirebaseService.demoMode
                      ? 'Offline mode — data saved on this device'
                      : isFallbackOptions
                          ? 'Local demo mode (no Firebase yet)'
                          : 'Firebase Firestore'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.savings_outlined),
                  title: const Text('Monthly budget'),
                  subtitle: Text(
                    budgetValue > 0 ? Format.tk(budgetValue) : 'Set a limit',
                    style: budgetValue > 0
                        ? null
                        : TextStyle(color: Colors.grey.shade500),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: setBudget,
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.repeat),
                  title: const Text('Recurring entries'),
                  subtitle: const Text('Monthly rent, salary rules'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: manageRecurring,
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('App lock'),
                  subtitle: Text(_hasPin ? 'PIN lock চালু' : 'PIN দিয়ে lock করুন'),
                  trailing: _hasPin
                      ? TextButton(
                          onPressed: removePin,
                          child: Text('Remove',
                              style:
                                  TextStyle(color: theme.colorScheme.error)),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _hasPin ? () => setupPin(change: true) : setupPin,
                ),
                if (_hasPin) ...[
                  const Divider(height: 1, indent: 56),
                  FutureBuilder<bool>(
                    future: AppSecurity.biometricEnabled(),
                    builder: (ctx, snap) => SwitchListTile(
                      secondary: const Icon(Icons.fingerprint),
                      title: const Text('Fingerprint unlock'),
                      subtitle: const Text('PIN er alternative'),
                      value: snap.data ?? false,
                      onChanged: toggleBiometric,
                    ),
                  ),
                ],
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('Backup (JSON file)'),
                  subtitle: const Text('Share kore rakhun — restore o jabe'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: exportBackup,
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.restore_outlined),
                  title: const Text('Restore backup'),
                  subtitle: const Text('Backup JSON file theke data ferot ana'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: restoreBackup,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(Icons.logout, color: theme.colorScheme.error),
              title: Text('Logout',
                  style: TextStyle(color: theme.colorScheme.error)),
              onTap: logout,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text('Hisab Master v1.0.0',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
