import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/message.dart';
import 'offer_card.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.currentUserId,
    this.onAcceptOffer,
    this.onCounterOffer,
    this.onDeclineOffer,
    this.onRetractOffer,
    this.onPayNowOffer,
    this.onViewOrderOffer,
  });

  final Message message;
  final bool isMine;
  final String? currentUserId;
  final VoidCallback? onAcceptOffer;
  final VoidCallback? onCounterOffer;
  final VoidCallback? onDeclineOffer;
  final VoidCallback? onRetractOffer;
  final VoidCallback? onPayNowOffer;
  final VoidCallback? onViewOrderOffer;

  @override
  Widget build(BuildContext context) {
    if (message.type == MessageType.offer && message.offer != null) {
      return Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: OfferCard(
          offer: message.offer!,
          currentUserId: currentUserId,
          onAccept: onAcceptOffer,
          onCounter: onCounterOffer,
          onDecline: onDeclineOffer,
          onRetract: onRetractOffer,
          onPayNow: onPayNowOffer,
          onViewOrder: onViewOrderOffer,
        ),
      );
    }

    if (message.type == MessageType.system) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: Text(
              message.body ?? '',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      );
    }

    final background = isMine ? AppColors.primary : AppColors.accent.withValues(alpha: 0.22);
    final foreground = isMine ? AppColors.surface : AppColors.textPrimary;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.type == MessageType.image && message.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                child: Image.network(message.imageUrl!, fit: BoxFit.cover),
              )
            else
              Text(message.body ?? '', style: TextStyle(color: foreground)),
            if (message.isFlagged) ...[
              const SizedBox(height: 4),
              Text(
                'Contact info removed - keep it in the app.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: foreground.withValues(alpha: 0.75),
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              Formatters.messageTime(message.createdAt ?? DateTime.now()),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: foreground.withValues(alpha: 0.7),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
