import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../providers/discovery_provider.dart';
import '../widgets/saveable_listing_card.dart';
import 'filter_sheet.dart';

/// The dedicated "browse everything" page - search, filter, sort, and the
/// full paginated catalog, all on one screen where filtering it actually
/// changes the whole page. Previously this lived inline on the Home
/// screen alongside the "Fresh Finds"/"Trending" rails, which don't react
/// to those filters - making the page look half-broken every time a
/// filter was applied. Uses the same [discoveryFeedProvider]/
/// [discoveryFiltersProvider] Home used, unchanged - just relocated.
class BrowseAllScreen extends ConsumerStatefulWidget {
  const BrowseAllScreen({super.key});

  @override
  ConsumerState<BrowseAllScreen> createState() => _BrowseAllScreenState();
}

class _BrowseAllScreenState extends ConsumerState<BrowseAllScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchSubmitted(String value) {
    final trimmed = value.trim();
    final current = ref.read(discoveryFiltersProvider);
    ref.read(discoveryFiltersProvider.notifier).state = current.copyWith(
      q: trimmed.isEmpty ? null : trimmed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(discoveryFeedProvider);
    final filters = ref.watch(discoveryFiltersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Browse')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(discoveryFeedProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _onSearchSubmitted,
                    decoration: const InputDecoration(
                      hintText: 'Search listings',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton.filled(
                  onPressed: () => showFilterSheet(context),
                  icon: const Icon(Icons.tune),
                  style: IconButton.styleFrom(
                    backgroundColor: filters.hasActiveFilters
                        ? AppColors.primary
                        : AppColors.accent.withValues(alpha: 0.4),
                    foregroundColor: filters.hasActiveFilters
                        ? AppColors.surface
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            feedAsync.when(
              data: (feedState) {
                if (feedState.listings.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xl,
                    ),
                    child: Center(
                      child: Text(
                        'No listings match your filters yet.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                        ),
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
                                    .read(discoveryFeedProvider.notifier)
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
