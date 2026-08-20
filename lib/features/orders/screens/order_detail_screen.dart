import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/dispute.dart';
import '../../../shared/models/lga.dart';
import '../../../shared/models/order.dart';
import '../../../shared/models/review.dart';
import '../../../shared/models/user.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/lga_provider.dart';
import '../../checkout/providers/delivery_addresses_provider.dart';
import '../../trust/providers/reviews_provider.dart';
import '../providers/orders_provider.dart';

const _disputeStatusHints = {
  DisputeStatus.open: 'Awaiting the seller to respond.',
  DisputeStatus.selfResolving: 'The seller responded - awaiting your decision.',
  DisputeStatus.adminReview: 'Under review by our support team - no action needed from you.',
  DisputeStatus.resolvedRefund: 'Resolved - you were refunded in full.',
  DisputeStatus.resolvedRelease: 'Resolved - payment was released to the seller.',
  DisputeStatus.resolvedPartial: 'Resolved - a partial refund was issued.',
};

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  Order? _order;
  bool _isLoading = true;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final order = await ref.read(ordersProvider.notifier).getOrder(widget.orderId);
      if (!mounted) return;
      setState(() => _order = order);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessageFrom(e, fallback: 'Could not load this order.'))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _runAction(Future<Order> Function() action) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);

    try {
      final order = await action();
      if (mounted) setState(() => _order = order);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessageFrom(e, fallback: 'Could not complete that.')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<String?> _promptText(String title, {String? hint}) {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, autofocus: true, decoration: InputDecoration(hintText: hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  /// A real courier booking needs the seller's pickup address, which
  /// doesn't exist until they set one - never a hard block, "Skip for
  /// now" just means booking falls back to the existing manual tracking-
  /// reference flow, same as if this prompt never existed.
  Future<void> _markPrepared() async {
    final order = _order;
    final needsPickupAddress = order != null &&
        order.deliveryTier != DeliveryTier.pickup &&
        ref.read(authProvider).value?.pickupAddress == null;

    if (needsPickupAddress) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const _PickupAddressPromptSheet(),
      );
      if (!mounted) return;
    }

    await _runAction(() => ref.read(ordersProvider.notifier).markPrepared(widget.orderId));
  }

  Future<void> _markInTransit() async {
    final tracking = await _promptText('Tracking reference', hint: 'e.g. GIG123456');
    if (tracking == null || tracking.isEmpty) return;

    await _runAction(
      () => ref.read(ordersProvider.notifier).markInTransit(widget.orderId, trackingReference: tracking),
    );
  }

  Future<void> _confirmDelivery() async {
    final code = await _promptText('Enter the buyer\'s pickup code');
    if (code == null || code.isEmpty) return;

    await _runAction(() => ref.read(ordersProvider.notifier).confirmDelivery(widget.orderId, code));
  }

  Future<void> _markDelivered() {
    return _runAction(() => ref.read(ordersProvider.notifier).markDelivered(widget.orderId));
  }

  Future<void> _confirmReceipt() {
    return _runAction(() => ref.read(ordersProvider.notifier).confirmReceipt(widget.orderId));
  }

  Future<void> _cancel() {
    return _runAction(() => ref.read(ordersProvider.notifier).cancel(widget.orderId));
  }

  /// The create endpoint returns just the Review, not the whole Order -
  /// refetching afterward is what actually updates the local `_order`
  /// copy (via `reviews`), same _runAction plumbing every other action
  /// on this screen already uses.
  Future<void> _leaveReview() async {
    final result = await showModalBottomSheet<_ReviewSubmission>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _LeaveReviewSheet(),
    );
    if (result == null) return;

    await _runAction(() async {
      await ref.read(reviewsServiceProvider).create(
            widget.orderId,
            rating: result.rating,
            comment: result.comment,
          );
      return ref.read(ordersProvider.notifier).getOrder(widget.orderId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final currentUserId = ref.watch(authProvider).value?.id;
    final isBuyer = order?.buyer?.id == currentUserId;
    final isSeller = order?.seller?.id == currentUserId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Order')),
      body: _isLoading || order == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The "just paid/confirmed" moment - the freshest an
                    // order ever is, so it gets its own celebratory
                    // treatment instead of jumping straight into the
                    // ordinary tracking view every other status uses.
                    if (order.status == OrderStatus.confirmed) ...[
                      _SuccessHeader(order: order, isBuyer: isBuyer),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    Text(
                      order.listing?.title ?? 'Order',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      Formatters.currency(order.totalAmount),
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _OtherPartyRow(
                      label: isBuyer ? 'Seller' : 'Buyer',
                      otherParty: isBuyer ? order.seller : order.buyer,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _StatusTimeline(order: order),
                    if (order.escrowStatus == EscrowStatus.held) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _Banner(
                        icon: Icons.shield_outlined,
                        text: isBuyer
                            ? "Your money is safe with us. We won't pay the seller until "
                                "you confirm you've received your item."
                            : "The buyer's payment is safe with us. You'll be paid once "
                                "they confirm they've received their item.",
                        color: AppColors.success,
                      ),
                    ],
                    if (order.deliveryTier == DeliveryTier.pickup &&
                        order.status != OrderStatus.pending &&
                        order.status != OrderStatus.cancelled) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _MeetupCard(otherParty: isBuyer ? order.seller : order.buyer, isBuyer: isBuyer),
                    ],
                    if (isBuyer &&
                        order.pickupCode != null &&
                        order.deliveryTier == DeliveryTier.pickup) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _PickupCodeCard(code: order.pickupCode!),
                    ],
                    if (order.trackingReference != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Tracking: ${order.trackingReference}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    ..._actionsFor(order, isBuyer: isBuyer, isSeller: isSeller),
                  ],
                ),
              ),
            ),
    );
  }

  List<Widget> _actionsFor(Order order, {required bool isBuyer, required bool isSeller}) {
    final buttons = <Widget>[];

    if (isSeller && order.status == OrderStatus.confirmed) {
      buttons.add(_actionButton('Mark Prepared', _markPrepared));
    }

    if (isSeller && order.status == OrderStatus.prepared) {
      buttons.add(
        _actionButton(
          order.deliveryTier == DeliveryTier.pickup ? 'Confirm Delivery' : 'Mark In Transit',
          order.deliveryTier == DeliveryTier.pickup ? _confirmDelivery : _markInTransit,
        ),
      );
    }

    if (isBuyer && order.status == OrderStatus.inTransit && order.deliveryTier != DeliveryTier.pickup) {
      buttons.add(_actionButton('Mark as Delivered', _markDelivered));
    }

    if (order.status == OrderStatus.delivered && order.activeDispute != null) {
      // Both parties need to reach this - the seller is the one who
      // actually has to respond to it (see DisputeDetailScreen's
      // isSeller-gated Respond button), not just the buyer who raised it.
      buttons.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            _disputeStatusHints[order.activeDispute!.status] ?? '',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ),
      );
      buttons.add(
        _outlinedButton(
          'View Dispute',
          () => context.push('/disputes/${order.activeDispute!.id}'),
        ),
      );
    } else if (isBuyer && order.status == OrderStatus.delivered) {
      buttons.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            "Confirming releases payment to the seller right away and can't be undone. "
            "If something's wrong with your item, raise a dispute instead - not after confirming.",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ),
      );
      buttons.add(_actionButton('Confirm Receipt', _confirmReceipt));
      buttons.add(
        _outlinedButton(
          'Raise a Dispute',
          () => context.push('/orders/${order.id}/dispute/raise'),
          color: AppColors.error,
        ),
      );
    }

    if (order.status == OrderStatus.completed) {
      final currentUserId = ref.read(authProvider).value?.id;
      final myReview = order.myReview(currentUserId);
      final theirReview = order.theirReview(currentUserId);

      if (myReview != null) {
        buttons.add(_ReviewCard(title: 'Your review', review: myReview));
      } else {
        buttons.add(_outlinedButton('Leave a Review', _leaveReview));
      }

      if (theirReview != null) {
        buttons.add(
          _ReviewCard(
            title: isBuyer ? "The seller's review of you" : "The buyer's review of you",
            review: theirReview,
          ),
        );
      }
    }

    if (isBuyer && order.status == OrderStatus.pending) {
      buttons.add(
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isBusy ? null : _cancel,
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Cancel Order'),
            ),
          ),
        ),
      );
    }

    return buttons;
  }

  Widget _actionButton(String label, Future<void> Function() onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isBusy ? null : onPressed,
          child: Text(label),
        ),
      ),
    );
  }

  Widget _outlinedButton(String label, VoidCallback onPressed, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: _isBusy ? null : onPressed,
          style: color != null ? OutlinedButton.styleFrom(foregroundColor: color) : null,
          child: Text(label),
        ),
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.order});

  final Order order;

  static const _pickupSteps = [
    OrderStatus.pending,
    OrderStatus.confirmed,
    OrderStatus.prepared,
    OrderStatus.delivered,
    OrderStatus.completed,
  ];

  static const _courierSteps = [
    OrderStatus.pending,
    OrderStatus.confirmed,
    OrderStatus.prepared,
    OrderStatus.inTransit,
    OrderStatus.delivered,
    OrderStatus.completed,
  ];

  @override
  Widget build(BuildContext context) {
    if (order.status == OrderStatus.cancelled) {
      return Text(
        'Order cancelled',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.error),
      );
    }

    final steps = order.deliveryTier == DeliveryTier.pickup ? _pickupSteps : _courierSteps;
    final currentIndex = steps.indexOf(order.status);

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        for (var i = 0; i < steps.length; i++)
          Chip(
            label: Text(_label(steps[i])),
            backgroundColor: i <= currentIndex
                ? AppColors.primary
                : AppColors.accent.withValues(alpha: 0.3),
            labelStyle: TextStyle(
              color: i <= currentIndex ? AppColors.surface : AppColors.textMuted,
              fontWeight: i == currentIndex ? FontWeight.bold : FontWeight.normal,
            ),
          ),
      ],
    );
  }

  String _label(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Payment';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.prepared:
        return 'Prepared';
      case OrderStatus.inTransit:
        return 'In transit';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class _SuccessHeader extends StatelessWidget {
  const _SuccessHeader({required this.order, required this.isBuyer});

  final Order order;
  final bool isBuyer;

  String get _subtitle {
    final isOnline = order.paymentMethod == PaymentMethod.online;

    if (isBuyer) {
      return isOnline
          ? 'Your payment was successful.'
          : 'Your cash-on-delivery order is confirmed.';
    }

    return isOnline
        ? "Payment received — time to prepare the buyer's order."
        : 'Order confirmed - cash on delivery. Time to prepare it.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: AppColors.surface, size: 32),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            isBuyer ? 'Order placed!' : 'New sale!',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppColors.success),
          ),
          const SizedBox(height: 4),
          Text(
            _subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          // Reached via context.go() from checkout, not push() - there's
          // no back button to fall back on, so this is the only way
          // forward from a fresh success screen. Stacked full-width, not
          // side by side - "Continue Shopping" wrapped onto two lines
          // when squeezed into half the row, throwing off the button's
          // height next to the single-line "View My Orders".
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/orders'),
                  child: const Text('View My Orders'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Continue Shopping'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: TextStyle(color: color))),
        ],
      ),
    );
  }
}

