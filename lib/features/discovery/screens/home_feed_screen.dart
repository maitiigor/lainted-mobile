import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../models/discovery_filters.dart';
import '../providers/discovery_provider.dart';
import '../widgets/saveable_listing_card.dart';

const _freshFinds = DiscoveryFilters(isWardrobeCleanout: true, sort: 'newest');
const _trending = DiscoveryFilters(sort: 'popular');

/// Curated landing page - "Fresh Finds"/"Trending" rails plus a search
/// entry point into the dedicated Browse page. Deliberately has no filter
/// UI or full grid of its own: those used to live here, but a filter only
/// affecting part of the page (the grid, not the static rails above it)
/// made the whole screen look broken whenever one was applied - see
/// `BrowseAllScreen`.
class HomeFeedScreen extends StatelessWidget {
  const HomeFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        // Android's AppBar left-aligns the title by default (iOS centers
        // it) - force centered on both so the wordmark lockup sits in the
        // same spot everywhere, rather than only "by accident" on iOS.
        centerTitle: true,
        // TESTING the new logo mark (assets/images/logo-mark.png, cropped
        // + keyed to transparent from assets/branding/splash-no-bg.jpeg -
        // see app_colors.dart). Unlike the old logo-header.png this new
        // mark has no wordmark baked in, so the "LAINTED" text is now a
        // real widget instead of flattened into the image - it also means
        // it no longer needs regenerating by hand every time AppColors
        // changes. Revert: swap this Row back for
        // Image.asset('assets/images/logo-header.png', height: 32).
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo-mark.png',
              height: 28,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
            const SizedBox(width: 8),
            Text(
              'LAINTED',
              style: GoogleFonts.fraunces(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outline),
            onPressed: () => context.push('/saved'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            onTap: () => context.push('/browse'),
            child: InputDecorator(
              decoration: const InputDecoration(
                hintText: 'Search listings',
                prefixIcon: Icon(Icons.search),
                suffixIcon: Icon(Icons.tune),
              ),
              child: const SizedBox(height: 20),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _PresetRail(title: 'Fresh Finds', filters: _freshFinds),
          const SizedBox(height: AppSpacing.lg),
          _PresetRail(title: 'Trending', filters: _trending),
        ],
      ),
    );
  }
}

class _PresetRail extends ConsumerWidget {
  const _PresetRail({required this.title, required this.filters});

  final String title;
  final DiscoveryFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presetAsync = ref.watch(discoveryPresetProvider(filters));

    return presetAsync.when(
      data: (listings) {
        if (listings.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                TextButton(
                  onPressed: () =>
                      context.push('/preset-listings', extra: (title, filters)),
                  child: const Text('See all'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: listings.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) => SizedBox(
                  width: 160,
                  child: SaveableListingCard(listing: listings[index]),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }
}
