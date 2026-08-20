import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../models/listing.dart';

/// Listing card shown in feeds/search results: photo, color-coded grade
/// badge, title, price, negotiable indicator, LGA + landmark, and seller
/// rating - matching the listing card mock in the product document's
/// grading section.
class ListingCard extends StatelessWidget {
  const ListingCard({
    super.key,
    required this.listing,
    this.onTap,
    this.isSaved,
    this.onToggleSave,
  });

  final Listing listing;
  final VoidCallback? onTap;

  /// Heart overlay only renders when both this and [onToggleSave] are set -
  /// screens that don't care about save state (e.g. MyListingsScreen) pass
  /// neither and get the exact same card as before.
  final bool? isSaved;
  final VoidCallback? onToggleSave;

  @override
  Widget build(BuildContext context) {
    final photoUrl = listing.photos.isNotEmpty ? listing.photos.first.url : null;
    final locationParts = [
      if (listing.landmark != null) listing.landmark!,
      if (listing.lga != null) listing.lga!,
    ];
    final rating = listing.seller?.rating;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Expanded, not AspectRatio(1) - the text block below varies in
            // height (negotiable chip / location / rating are all
            // optional and can appear together), so the photo must yield
            // whatever space is left in the grid's fixed cell height
            // rather than claiming a fixed square and overflowing it.
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  photoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: photoUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: AppColors.accent.withValues(alpha: 0.3),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: AppColors.accent.withValues(alpha: 0.3),
                            child: const Icon(Icons.image_not_supported_outlined),
                          ),
                        )
                      : Container(
                          color: AppColors.accent.withValues(alpha: 0.3),
                          child: const Icon(Icons.image_outlined),
                        ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _GradeBadge(grade: listing.conditionGrade),
                  ),
                  if (listing.isWardrobeCleanout)
                    const Positioned(
                      bottom: 8,
                      left: 8,
                      child: _CleanoutBadge(),
                    ),
                  if (isSaved != null && onToggleSave != null)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: _SaveButton(
                        isSaved: isSaved!,
                        onPressed: onToggleSave!,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  // Wrap, not Row - a narrow 2-column card can't always fit
                  // both the price and the "Negotiable" chip on one line;
                  // Wrap drops the chip to its own line instead of
                  // overflowing off the edge of the card.
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      Text(
                        Formatters.currency(listing.price),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                      ),
                      if (listing.isNegotiable) const _NegotiableChip(),
                    ],
                  ),
                  if (locationParts.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            locationParts.join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (rating != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(
                          rating.toStringAsFixed(1),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared pill shape for the small badges/chips overlaid on listing cards.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.background, required this.foreground});

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
      ),
    );
  }
}

class _GradeBadge extends StatelessWidget {
  const _GradeBadge({required this.grade});

  final String grade;

  @override
  Widget build(BuildContext context) {
    return _Chip(
      label: grade,
      background: AppColors.gradeColor(grade),
      foreground: AppColors.surface,
    );
  }
}

class _CleanoutBadge extends StatelessWidget {
  const _CleanoutBadge();

  @override
  Widget build(BuildContext context) {
    return const _Chip(
      label: 'Cleanout',
      background: AppColors.primary,
      foreground: AppColors.surface,
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.isSaved, required this.onPressed});

  final bool isSaved;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface.withValues(alpha: 0.85),
      shape: const CircleBorder(),
      child: IconButton(
        iconSize: 18,
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(),
        onPressed: onPressed,
        icon: Icon(
          isSaved ? Icons.favorite : Icons.favorite_border,
          color: isSaved ? AppColors.error : AppColors.textMuted,
        ),
      ),
    );
  }
}

class _NegotiableChip extends StatelessWidget {
  const _NegotiableChip();

  @override
  Widget build(BuildContext context) {
    return _Chip(
      label: 'Negotiable',
      background: AppColors.secondary.withValues(alpha: 0.15),
      foreground: AppColors.secondary,
    );
  }
}
