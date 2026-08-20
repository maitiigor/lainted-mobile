import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/models/listing.dart';
import '../providers/recently_viewed_provider.dart';
import '../providers/saved_listings_provider.dart';
import '../widgets/saveable_listing_card.dart';

/// One route (not two, not a bottom-nav slot) for both "saved" and
/// "recently viewed" - nobody asked for nav restructuring, and these two
/// lists are small/related enough to share a single tabbed screen.
class SavedAndRecentScreen extends StatelessWidget {
  const SavedAndRecentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Saved & Recently Viewed'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Saved'), Tab(text: 'Recently Viewed')],
          ),
        ),
        body: const TabBarView(
          children: [_SavedTab(), _RecentlyViewedTab()],
        ),
      ),
    );
  }
}

class _SavedTab extends ConsumerWidget {
  const _SavedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(savedListingsProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(savedListingsProvider.notifier).refresh(),
      child: savedAsync.when(
        data: (listings) => _ListingGrid(
          listings: listings,
          emptyMessage: 'Nothing saved yet. Tap the heart on a listing to save it.',
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => const _ErrorMessage(
          message: 'Could not load saved listings. Pull down to try again.',
        ),
      ),
    );
  }
}

class _RecentlyViewedTab extends ConsumerWidget {
  const _RecentlyViewedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentlyViewedProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(recentlyViewedProvider.future),
      child: recentAsync.when(
        data: (listings) => _ListingGrid(
          listings: listings,
          emptyMessage: 'Listings you view will show up here.',
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => const _ErrorMessage(
          message: 'Could not load recently viewed listings. Pull down to try again.',
        ),
      ),
    );
  }
}

class _ListingGrid extends StatelessWidget {
  const _ListingGrid({required this.listings, required this.emptyMessage});

  final List<Listing> listings;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (listings.isEmpty) {
      return ListView(
        // A scrollable ancestor is required for RefreshIndicator's
        // pull-to-refresh gesture to register on an otherwise-empty body.
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: Center(
              child: Text(
                emptyMessage,
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

    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.72,
      ),
      itemCount: listings.length,
      itemBuilder: (context, index) =>
          SaveableListingCard(listing: listings[index]),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.error),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
