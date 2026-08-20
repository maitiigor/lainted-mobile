import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/dispute.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/disputes_provider.dart';
import '../widgets/respond_to_dispute_sheet.dart';

const _disputeTypeLabels = {
  DisputeType.notReceived: "Item not received",
  DisputeType.gradeMismatch: "Doesn't match the listed grade",
  DisputeType.wrongItem: 'Wrong item received',
  DisputeType.itemDamaged: 'Item arrived damaged',
  DisputeType.sellerNoShow: "Seller didn't show up for pickup",
  DisputeType.other: 'Other',
};

const _statusLabels = {
  DisputeStatus.open: 'Awaiting seller response',
  DisputeStatus.selfResolving: 'Seller responded - awaiting your decision',
  DisputeStatus.adminReview: 'Under review by our support team',
  DisputeStatus.resolvedRefund: 'Resolved - full refund issued',
  DisputeStatus.resolvedRelease: 'Resolved - payment released to seller',
  DisputeStatus.resolvedPartial: 'Resolved - partial refund issued',
};

class DisputeDetailScreen extends ConsumerStatefulWidget {
  const DisputeDetailScreen({super.key, required this.disputeId});

  final String disputeId;

  @override
  ConsumerState<DisputeDetailScreen> createState() => _DisputeDetailScreenState();
}

class _DisputeDetailScreenState extends ConsumerState<DisputeDetailScreen> {
  Dispute? _dispute;
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
      final dispute = await ref.read(disputesProvider.notifier).getDispute(widget.disputeId);
      if (!mounted) return;
      setState(() => _dispute = dispute);
    } catch (e) {
      if (!mounted) return;
      _showError(errorMessageFrom(e, fallback: 'Could not load this dispute.'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _runAction(Future<Dispute> Function() action) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);

    try {
      final dispute = await action();
      if (mounted) setState(() => _dispute = dispute);
    } catch (e) {
      if (!mounted) return;
      _showError(errorMessageFrom(e, fallback: 'Could not complete that.'));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _respond() async {
    final result = await showModalBottomSheet<RespondToDisputeResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const RespondToDisputeSheet(),
    );
    if (result == null) return;

    await _runAction(
      () => ref.read(disputesProvider.notifier).respond(
            widget.disputeId,
            sellerStatement: result.statement,
            selfResolutionOffered: result.offerAmount,
          ),
    );
  }

  Future<void> _accept() {
    return _runAction(() => ref.read(disputesProvider.notifier).acceptResolution(widget.disputeId));
  }

  Future<void> _reject() {
    return _runAction(() => ref.read(disputesProvider.notifier).rejectResolution(widget.disputeId));
  }

  @override
  Widget build(BuildContext context) {
    final dispute = _dispute;
    final currentUserId = ref.watch(authProvider).value?.id;
    final isBuyer = dispute?.raisedBy?.id == currentUserId;
    final isSeller = dispute != null && !isBuyer;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Dispute')),
      body: _isLoading || dispute == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (dispute.orderListingTitle != null) ...[
                      Text(dispute.orderListingTitle!, style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                    Text(
                      _disputeTypeLabels[dispute.disputeType]!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _StatusBanner(dispute: dispute),
                    if (dispute.status == DisputeStatus.adminReview) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        "Our support team is reviewing the statements and photos from both sides. "
                        "There's no set timeline for this yet, but we'll notify you the moment it's "
                        "resolved - no action is needed from you right now.",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Text('Buyer statement', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(dispute.buyerStatement),
                    if (dispute.buyerPhotos.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _PhotoRow(urls: dispute.buyerPhotos),
                    ],
                    if (dispute.sellerStatement != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text('Seller response', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(dispute.sellerStatement!),
                      if (dispute.sellerPhotos.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _PhotoRow(urls: dispute.sellerPhotos),
                      ],
                    ],
                    if (dispute.selfResolutionOffered != null && dispute.status == DisputeStatus.selfResolving) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Seller offered a refund of ${Formatters.currency(dispute.selfResolutionOffered!)}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            if (isBuyer) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _isBusy ? null : _reject,
                                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                                      child: const Text('Reject - escalate'),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _isBusy ? null : _accept,
                                      child: const Text('Accept'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (dispute.adminNotes != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text('Support notes', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(dispute.adminNotes!),
                    ],
                    if (isSeller && dispute.status == DisputeStatus.open) ...[
                      const SizedBox(height: AppSpacing.xl),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isBusy ? null : _respond,
                          child: const Text('Respond'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.dispute});

  final Dispute dispute;

  @override
  Widget build(BuildContext context) {
    final color = dispute.isResolved ? AppColors.success : AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Text(
        _statusLabels[dispute.status]!,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _PhotoRow extends StatelessWidget {
  const _PhotoRow({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) => ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: Image.network(urls[index], width: 72, height: 72, fit: BoxFit.cover),
        ),
      ),
    );
  }
}
