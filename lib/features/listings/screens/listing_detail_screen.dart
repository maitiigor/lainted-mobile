import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/listing.dart';
import '../../../shared/models/user.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/providers/chat_provider.dart';
import '../../chat/providers/conversations_provider.dart';
import '../../chat/widgets/make_offer_sheet.dart';
import '../../discovery/providers/saved_listings_provider.dart';
import '../../trust/widgets/report_sheet.dart';
import '../providers/listings_provider.dart';

class ListingDetailScreen extends ConsumerStatefulWidget {
  const ListingDetailScreen({super.key, required this.listingId});

  final String listingId;

  @override
  ConsumerState<ListingDetailScreen> createState() =>
      _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  Listing? _listing;
  bool _isLoading = true;
  bool _isBusy = false;
  bool _isMessaging = false;
  bool _isMakingOffer = false;
  int _photoIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final listing = await ref
          .read(myListingsProvider.notifier)
          .getListing(widget.listingId);
      if (!mounted) return;
      setState(() => _listing = listing);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessageFrom(e, fallback: 'Could not load this listing.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markSold() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await ref.read(myListingsProvider.notifier).markSold(widget.listingId);
      await _load();
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _messageSeller() async {
    if (_isMessaging) return;
    setState(() => _isMessaging = true);

    try {
      final conversation = await ref
          .read(conversationsProvider.notifier)
          .startConversation(widget.listingId);
      if (!mounted) return;
      context.push('/chat/${conversation.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessageFrom(e, fallback: 'Could not start a conversation.')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isMessaging = false);
    }
  }

  Future<void> _makeOffer() async {
    final listing = _listing;
    if (_isMakingOffer || listing == null) return;

    final amount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (_) => MakeOfferSheet(listingPrice: listing.price, title: 'Make an offer'),
    );
    if (amount == null) return;
    if (!mounted) return;

    setState(() => _isMakingOffer = true);
    try {
      final conversation = await ref
          .read(conversationsProvider.notifier)
          .startConversation(widget.listingId);
      await ref.read(chatProvider(conversation.id).notifier).makeOffer(amount);
      if (!mounted) return;
      context.push('/chat/${conversation.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessageFrom(e, fallback: 'Could not send that offer.')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isMakingOffer = false);
    }
  }

  void _buyNow(Listing listing) {
    context.push('/checkout/listing', extra: listing);
  }

  Future<void> _delete() async {
    if (_isBusy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this listing?'),
        content: const Text('This will take it off the marketplace.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isBusy = true);
    try {
      await ref
          .read(myListingsProvider.notifier)
          .deleteListing(widget.listingId);
      if (!mounted) return;
      context.pop();
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listing = _listing;
    final currentUserId = ref.watch(authProvider).value?.id;
    final isOwner = listing != null && listing.seller?.id == currentUserId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(listing?.title ?? 'Listing'),
        actions: listing == null
            ? null
            : isOwner
            ? [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () =>
                      context.push('/listings/${listing.id}/edit'),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _isBusy ? null : _delete,
                ),
              ]
            : [
                Consumer(
                  builder: (context, ref, _) {
                    final isSaved = ref
                        .watch(savedListingIdsProvider)
                        .contains(listing.id);

                    return IconButton(
                      icon: Icon(
                        isSaved ? Icons.favorite : Icons.favorite_border,
                        color: isSaved ? AppColors.error : null,
                      ),
                      onPressed: () => ref
                          .read(savedListingsProvider.notifier)
                          .toggleSave(listing),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.flag_outlined),
                  tooltip: 'Report listing',
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => ReportSheet(reportableType: 'listing', reportableId: listing.id),
                  ),
                ),
              ],
      ),
      body: _isLoading || listing == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (listing.photos.isEmpty)
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMd,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.image_outlined,
                            size: 48,
                            color: AppColors.textMuted,
                          ),
                        ),
                      )
                    else ...[
                      SizedBox(
                        height: 220,
                        child: Stack(
                          children: [
                            PageView(
                              onPageChanged: (index) =>
                                  setState(() => _photoIndex = index),
                              children: [
                                for (final photo in listing.photos)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusMd,
                                    ),
                                    child: Image.network(
                                      photo.url,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                              ],
                            ),
                            if (listing.photos.length > 1)
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: AppSpacing.xs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                                  ),
                                  child: Text(
                                    '${_photoIndex + 1} / ${listing.photos.length}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppColors.surface,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (listing.photos.length > 1) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < listing.photos.length; i++)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: i == _photoIndex
                                        ? AppColors.primary
                                        : AppColors.accent,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gradeColor(listing.conditionGrade),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            listing.conditionGrade,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.surface,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          listing.status.name.toUpperCase(),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      listing.title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      Formatters.currency(listing.price),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(color: AppColors.primary),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      listing.description,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (listing.categoryName != null)
                      _DetailRow(label: 'Category', value: listing.categoryName!),
                    if (listing.size != null)
                      _DetailRow(label: 'Size', value: listing.size!),
                    if (listing.lga != null)
                      _DetailRow(
                        label: 'Location',
                        value: [
                          listing.landmark,
                          listing.lga,
                        ].whereType<String>().join(', '),
                      ),
                    if (listing.isBale)
                      _DetailRow(
                        label: 'Bale',
                        value:
                            '${listing.baleType?.name ?? ''} - '
                            '${listing.baleItemCount ?? '?'} items from '
                            '${listing.baleOriginCountry ?? '?'}',
                      ),
                    if (!isOwner && listing.seller != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _SellerRow(seller: listing.seller!),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    if (isOwner && listing.status == ListingStatus.draft)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () =>
                              context.push('/listings/${listing.id}/photos'),
                          child: const Text('Finish setup & publish'),
                        ),
                      ),
                    if (isOwner && listing.status == ListingStatus.active)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _isBusy ? null : _markSold,
                          child: const Text('Mark as sold'),
                        ),
                      ),
                    if (!isOwner && listing.status == ListingStatus.active) ...[
                      if (listing.isNegotiable) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isMakingOffer ? null : _makeOffer,
                            icon: const Icon(Icons.local_offer_outlined),
                            label: Text(
                              _isMakingOffer ? 'Sending…' : 'Make Offer',
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _buyNow(listing),
                            icon: const Icon(Icons.shopping_bag_outlined),
                            label: const Text('Buy Now'),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isMessaging ? null : _messageSeller,
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: Text(
                            _isMessaging ? 'Starting…' : 'Message Seller',
                          ),
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

class _SellerRow extends StatelessWidget {
  const _SellerRow({required this.seller});

  final User seller;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/profile/${seller.id}'),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.accent,
              backgroundImage: seller.photoUrl != null ? NetworkImage(seller.photoUrl!) : null,
              child: seller.photoUrl == null
                  ? Text(seller.name.isNotEmpty ? seller.name[0].toUpperCase() : '?')
                  : null,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(seller.name, style: Theme.of(context).textTheme.bodyMedium),
                  if (seller.rating != null)
                    Text(
                      '★ ${seller.rating!.toStringAsFixed(1)} · ${seller.totalSales} sales',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
