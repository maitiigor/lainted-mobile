import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../shared/models/listing.dart';
import '../../../shared/models/listing_photo.dart';
import '../../../shared/providers/dio_provider.dart';
import '../../discovery/providers/discovery_provider.dart';

/// The signed-in seller's own inventory - not the public discovery feed
/// (that's a separate, not-yet-built Phase 3 concern with its own provider).
class MyListingsNotifier extends AsyncNotifier<List<Listing>> {
  @override
  Future<List<Listing>> build() => _fetch();

  Future<List<Listing>> _fetch() async {
    final response = await ref.read(dioProvider).get(ApiConstants.listings);
    final data = response.data['data'] as List<dynamic>;

    return data.map((e) => Listing.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<Listing> getListing(String uuid) async {
    final response = await ref.read(dioProvider).get(ApiConstants.listing(uuid));

    return Listing.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// Always creates as a draft - grade/photo-count enforcement only
  /// happens at [publishListing] time.
  Future<Listing> createListing(Map<String, dynamic> data) async {
    final response = await ref
        .read(dioProvider)
        .post(ApiConstants.listings, data: data);
    await refresh();

    return Listing.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<Listing> updateListing(String uuid, Map<String, dynamic> data) async {
    final response = await ref
        .read(dioProvider)
        .put(ApiConstants.listing(uuid), data: data);
    await refresh();

    return Listing.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<Listing> publishListing(String uuid) async {
    final response = await ref
        .read(dioProvider)
        .post(ApiConstants.publishListing(uuid));
    await refresh();

    // The Home feed's rails and the Browse screen cache their results
    // indefinitely (FutureProvider/AsyncNotifier, not autoDispose) - a
    // freshly-published listing otherwise never appears there until the
    // app restarts, no matter how many times you navigate back to Home.
    ref.invalidate(discoveryPresetProvider);
    ref.invalidate(discoveryFeedProvider);
    ref.invalidate(presetFeedProvider);

    return Listing.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> markSold(String uuid) async {
    await ref.read(dioProvider).post(ApiConstants.markListingSold(uuid));
    await refresh();
  }

  Future<void> deleteListing(String uuid) async {
    await ref.read(dioProvider).delete(ApiConstants.listing(uuid));
    await refresh();
  }

  Future<ListingPhoto> uploadPhoto({
    required String listingUuid,
    required List<int> bytes,
    required String filename,
  }) async {
    final formData = FormData.fromMap({
      'photo': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await ref
        .read(dioProvider)
        .post(ApiConstants.listingPhotos(listingUuid), data: formData);
    await refresh();

    return ListingPhoto.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> deletePhoto({
    required String listingUuid,
    required String photoId,
  }) async {
    await ref
        .read(dioProvider)
        .delete(ApiConstants.listingPhoto(listingUuid, photoId));
    await refresh();
  }
}

final myListingsProvider =
    AsyncNotifierProvider<MyListingsNotifier, List<Listing>>(
      MyListingsNotifier.new,
    );
