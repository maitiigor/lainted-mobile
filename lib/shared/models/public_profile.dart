import '../../core/utils/json_parsing.dart';
import 'user.dart';

/// A stranger's-eye view of another user - deliberately a separate, much
/// smaller model than [User]. The backend's GET /users/{id} endpoint
/// hand-picks a safe public subset (no phone/email/verification data),
/// so this can't just reuse User.fromJson() - that model requires phone.
class PublicProfile {
  const PublicProfile({
    required this.id,
    required this.name,
    this.photoUrl,
    this.sellerType = SellerType.none,
    this.isVerified = false,
    this.rating,
    this.totalSales = 0,
    this.trustScore,
    this.sellerRank = SellerRank.newSeller,
    this.memberSince,
  });

  final String id;
  final String name;
  final String? photoUrl;
  final SellerType sellerType;
  final bool isVerified;
  final double? rating;
  final int totalSales;
  final double? trustScore;
  final SellerRank sellerRank;
  final DateTime? memberSince;

  factory PublicProfile.fromJson(Map<String, dynamic> json) {
    return PublicProfile(
      id: json['uuid'] as String,
      name: json['name'] as String,
      photoUrl: json['photo_path'] as String?,
      sellerType: sellerTypeFromString(json['seller_type'] as String?),
      isVerified: json['is_verified'] as bool? ?? false,
      rating: parseNullableDouble(json['rating']),
      totalSales: json['total_sales'] as int? ?? 0,
      trustScore: parseNullableDouble(json['trust_score']),
      sellerRank: sellerRankFromString(json['seller_rank'] as String?),
      memberSince: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }
}
