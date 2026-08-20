import 'user.dart';

/// Buyer reviews seller, seller reviews buyer - both directions use the
/// same shape, only [reviewerRole] differs. See ReviewService on the
/// backend.
enum ReviewerRole { buyer, seller }

ReviewerRole reviewerRoleFromString(String? value) {
  return value == 'seller' ? ReviewerRole.seller : ReviewerRole.buyer;
}

class Review {
  const Review({
    required this.id,
    required this.orderId,
    required this.reviewerId,
    required this.revieweeId,
    this.reviewer,
    this.reviewee,
    required this.reviewerRole,
    required this.rating,
    this.comment,
    this.createdAt,
  });

  final String id;
  final String orderId;
  final String reviewerId;
  final String revieweeId;
  final User? reviewer;
  final User? reviewee;
  final ReviewerRole reviewerRole;

  /// 1-5 stars.
  final int rating;
  final String? comment;
  final DateTime? createdAt;

  factory Review.fromJson(Map<String, dynamic> json) {
    final reviewer = json['reviewer'] != null ? User.fromJson(json['reviewer'] as Map<String, dynamic>) : null;
    final reviewee = json['reviewee'] != null ? User.fromJson(json['reviewee'] as Map<String, dynamic>) : null;

    return Review(
      id: json['uuid'] as String,
      orderId: json['order_id'].toString(),
      // The backend's raw reviewer_id/reviewee_id are internal bigint FKs,
      // never uuids - comparing them against User.id (always a uuid, see
      // Order.buyerId/sellerId) would never match. Prefer the nested
      // User's real uuid; the raw FK is only a fallback for the
      // (currently unreachable) case where the relation wasn't eager-
      // loaded.
      reviewerId: reviewer?.id ?? json['reviewer_id'].toString(),
      revieweeId: reviewee?.id ?? json['reviewee_id'].toString(),
      reviewer: reviewer,
      reviewee: reviewee,
      reviewerRole: reviewerRoleFromString(json['reviewer_role'] as String?),
      rating: json['rating'] as int,
      comment: json['comment'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': id,
      'order_id': orderId,
      'reviewer_id': reviewerId,
      'reviewee_id': revieweeId,
      'reviewer': reviewer?.toJson(),
      'reviewee': reviewee?.toJson(),
      'reviewer_role': reviewerRole.name,
      'rating': rating,
      'comment': comment,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
