import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/models/user.dart';
import '../../auth/providers/auth_provider.dart';

/// Minimal account hub replacing the bare placeholder that used to sit
/// behind the bottom nav's Profile tab - it was silently making Wallet
/// (and therefore Transaction History/Bank Accounts/Withdraw) AND Logout
/// completely unreachable from anywhere in the app, since nothing else
/// ever linked to either. Phase 10 added Edit Profile/Change Phone/
/// Blocked Users/Delete Account on top of that.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  String _sellerTypeLabel(SellerType? type) {
    switch (type) {
      case SellerType.personal:
        return 'Personal Seller';
      case SellerType.business:
        return 'Business Seller';
      case SellerType.none:
      case null:
        return 'Buyer';
    }
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Log out')),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(authProvider.notifier).logout();
    if (context.mounted) context.go('/auth/login');
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          "Your account will be scheduled for deletion. You have 30 days to change your mind - just log "
          "back in and tap Restore. After that, it's permanent and your wallet balance will be forfeited.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(authProvider.notifier).deleteAccount();
    await ref.read(authProvider.notifier).logout();
    if (context.mounted) context.go('/auth/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.accent,
                  backgroundImage: user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
                  child: user?.photoUrl == null
                      ? Text(
                          user != null && user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                          style: Theme.of(context).textTheme.titleLarge,
                        )
                      : null,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? '', style: Theme.of(context).textTheme.titleLarge),
                      Text(
                        _sellerTypeLabel(user?.sellerType),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            _MenuTile(
              icon: Icons.person_outline,
              label: 'Edit Profile',
              onTap: () => context.push('/account/edit'),
            ),
            const Divider(height: 1),
            _MenuTile(
              icon: Icons.phone_outlined,
              label: 'Change Phone Number',
              onTap: () => context.push('/account/change-phone'),
            ),
            const Divider(height: 1),
            _MenuTile(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Wallet',
              onTap: () => context.push('/wallet'),
            ),
            if (user?.sellerType == SellerType.business) ...[
              const Divider(height: 1),
              _MenuTile(
                icon: Icons.workspace_premium_outlined,
                label: 'Subscription',
                onTap: () => context.push('/account/subscription'),
              ),
            ],
            const Divider(height: 1),
            _MenuTile(
              icon: Icons.block_outlined,
              label: 'Blocked Users',
              onTap: () => context.push('/account/blocked-users'),
            ),
            const Divider(height: 1),
            _MenuTile(
              icon: Icons.logout,
              label: 'Log out',
              color: AppColors.error,
              onTap: () => _logout(context, ref),
            ),
            const Divider(height: 1),
            _MenuTile(
              icon: Icons.delete_outline,
              label: 'Delete Account',
              color: AppColors.error,
              onTap: () => _deleteAccount(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.label, required this.onTap, this.color});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color ?? AppColors.textPrimary),
      title: Text(label, style: TextStyle(color: color)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
