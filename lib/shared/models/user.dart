import '../../core/utils/json_parsing.dart';
import 'delivery_address.dart';
import 'subscription_plan.dart';

/// Seller type, per the product document's user roles (Personal Seller,
/// Business Seller, or neither yet).
enum SellerType { none, personal, business }

SellerType sellerTypeFromString(String? value) {
  return SellerType.values.firstWhere(
    (e) => e.name == value,
    orElse: () => SellerType.none,
  );
}

/// Account standing - `pendingDeletion` is what the "Restore your
/// account?" gate checks for (see splash_screen.dart/otp_entry_screen.dart/
/// password_login_screen.dart, right where they already check
/// needsProfileSetup).
enum AccountStatus { active, warned, suspended, banned, pendingDeletion }

AccountStatus accountStatusFromString(String? value) {
  const map = {
    'active': AccountStatus.active,
    'warned': AccountStatus.warned,
    'suspended': AccountStatus.suspended,
    'banned': AccountStatus.banned,
    'pending_deletion': AccountStatus.pendingDeletion,
  };
  return map[value] ?? AccountStatus.active;
}

/// Seller rank ladder: New -> Rising -> Trusted -> Top -> Elite.
enum SellerRank { newSeller, rising, trusted, top, elite }

SellerRank sellerRankFromString(String? value) {
  const map = {
    'new': SellerRank.newSeller,
    'rising': SellerRank.rising,
    'trusted': SellerRank.trusted,
    'top': SellerRank.top,
    'elite': SellerRank.elite,
  };
  return map[value] ?? SellerRank.newSeller;
}

class User {
  const User({
    required this.id,
    required this.name,
    required this.phone,
    this.photoUrl,
    this.email,
    this.bio,
    this.lga,
    this.landmark,
    this.sellerType = SellerType.none,
    this.isVerified = false,
    this.sellerRank = SellerRank.newSeller,
    this.responseRate,
    this.totalSales = 0,
    this.trustScore,
    this.rating,
    this.profileCompletedAt,
    this.pickupAddress,
    this.accountStatus = AccountStatus.active,
    this.deletionRequestedAt,
    this.activeSubscription,
  });

  final String id;
  final String name;
  final String phone;
  final String? photoUrl;
  final String? email;
  final String? bio;
  final String? lga;
  final String? landmark;
  final SellerType sellerType;
  final bool isVerified;
  final AccountStatus accountStatus;

  /// Set once a self-service delete-account request is pending - null
  /// again once restored or purged. See AccountDeletionService on the
  /// backend for the 30-day recovery window this anchors.
  final DateTime? deletionRequestedAt;

  /// Only ever set for business sellers - personal sellers have a flat
  /// hardcoded cap and no subscription row at all (see
  /// User::remainingListingSlots() on the backend).
  final ActiveSubscription? activeSubscription;

  final SellerRank sellerRank;
  final double? responseRate;
  final int totalSales;
  final double? trustScore;

  /// Average star rating (1-5) from completed-transaction reviews.
  final double? rating;

  /// Null until profile setup (name/photo/LGA/seller-type) is submitted.
  final DateTime? profileCompletedAt;

  /// A seller's saved default pickup location for real courier bookings -
  /// reuses DeliveryAddress as-is (see SendboxService on the backend).
  /// Null for buyers and for sellers who haven't set one yet.
  final DeliveryAddress? pickupAddress;

  bool get needsProfileSetup => profileCompletedAt == null;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      // The backend's raw `id` is an internal bigint (never meant to be
      // exposed/used externally) - `uuid` is the actual public identifier.
      id: json['uuid'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      photoUrl: json['photo_path'] as String?,
      email: json['email'] as String?,
      bio: json['bio'] as String?,
      // The backend sends the raw `lga_id` FK plus an appended `lga_name`
      // string for display - there is no plain `lga` key.
      lga: json['lga_name'] as String?,
      landmark: json['landmark'] as String?,
      sellerType: sellerTypeFromString(json['seller_type'] as String?),
      isVerified: json['is_verified'] as bool? ?? false,
      sellerRank: sellerRankFromString(json['seller_rank'] as String?),
      responseRate: parseNullableDouble(json['response_rate']),
      totalSales: json['total_sales'] as int? ?? 0,
      trustScore: parseNullableDouble(json['trust_score']),
      rating: parseNullableDouble(json['rating']),
      profileCompletedAt: json['profile_completed_at'] != null
          ? DateTime.tryParse(json['profile_completed_at'] as String)
          : null,
      pickupAddress: json['pickup_address'] != null
          ? DeliveryAddress.fromJson(json['pickup_address'] as Map<String, dynamic>)
          : null,
      accountStatus: accountStatusFromString(json['account_status'] as String?),
      deletionRequestedAt: json['deletion_requested_at'] != null
          ? DateTime.tryParse(json['deletion_requested_at'] as String)
          : null,
      activeSubscription: json['active_subscription'] != null
          ? ActiveSubscription.fromJson(json['active_subscription'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': id,
      'name': name,
      'phone': phone,
      'photo_path': photoUrl,
      'email': email,
      'bio': bio,
      'lga_name': lga,
      'landmark': landmark,
      'seller_type': sellerType.name,
      'is_verified': isVerified,
      'seller_rank': sellerRank == SellerRank.newSeller
          ? 'new'
          : sellerRank.name,
      'response_rate': responseRate,
      'total_sales': totalSales,
      'trust_score': trustScore,
      'rating': rating,
      'profile_completed_at': profileCompletedAt?.toIso8601String(),
      'pickup_address': pickupAddress?.toJson(),
      'account_status': accountStatus == AccountStatus.pendingDeletion ? 'pending_deletion' : accountStatus.name,
      'deletion_requested_at': deletionRequestedAt?.toIso8601String(),
    };
  }
}
