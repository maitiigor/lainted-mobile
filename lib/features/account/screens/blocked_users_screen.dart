import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/error_message.dart';
import '../../chat/providers/blocked_users_provider.dart';

/// Doc: "Blocked users list" - a thin read+unblock screen over the
/// blocking already built for chat (chat_screen.dart's per-conversation
/// block toggle) - no new "block a user" entry point here.
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedAsync = ref.watch(blockedUsersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Blocked Users')),
      body: blockedAsync.when(
        data: (blocked) => blocked.isEmpty
            ? Center(
                child: Text(
                  "You haven't blocked anyone.",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: blocked.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final user = blocked[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.accent,
                      backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                      child: user.photoUrl == null
                          ? Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?')
                          : null,
                    ),
                    title: Text(user.name),
                    trailing: TextButton(
                      onPressed: () async {
                        try {
                          await ref.read(blockedUsersProvider.notifier).unblock(user);
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(errorMessageFrom(e, fallback: 'Could not unblock this user.'))),
                          );
                        }
                      },
                      child: const Text('Unblock'),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text(
            'Could not load blocked users.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.error),
          ),
        ),
      ),
    );
  }
}