/// Structurally mirrors checkout_screen.dart's _AddAddressSheet - same
/// LGA autocomplete + landmark/address/phone fields - but saves the new
/// address AND immediately sets it as the seller's pickup address, with
/// an explicit "Skip for now" escape hatch since this is never a hard
/// requirement to mark an order prepared.
class _PickupAddressPromptSheet extends ConsumerStatefulWidget {
  const _PickupAddressPromptSheet();

  @override
  ConsumerState<_PickupAddressPromptSheet> createState() => _PickupAddressPromptSheetState();
}

class _PickupAddressPromptSheetState extends ConsumerState<_PickupAddressPromptSheet> {
  final _landmarkController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  Lga? _selectedLga;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _landmarkController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _selectedLga != null &&
      _landmarkController.text.trim().isNotEmpty &&
      _addressController.text.trim().isNotEmpty &&
      _phoneController.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (_isSubmitting || !_isValid) return;
    setState(() => _isSubmitting = true);

    try {
      final address = await ref.read(deliveryAddressesProvider.notifier).create(
            lgaId: _selectedLga!.id,
            landmark: _landmarkController.text.trim(),
            fullAddress: _addressController.text.trim(),
            recipientPhone: _phoneController.text.trim(),
          );
      await ref.read(authProvider.notifier).setPickupAddress(address.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessageFrom(e, fallback: 'Could not save this address.'))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lgasAsync = ref.watch(lgaListProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add a pickup address', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "So we can book a real courier for this delivery. You can skip this and arrange delivery yourself instead.",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          lgasAsync.when(
            data: (lgas) => Autocomplete<Lga>(
              displayStringForOption: (lga) => '${lga.name}, ${lga.state}',
              optionsBuilder: (value) {
                if (value.text.isEmpty) return const Iterable<Lga>.empty();
                return lgas.where(
                  (lga) => lga.name.toLowerCase().contains(value.text.toLowerCase()),
                );
              },
              onSelected: (lga) => setState(() => _selectedLga = lga),
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(hintText: 'Search your LGA'),
                );
              },
            ),
            loading: () => const LinearProgressIndicator(),
            error: (error, stack) => const Text('Could not load LGAs.'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _landmarkController,
            decoration: const InputDecoration(hintText: 'Landmark (e.g. Near the big mango tree)'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _addressController,
            maxLines: 2,
            decoration: const InputDecoration(hintText: 'Full pickup address'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(hintText: 'Contact phone number for pickup'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isValid && !_isSubmitting ? _submit : null,
              child: Text(_isSubmitting ? 'Saving…' : 'Save & Continue'),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Center(
            child: TextButton(
              onPressed: _isSubmitting ? null : () => Navigator.pop(context),
              child: const Text('Skip for now'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pickup tier has no shipping address at all - the doc's own masked-
/// address design only ever decrypts a buyer's full address for a
/// logistics rider, and Pickup has none. Coordinating an in-person
/// handoff needs *some* location context, so this surfaces the LGA/
/// landmark already on the other party's profile (never a precise
/// street address, matching the masking principle) plus a phone number -
/// safe to share here specifically because the order already exists
/// (payment secured/escrowed or COD), unlike the pre-sale chat context
/// where sharing a phone number is a contact-leak risk.
/// Makes the other party's profile (and whatever reviews they've
/// received - from this order or any other) reachable from every order,
/// not just Pickup-tier ones like _MeetupCard below. This is what
/// actually makes a seller's review of a buyer visible to "other users"
/// in any meaningful sense - a buyer has no browsable public listing of
/// their own, so the only real discovery path for their reputation is
/// the next seller who transacts with them tapping through from here.
class _OtherPartyRow extends StatelessWidget {
  const _OtherPartyRow({required this.label, required this.otherParty});

  final String label;
  final User? otherParty;

  @override
  Widget build(BuildContext context) {
    final party = otherParty;
    if (party == null) return const SizedBox.shrink();

    return InkWell(
      onTap: () => context.push('/profile/${party.id}'),
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(
              '$label: ',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
            Expanded(
              child: Text(
                party.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _MeetupCard extends StatelessWidget {
  const _MeetupCard({required this.otherParty, required this.isBuyer});

  final User? otherParty;
  final bool isBuyer;

  @override
  Widget build(BuildContext context) {
    final party = otherParty;
    if (party == null) return const SizedBox.shrink();

    final location = [party.landmark, party.lga].where((s) => s != null && s.isNotEmpty).join(', ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isBuyer ? 'Meet the seller' : 'Meet the buyer',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(party.name, style: Theme.of(context).textTheme.titleMedium),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Expanded(child: Text(location, style: Theme.of(context).textTheme.bodyMedium)),
              ],
            ),
          ],
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.call_outlined, size: 16, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(party.phone, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.title, required this.review});

  final String title;
  final Review review;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: 4),
            Text(
              '${'★' * review.rating}${'☆' * (5 - review.rating)}',
              style: const TextStyle(color: AppColors.primary),
            ),
            if (review.comment != null) ...[
              const SizedBox(height: 4),
              Text(review.comment!, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

class _PickupCodeCard extends StatelessWidget {
  const _PickupCodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your pickup code',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            code,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 4),
          ),
          const SizedBox(height: 4),
          Text(
            'Show this to the seller in person to confirm pickup.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ReviewSubmission {
  const _ReviewSubmission({required this.rating, this.comment});

  final int rating;
  final String? comment;
}

class _LeaveReviewSheet extends StatefulWidget {
  const _LeaveReviewSheet();

  @override
  State<_LeaveReviewSheet> createState() => _LeaveReviewSheetState();
}

class _LeaveReviewSheetState extends State<_LeaveReviewSheet> {
  final _commentController = TextEditingController();
  int _rating = 5;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Leave a Review', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starValue = index + 1;
              return IconButton(
                onPressed: () => setState(() => _rating = starValue),
                icon: Icon(
                  starValue <= _rating ? Icons.star : Icons.star_border,
                  color: AppColors.primary,
                  size: 32,
                ),
              );
            }),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Add a comment (optional)'),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(
                context,
                _ReviewSubmission(
                  rating: _rating,
                  comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
                ),
              ),
              child: const Text('Submit Review'),
            ),
          ),
        ],
      ),
    );
  }
}
