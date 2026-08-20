import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/conversation.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/conversations_provider.dart';

class ConversationsListScreen extends ConsumerStatefulWidget {
  const ConversationsListScreen({super.key});

  @override
  ConsumerState<ConversationsListScreen> createState() => _ConversationsListScreenState();
}

class _ConversationsListScreenState extends ConsumerState<ConversationsListScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// The list is fetched in full (not paginated) and realistically stays
  /// small per user, so a client-side filter is enough - no backend
  /// search endpoint needed for this.
  List<_Entry> _filter(List<Conversation> conversations, String? currentUserId) {
    final entries = conversations.map((c) {
      final other = c.otherParticipant(currentUserId);
      return _Entry(conversation: c, otherName: other?.name ?? 'User');
    });

    if (_query.trim().isEmpty) return entries.toList();

    final query = _query.trim().toLowerCase();
    return entries.where((e) {
      final listingTitle = e.conversation.listing?.title.toLowerCase() ?? '';
      return e.otherName.toLowerCase().contains(query) || listingTitle.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(conversationsProvider);
    final currentUserId = ref.watch(authProvider).value?.id;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Chat')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search by seller, buyer, or listing',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(conversationsProvider.notifier).refresh(),
              child: conversationsAsync.when(
                data: (conversations) {
                  if (conversations.isEmpty) {
                    return ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                          child: Center(
                            child: Text(
                              'No conversations yet. Message a seller from a listing to start one.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.textMuted),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  final entries = _filter(conversations, currentUserId);

                  if (entries.isEmpty) {
                    return ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                          child: Center(
                            child: Text(
                              'No conversations match "$_query".',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.textMuted),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, indent: AppSpacing.lg),
                    itemBuilder: (context, index) {
                      final entry = entries[index];

                      return _ConversationTile(
                        conversation: entry.conversation,
                        otherName: entry.otherName,
                        onTap: () => context.push('/chat/${entry.conversation.id}'),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                      child: Center(
                        child: Text(
                          'Could not load conversations. Pull down to try again.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.error),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Entry {
  const _Entry({required this.conversation, required this.otherName});

  final Conversation conversation;
  final String otherName;
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.otherName,
    required this.onTap,
  });

  final Conversation conversation;
  final String otherName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final photoUrl = conversation.listing?.photos.isNotEmpty ?? false
        ? conversation.listing!.photos.first.url
        : null;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: SizedBox(
          width: 48,
          height: 48,
          child: photoUrl != null
              ? Image.network(photoUrl, fit: BoxFit.cover)
              : Container(
                  color: AppColors.accent.withValues(alpha: 0.3),
                  child: const Icon(Icons.image_outlined, color: AppColors.textMuted),
                ),
        ),
      ),
      title: Text(otherName, style: Theme.of(context).textTheme.titleLarge),
      subtitle: Text(
        conversation.listing?.title ?? 'Listing',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      trailing: conversation.lastMessageAt != null
          ? Text(
              Formatters.messageTime(conversation.lastMessageAt!),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textMuted),
            )
          : null,
    );
  }
}
