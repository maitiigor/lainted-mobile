import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../shared/models/listing.dart';
import '../../../shared/providers/dio_provider.dart';

class SavedListingsNotifier extends AsyncNotifier<List<Listing>> {
  @override
  Future<List<Listing>> build() => _fetch();

  Future<List<Listing>> _fetch() async {
    final response = await ref.read(dioProvider).get(ApiConstants.savedListings);
    final data = response.data['data'] as List<dynamic>;

    return data.map((e) => Listing.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> toggleSave(Listing listing) async {
    final isSaved = state.value?.any((l) => l.id == listing.id) ?? false;

    if (isSaved) {
      await ref.read(dioProvider).delete(ApiConstants.saveListing(listing.id));
    } else {
      await ref.read(dioProvider).post(ApiConstants.saveListing(listing.id));
    }

    await refresh();
  }
}

final savedListingsProvider =
    AsyncNotifierProvider<SavedListingsNotifier, List<Listing>>(
      SavedListingsNotifier.new,
    );

/// Cheap membership lookup for heart-icon state on any card, anywhere -
/// live-shared across screens for the app's process lifetime. No
/// `is_saved` field needed on any backend Listing response.
final savedListingIdsProvider = Provider<Set<String>>((ref) {
  return ref.watch(savedListingsProvider).value?.map((l) => l.id).toSet() ??
      {};
});
