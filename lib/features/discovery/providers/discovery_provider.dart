import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../shared/models/listing.dart';
import '../../../shared/providers/dio_provider.dart';
import '../models/discovery_filters.dart';

/// Shared by every notifier below - the backend's `/discover` nested
/// paginator shape (`data.data`, `data.current_page`, `data.last_page`) is
/// unusual enough (see [DiscoveryFeedNotifier]) that duplicating its
/// parsing risks the two copies silently drifting if it ever changes.
Future<DiscoveryFeedState> _fetchDiscoverPage(
  Ref ref,
  DiscoveryFilters filters,
  int page,
) async {
  final response = await ref.read(dioProvider).get(
    ApiConstants.discover,
    queryParameters: {...filters.toQueryParams(), 'page': page},
  );
  final paginator = response.data['data'] as Map<String, dynamic>;
  final items = (paginator['data'] as List<dynamic>)
      .map((e) => Listing.fromJson(e as Map<String, dynamic>))
      .toList();

  return DiscoveryFeedState(
    listings: items,
    currentPage: paginator['current_page'] as int,
    lastPage: paginator['last_page'] as int,
  );
}

/// Current filter/sort selection for the main discovery grid. Changing
/// this is watched by [discoveryFeedProvider] and triggers a fresh
/// page-1 fetch automatically.
final discoveryFiltersProvider = StateProvider<DiscoveryFilters>(
  (ref) => const DiscoveryFilters(),
);

class DiscoveryFeedState {
  const DiscoveryFeedState({
    this.listings = const [],
    this.currentPage = 1,
    this.lastPage = 1,
    this.isLoadingMore = false,
  });

  final List<Listing> listings;
  final int currentPage;
  final int lastPage;
  final bool isLoadingMore;

  bool get hasMore => currentPage < lastPage;

  DiscoveryFeedState copyWith({
    List<Listing>? listings,
    int? currentPage,
    int? lastPage,
    bool? isLoadingMore,
  }) {
    return DiscoveryFeedState(
      listings: listings ?? this.listings,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// The public feed - paginated, filter-driven. Distinct from
/// `myListingsProvider` (the seller's own inventory).
class DiscoveryFeedNotifier extends AsyncNotifier<DiscoveryFeedState> {
  @override
  Future<DiscoveryFeedState> build() {
    final filters = ref.watch(discoveryFiltersProvider);
    return _fetchPage(filters, 1);
  }

  Future<DiscoveryFeedState> _fetchPage(DiscoveryFilters filters, int page) =>
      _fetchDiscoverPage(ref, filters, page);

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetchPage(ref.read(discoveryFiltersProvider), 1),
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final next = await _fetchPage(
        ref.read(discoveryFiltersProvider),
        current.currentPage + 1,
      );
      state = AsyncData(
        current.copyWith(
          listings: [...current.listings, ...next.listings],
          currentPage: next.currentPage,
          lastPage: next.lastPage,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }
}

final discoveryFeedProvider =
    AsyncNotifierProvider<DiscoveryFeedNotifier, DiscoveryFeedState>(
      DiscoveryFeedNotifier.new,
    );

/// First-page-only fetch for the Home screen's small preset rails
/// ("Fresh Finds", "Trending") - these are just the same feed called with
/// a different filter preset, not a separate ranking algorithm.
final discoveryPresetProvider =
    FutureProvider.family<List<Listing>, DiscoveryFilters>((
      ref,
      filters,
    ) async {
      final response = await ref.read(dioProvider).get(
        ApiConstants.discover,
        queryParameters: {...filters.toQueryParams(), 'page': 1},
      );
      final paginator = response.data['data'] as Map<String, dynamic>;

      return (paginator['data'] as List<dynamic>)
          .map((e) => Listing.fromJson(e as Map<String, dynamic>))
          .toList();
    });

/// Full paginated view of a fixed preset (a "See all" page for "Fresh
/// Finds"/"Trending") - keyed by its own filters rather than the mutable
/// [discoveryFiltersProvider], so opening one never disturbs the Home
/// screen's own grid/filter state.
class PresetFeedNotifier
    extends FamilyAsyncNotifier<DiscoveryFeedState, DiscoveryFilters> {
  @override
  Future<DiscoveryFeedState> build(DiscoveryFilters filters) {
    return _fetchDiscoverPage(ref, filters, 1);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchDiscoverPage(ref, arg, 1));
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final next = await _fetchDiscoverPage(ref, arg, current.currentPage + 1);
      state = AsyncData(
        current.copyWith(
          listings: [...current.listings, ...next.listings],
          currentPage: next.currentPage,
          lastPage: next.lastPage,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }
}

final presetFeedProvider = AsyncNotifierProvider.family<
  PresetFeedNotifier,
  DiscoveryFeedState,
  DiscoveryFilters
>(PresetFeedNotifier.new);
