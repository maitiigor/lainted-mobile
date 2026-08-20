import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/listing.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/listing_card.dart';
import '../../../shared/widgets/stat_tile.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/listings_provider.dart';
import '../providers/wardrobe_stats_provider.dart';

class MyListingsScreen extends ConsumerWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(myListingsProvider);
    final isPersonalSeller = ref.watch(authProvider).value?.sellerType == SellerType.personal;

    // Personal sellers get the 3-step wardrobe wizard for new listings;
    // business sellers keep the full form - editing is unaffected either
    // way, see ListingFormScreen.
    final createRoute = isPersonalSeller ? '/listings/create/wardrobe' : '/listings/create';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('My Listings')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(createRoute),
        child: const Icon(Icons.add),
      ),
      body: listingsAsync.when(
        data: (listings) {
          if (listings.isEmpty) {
            return _EmptyState(onCreate: () => context.push(createRoute));
          }

          final groups = <ListingStatus, List<Listing>>{};
          for (final listing in listings) {
            groups.putIfAbsent(listing.status, () => []).add(listing);
          }

          const order = [
            ListingStatus.draft,
            ListingStatus.active,
            ListingStatus.sold,
            ListingStatus.expired,
            ListingStatus.removed,
          ];

          return RefreshIndicator(
            onRefresh: () => ref.read(myListingsProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                if (isPersonalSeller) ...[
                  const _WardrobeStatsRow(),
                  const SizedBox(height: AppSpacing.lg),
                ],
                for (final status in order)
                  if (groups[status] != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text(
                        _statusLabel(status),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: AppSpacing.sm,
                            crossAxisSpacing: AppSpacing.sm,
                            childAspectRatio: 0.72,
                          ),
                      itemCount: groups[status]!.length,
                      itemBuilder: (context, index) {
                        final listing = groups[status]![index];
                        return ListingCard(
                          listing: listing,
                          onTap: () =>
                              context.push('/listings/${listing.id}'),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Could not load your listings. Pull down to try again.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.error),
            ),
          ),
        ),
      ),
    );
  }

  String _statusLabel(ListingStatus status) {
    return switch (status) {
      ListingStatus.draft => 'Drafts',
      ListingStatus.active => 'Active',
      ListingStatus.sold => 'Sold',
      ListingStatus.expired => 'Expired',
      ListingStatus.removed => 'Removed',
    };
  }
}

class _WardrobeStatsRow extends ConsumerWidget {
  const _WardrobeStatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(wardrobeStatsProvider);

    return statsAsync.when(
      data: (stats) => Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            StatTile(label: 'Listed', value: '${stats.itemsListed}'),
            StatTile(label: 'Sold', value: '${stats.itemsSold}'),
            StatTile(label: 'Earned', value: Formatters.currency(stats.totalEarned)),
          ],
        ),
      ),
      loading: () => const SizedBox(height: 64, child: Center(child: CircularProgressIndicator())),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 56,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Nothing listed yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Create your first listing to start selling.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: onCreate,
              child: const Text('Create a listing'),
            ),
          ],
        ),
      ),
    );
  }
}
