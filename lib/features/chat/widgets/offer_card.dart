import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/offer.dart';

/// Renders an offer/counter-offer as a negotiation card in place of a
/// normal chat bubble. Accept/Counter/Decline are only shown to whichever
/// party did NOT propose the current round - the other party is just
/// waiting, same rule the backend enforces in `OfferService`.
class OfferCard extends StatelessWidget {
  const OfferCard({
    super.key,
    required this.offer,
    required this.currentUserId,
    this.onAccept,
    this.onCounter,
    this.onDecline,
    this.onRetract,
    this.onPayNow,
    this.onViewOrder,
  });

  final Offer offer;
  final String? currentUserId;
  final VoidCallback? onAccept;
  final VoidCallback? onCounter;
  final VoidCallback? onDecline;
  final VoidCallback? onRetract;
  final VoidCallback? onPayNow;
  final VoidCallback? onViewOrder;

  bool get _isBuyer => offer.buyer?.id == currentUserId;

  OfferParty get _currentParty => _isBuyer ? OfferParty.buyer : OfferParty.seller;

  bool get _isResponder => _currentParty != offer.initiatedBy;

  bool get _isProposer => _currentParty == offer.initiatedBy;

  String get _statusLabel {
    switch (offer.status) {
      case OfferStatus.pending:
        return _isResponder ? 'Awaiting your response' : 'Waiting on a response';
      case OfferStatus.countered:
        return 'Countered';
      case OfferStatus.accepted:
        return 'Accepted';
      case OfferStatus.declined:
        return 'Declined';
      case OfferStatus.expired:
        return 'Offer expired';
      case OfferStatus.retracted:
        return 'Offer retracted';
      case OfferStatus.checkoutExpired:
        return 'Checkout window expired';
      case OfferStatus.completed:
        return 'Completed';
    }
  }

  /// The backend's `offers:sweep` command only flips a stale `accepted`
  /// row to `checkoutExpired` every 5 minutes - checking the deadline
  /// directly here means the UI stops offering to pay the instant the
  /// 2-hour window closes, not up to 5 minutes late.
  bool get _isCheckoutWindowExpired =>
      offer.checkoutExpiresAt != null && offer.checkoutExpiresAt!.isBefore(DateTime.now());

  Duration? get _timeRemaining {
    final deadline = offer.checkoutExpiresAt;
    if (deadline == null) return null;

    final remaining = deadline.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  String _formatRemaining(Duration remaining) {
    if (remaining.inHours >= 1) {
      return '${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m';
    }
    return '${remaining.inMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isAccepted = offer.status == OfferStatus.accepted;
    final isCompleted = offer.status == OfferStatus.completed;
    // Still shows green once the checkout window has expired would read as
    // "good to go" when it's actually the opposite - only true while a
    // payment can still happen. Completed (payment already made) is its
    // own success state regardless of the window.
    final isPayable = isAccepted && !_isCheckoutWindowExpired;
    final isSuccessLook = isPayable || isCompleted;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isSuccessLook
            ? AppColors.success.withValues(alpha: 0.15)
            : AppColors.accent.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: isSuccessLook ? AppColors.success : AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Round ${offer.roundNumber} offer',
            style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            Formatters.currency(offer.amount),
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (offer.isLowball && offer.status == OfferStatus.pending) ...[
            const SizedBox(height: 4),
            Text(
              'Below 30% of the asking price',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.error,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 6),
          if (isCompleted) ...[
            Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success, size: 18),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Payment received — order placed',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (offer.orderId != null) ...[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onViewOrder,
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.success),
                  child: const Text('View Order'),
                ),
              ),
            ],
          ] else if (isAccepted && _isCheckoutWindowExpired)
            Text(
              'Checkout window expired — this offer can no longer be paid.',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            )
          else if (isAccepted) ...[
            Text(
              'You agreed on ${Formatters.currency(offer.amount)} — pay now',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_timeRemaining case final remaining?) ...[
              const SizedBox(height: 2),
              Text(
                'Pay within ${_formatRemaining(remaining)} or this offer expires.',
                style: textTheme.bodySmall?.copyWith(color: AppColors.error),
              ),
            ],
            if (_isBuyer) ...[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onPayNow,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                  child: const Text('Pay now'),
                ),
              ),
            ],
          ] else
            Text(_statusLabel, style: textTheme.bodySmall),
          if (offer.status == OfferStatus.pending && _isResponder) ...[
            const SizedBox(height: AppSpacing.sm),
            // Two rows, not three Expanded buttons in one - "Decline"/
            // "Counter" wrapped onto two lines each when squeezed a third
            // of this card's width, which also wraps at ~80% screen width.
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCounter,
                    child: const Text('Counter'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAccept,
                child: const Text('Accept'),
              ),
            ),
          ],
          if (offer.status == OfferStatus.pending && _isProposer && offer.initiatedBy == OfferParty.buyer) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onRetract,
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Retract offer'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
