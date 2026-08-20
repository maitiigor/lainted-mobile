import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../shared/models/public_profile.dart';
import '../../../shared/models/review.dart';
import '../../../shared/providers/dio_provider.dart';

/// No cached list state here, unlike DisputesNotifier - a review only
/// ever needs creating (the order screen already owns its own
/// Order.reviews) or listing for a specific other user's public profile
/// (owned by that screen's own FutureProvider.family below).
class ReviewsService {
  ReviewsService(this._ref);

  final Ref _ref;

  Future<Review> create(String orderUuid, {required int rating, String? comment}) async {
    final response = await _ref.read(dioProvider).post(
          ApiConstants.createReview(orderUuid),
          data: {'rating': rating, 'comment': comment},
        );

    return Review.fromJson(response.data['data'] as Map<String, dynamic>);
  }
}

final reviewsServiceProvider = Provider<ReviewsService>((ref) => ReviewsService(ref));

final publicProfileProvider = FutureProvider.family<PublicProfile, String>((ref, userUuid) async {
  final response = await ref.read(dioProvider).get(ApiConstants.publicProfile(userUuid));

  return PublicProfile.fromJson(response.data['data'] as Map<String, dynamic>);
});

final userReviewsProvider = FutureProvider.family<List<Review>, String>((ref, userUuid) async {
  final response = await ref.read(dioProvider).get(ApiConstants.userReviews(userUuid));
  final data = response.data['data']['data'] as List<dynamic>;

  return data.map((e) => Review.fromJson(e as Map<String, dynamic>)).toList();
});
