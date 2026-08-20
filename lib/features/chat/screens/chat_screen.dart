import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/error_message.dart';
import '../../../shared/models/conversation.dart';
import '../../../shared/models/offer.dart';
import '../../../shared/models/user.dart';
import '../../auth/providers/auth_provider.dart';
import '../../trust/widgets/report_sheet.dart';
import '../providers/blocked_users_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/conversations_provider.dart';
import '../providers/reverb_socket_provider.dart';
import '../widgets/make_offer_sheet.dart';
import '../widgets/message_bubble.dart';
import '../widgets/quick_reply_chips.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _bodyController = TextEditingController();
  bool _isSending = false;
  bool _isNegotiating = false;
  bool _otherIsTyping = false;
  Timer? _typingResetTimer;

  @override
  void initState() {
    super.initState();
    ref.read(conversationsProvider.notifier).markRead(widget.conversationId);
    ref.read(reverbSocketProvider).listen(
      channelName: 'private-conversation.${widget.conversationId}',
      eventName: 'client-typing',
      onEvent: (_) {
        _typingResetTimer?.cancel();
        setState(() => _otherIsTyping = true);
        _typingResetTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _otherIsTyping = false);
        });
      },
    );
  }

  @override
  void dispose() {
    _bodyController.dispose();
    _typingResetTimer?.cancel();
    super.dispose();
  }

  Conversation? _conversation() {
    final conversations = ref.read(conversationsProvider).value ?? [];
    for (final c in conversations) {
      if (c.id == widget.conversationId) return c;
    }
    return null;
  }

  Future<void> _send(String body) async {
    if (body.trim().isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _bodyController.clear();

    try {
      await ref.read(chatProvider(widget.conversationId).notifier).sendMessage(body.trim());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessageFrom(e, fallback: 'Could not send message.')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    setState(() => _isSending = true);
    try {
      final bytes = await picked.readAsBytes();
      await ref
          .read(chatProvider(widget.conversationId).notifier)
          .sendImage(bytes: bytes, filename: picked.name);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessageFrom(e, fallback: 'Could not send photo.')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<double?> _promptAmount({required String title, double? initialAmount}) {
    final listing = _conversation()?.listing;
    if (listing == null) return Future.value(null);

    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (_) => MakeOfferSheet(
        listingPrice: listing.price,
        title: title,
        initialAmount: initialAmount,
      ),
    );
  }

  Future<void> _runNegotiationAction(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    if (_isNegotiating) return;
    setState(() => _isNegotiating = true);

    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessageFrom(e, fallback: 'Could not complete that.')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isNegotiating = false);
    }
  }

  Future<void> _makeOffer() async {
    final amount = await _promptAmount(title: 'Make an offer');
    if (amount == null) return;

    await _runNegotiationAction(
      () => ref.read(chatProvider(widget.conversationId).notifier).makeOffer(amount),
      successMessage: 'Offer sent.',
    );
  }

  Future<void> _counterOffer(Offer offer) async {
    final amount = await _promptAmount(title: 'Counter offer', initialAmount: offer.amount);
    if (amount == null) return;

    await _runNegotiationAction(
      () => ref
          .read(chatProvider(widget.conversationId).notifier)
          .counterOffer(offer.id, amount),
      successMessage: 'Counter-offer sent.',
    );
  }

  Future<void> _acceptOffer(Offer offer) {
    return _runNegotiationAction(
      () => ref.read(chatProvider(widget.conversationId).notifier).acceptOffer(offer.id),
      successMessage: 'Offer accepted.',
    );
  }

  Future<void> _declineOffer(Offer offer) {
    return _runNegotiationAction(
      () => ref.read(chatProvider(widget.conversationId).notifier).declineOffer(offer.id),
      successMessage: 'Offer declined.',
    );
  }

  Future<void> _retractOffer(Offer offer) {
    return _runNegotiationAction(
      () => ref.read(chatProvider(widget.conversationId).notifier).retractOffer(offer.id),
      successMessage: 'Offer retracted.',
    );
  }

  void _payNow(Offer offer) {
    context.push('/checkout/offer', extra: offer);
  }

  void _viewOrder(Offer offer) {
    if (offer.orderId != null) context.push('/orders/${offer.orderId}');
  }

  Future<void> _toggleBlock(bool currentlyBlocked, User? otherUser) async {
    if (otherUser == null) return;

    if (currentlyBlocked) {
      await ref.read(blockedUsersProvider.notifier).unblock(otherUser);
    } else {
      await ref.read(blockedUsersProvider.notifier).block(otherUser);
    }
  }

  Future<void> _reportUser(User? otherUser) async {
    if (otherUser == null) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ReportSheet(reportableType: 'user', reportableId: otherUser.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatProvider(widget.conversationId));
    final currentUserId = ref.watch(authProvider).value?.id;
    final conversation = _conversation();
    final other = conversation?.otherParticipant(currentUserId);
    final blockedIds = ref.watch(blockedUserIdsProvider);
    final isBlocked = other != null && blockedIds.contains(other.id);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: GestureDetector(
          onTap: conversation?.listing == null
              ? null
              : () => context.push('/listings/${conversation!.listing!.id}'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(other?.name ?? 'Chat'),
              if (conversation?.listing != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        conversation!.listing!.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                              decoration: TextDecoration.underline,
                            ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'block') _toggleBlock(isBlocked, other);
              if (value == 'report') _reportUser(other);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'block',
                child: Text(isBlocked ? 'Unblock user' : 'Block user'),
              ),
              const PopupMenuItem(
                value: 'report',
                child: Text('Report user'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'Say hello to get the conversation started.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textMuted),
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[messages.length - 1 - index];

                    return MessageBubble(
                      message: message,
                      isMine: message.sender?.id == currentUserId,
                      currentUserId: currentUserId,
                      onAcceptOffer: message.offer == null
                          ? null
                          : () => _acceptOffer(message.offer!),
                      onCounterOffer: message.offer == null
                          ? null
                          : () => _counterOffer(message.offer!),
                      onDeclineOffer: message.offer == null
                          ? null
                          : () => _declineOffer(message.offer!),
                      onRetractOffer: message.offer == null
                          ? null
                          : () => _retractOffer(message.offer!),
                      onPayNowOffer: message.offer == null
                          ? null
                          : () => _payNow(message.offer!),
                      onViewOrderOffer: message.offer == null
                          ? null
                          : () => _viewOrder(message.offer!),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text(
                  'Could not load messages.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.error),
                ),
              ),
            ),
          ),
          if (_otherIsTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Typing…',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textMuted),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          if (isBlocked)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                "You've blocked this user - unblock to send new messages.",
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textMuted),
              ),
            )
          else ...[
            QuickReplyChips(
              onSelected: _send,
              trailing: conversation?.listing != null &&
                      conversation!.listing!.isNegotiable &&
                      conversation.listing!.isActive &&
                      conversation.buyer?.id == currentUserId
                  ? ActionChip(
                      avatar: const Icon(Icons.local_offer_outlined, size: 16),
                      label: const Text('Make an offer'),
                      onPressed: _isNegotiating ? null : _makeOffer,
                    )
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _isSending ? null : _sendImage,
                      icon: const Icon(Icons.image_outlined),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _bodyController,
                        onChanged: (_) => ref
                            .read(chatProvider(widget.conversationId).notifier)
                            .notifyTyping(),
                        decoration: const InputDecoration(hintText: 'Message'),
                        textInputAction: TextInputAction.send,
                        onSubmitted: _send,
                      ),
                    ),
                    IconButton(
                      onPressed: _isSending ? null : () => _send(_bodyController.text),
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
