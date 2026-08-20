import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/listing.dart';
import '../../../shared/widgets/listing_card.dart';
import '../providers/saved_listings_provider.dart';

/// [ListingCard] wired with this app's shared saved-listing state - used
/// wherever a public listing (not the seller's own inventory) is shown:
/// the discovery feed, its preset rails, and the Saved/Recently-Viewed
/// screen.
class SaveableListingCard extends ConsumerWidget {
  const SaveableListingCard({super.key, required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSaved = ref.watch(savedListingIdsProvider).contains(listing.id);

    return ListingCard(
      listing: listing,
      onTap: () => context.push('/listings/${listing.id}'),
      isSaved: isSaved,
      onToggleSave: () =>
          ref.read(savedListingsProvider.notifier).toggleSave(listing),
    );
  }
}
