import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/models/public_profile.dart';
import '../../../shared/models/review.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/stat_tile.dart';
import '../providers/reviews_provider.dart';
import '../widgets/report_sheet.dart';

const _sellerRankLabels = {
  SellerRank.newSeller: 'New Seller',
  SellerRank.rising: 'Rising Seller',
  SellerRank.trusted: 'Trusted Seller',
  SellerRank.top: 'Top Seller',
  SellerRank.elite: 'Elite Seller',
};

/// A stranger's-eye view of another user - the screen the mobile User
/// model's rating/total_sales/trust_score/seller_rank fields have been
/// silently ready for since Phase 1, sitting behind a bare
/// PlaceholderScreen with zero navigation call sites until now.
class PublicProfileScreen extends ConsumerWidget {
  const PublicProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(publicProfileProvider(userId));
    final reviewsAsync = ref.watch(userReviewsProvider(userId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Report user',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => ReportSheet(reportableType: 'user', reportableId: userId),
            ),
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) => SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _Header(profile: profile),
              const SizedBox(height: AppSpacing.lg),
              Text('Reviews', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              reviewsAsync.when(
                data: (reviews) => reviews.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        child: Text(
                          'No reviews yet.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                        ),
                      )
                    : Column(children: reviews.map((r) => _ReviewTile(review: r)).toList()),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stack) => Text(
                  'Could not load reviews.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text(
            'Could not load this profile.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final PublicProfile profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: AppColors.accent,
          backgroundImage: profile.photoUrl != null ? NetworkImage(profile.photoUrl!) : null,
          child: profile.photoUrl == null
              ? Text(
                  profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
                  style: Theme.of(context).textTheme.headlineMedium,
                )
              : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(profile.name, style: Theme.of(context).textTheme.titleLarge),
            if (profile.isVerified) ...[
              const SizedBox(width: 4),
              const Icon(Icons.verified, color: AppColors.primary, size: 18),
            ],
          ],
        ),
        if (profile.sellerType != SellerType.none) ...[
          const SizedBox(height: 2),
          Text(
            _sellerRankLabels[profile.sellerRank] ?? 'New Seller',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            StatTile(label: 'Rating', value: profile.rating != null ? '★ ${profile.rating!.toStringAsFixed(1)}' : '—'),
            StatTile(label: 'Sales', value: '${profile.totalSales}'),
            StatTile(
              label: 'Trust score',
              value: profile.trustScore != null ? profile.trustScore!.toStringAsFixed(0) : '—',
            ),
          ],
        ),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(review.reviewer?.name ?? 'Anonymous', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(width: AppSpacing.sm),
              Text('★' * review.rating, style: const TextStyle(color: AppColors.primary)),
            ],
          ),
          if (review.comment != null) ...[
            const SizedBox(height: 2),
            Text(review.comment!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
