import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_provider.dart';

/// Reached only via the post-auth routing gate (splash_screen.dart /
/// otp_entry_screen.dart / password_login_screen.dart) when
/// user.accountStatus == pendingDeletion - logging back in during the
/// 30-day window is itself the recovery trigger, but restoring is still
/// a deliberate tap, not automatic, to avoid "wait, why is my account
/// back" confusion.
class RestoreAccountScreen extends ConsumerStatefulWidget {
  const RestoreAccountScreen({super.key});

  @override
  ConsumerState<RestoreAccountScreen> createState() => _RestoreAccountScreenState();
}

class _RestoreAccountScreenState extends ConsumerState<RestoreAccountScreen> {
  bool _isBusy = false;

  Future<void> _restore() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);

    try {
      await ref.read(authProvider.notifier).restoreAccount();
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessageFrom(e, fallback: 'Could not restore your account.'))),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    context.go('/auth/login');
  }

  @override
  Widget build(BuildContext context) {
    final requestedAt = ref.watch(authProvider).value?.deletionRequestedAt;
    final scheduledFor = requestedAt?.add(const Duration(days: 30));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.restore_outlined, size: 56, color: AppColors.primary),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Your account is scheduled for deletion',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                scheduledFor != null
                    ? "It will be permanently deleted on ${Formatters.shortDate(scheduledFor)}, and your "
                        "wallet balance will be forfeited. Restore your account to keep using Lainted."
                    : "Restore your account to keep using Lainted.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isBusy ? null : _restore,
                  child: Text(_isBusy ? 'Restoring…' : 'Restore my account'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: _isBusy ? null : _logout,
                child: const Text('Log out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
