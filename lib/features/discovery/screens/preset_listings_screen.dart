import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../models/discovery_filters.dart';
import '../providers/discovery_provider.dart';
import '../widgets/saveable_listing_card.dart';

/// The "See all" destination for a Home-screen preset rail (Fresh Finds,
/// Trending) - same grid/load-more shape as the Home screen's own "Browse
/// all" section, just scoped to a fixed [filters] preset instead of the
/// mutable global filter state.
class PresetListingsScreen extends ConsumerWidget {
  const PresetListingsScreen({super.key, required this.title, required this.filters});

  final String title;
  final DiscoveryFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(presetFeedProvider(filters));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title)),
      body: RefreshIndicator(
        onRefresh: () => ref.read(presetFeedProvider(filters).notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            feedAsync.when(
              data: (feedState) {
                if (feedState.listings.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Center(
                      child: Text(
                        'No listings here yet.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.textMuted),
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
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
                      itemCount: feedState.listings.length,
                      itemBuilder: (context, index) => SaveableListingCard(
                        listing: feedState.listings[index],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (feedState.hasMore)
                      Center(
                        child: feedState.isLoadingMore
                            ? const CircularProgressIndicator()
                            : OutlinedButton(
                                onPressed: () => ref
                                    .read(presetFeedProvider(filters).notifier)
                                    .loadMore(),
                                child: const Text('Load more'),
                              ),
                      ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(
                  child: Text(
                    'Could not load listings. Pull down to try again.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.error),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
