import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../shared/models/bundle.dart';
import '../../../shared/providers/dio_provider.dart';

class BundlesNotifier extends AsyncNotifier<List<Bundle>> {
  @override
  Future<List<Bundle>> build() => _fetch();

  Future<List<Bundle>> _fetch() async {
    final response = await ref.read(dioProvider).get(ApiConstants.bundles);
    final data = response.data['data'] as List<dynamic>;

    return data.map((e) => Bundle.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// The item pool is fixed at creation - see `BundleService` on the
  /// backend for why (matches this project's bias against building more
  /// than the doc actually asks for).
  Future<Bundle> createBundle({
    required String title,
    required int requiredItemCount,
    required double bundlePrice,
    required List<String> listingIds,
  }) async {
    final response = await ref.read(dioProvider).post(
      ApiConstants.bundles,
      data: {
        'title': title,
        'required_item_count': requiredItemCount,
        'bundle_price': bundlePrice,
        'listing_ids': listingIds,
      },
    );
    await refresh();

    return Bundle.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteBundle(String uuid) async {
    await ref.read(dioProvider).delete(ApiConstants.bundle(uuid));
    await refresh();
  }
}

final bundlesProvider = AsyncNotifierProvider<BundlesNotifier, List<Bundle>>(
  BundlesNotifier.new,
);
