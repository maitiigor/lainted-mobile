import '../../core/utils/json_parsing.dart';
import 'listing_photo.dart';
import 'user.dart';

/// Delivery weight/size tier, drives delivery cost calculation.
enum WeightTier { standard, bulky, furniture }

WeightTier weightTierFromString(String? value) {
  return WeightTier.values.firstWhere(
    (e) => e.name == value,
    orElse: () => WeightTier.standard,
  );
}

/// Personal seller (wardrobe) vs business seller listing.
enum ListingSource { business, wardrobe }

ListingSource listingSourceFromString(String? value) {
  return ListingSource.values.firstWhere(
    (e) => e.name == value,
    orElse: () => ListingSource.wardrobe,
  );
}

/// Bale/bundle grading, for bulk fashion lots.
enum BaleType { premium, mixed, economy, sorted }

BaleType? baleTypeFromString(String? value) {
  if (value == null) return null;
  return BaleType.values.firstWhereOrNull((e) => e.name == value);
}

enum ListingStatus { draft, active, sold, expired, removed }

ListingStatus listingStatusFromString(String? value) {
  return ListingStatus.values.firstWhere(
    (e) => e.name == value,
    orElse: () => ListingStatus.draft,
  );
}

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

class Listing {
  const Listing({
    required this.id,
    required this.categoryId,
    this.categoryName,
    required this.title,
    required this.description,
    required this.itemType,
    required this.conditionGrade,
    this.faultDescription,
    this.size,
    this.brand,
    this.model,
    this.weightTier = WeightTier.standard,
    required this.price,
    this.isNegotiable = true,
    this.minimumPrice,
    this.isFunctional,
    this.requiresInstallation = false,
    this.lgaId,
    this.lga,
    this.landmark,
    this.listingSource = ListingSource.wardrobe,
    this.isBale = false,
    this.baleType,
    this.baleItemCount,
    this.baleOriginCountry,
    this.isWardrobeCleanout = false,
    this.verificationStatus = 'not_submitted',
    this.status = ListingStatus.draft,
    this.viewsCount = 0,
    this.photos = const [],
    this.seller,
    this.createdAt,
    this.publishedAt,
    this.expiresAt,
    this.soldAt,
  });

  final String id;
  final int categoryId;

  /// Leaf category name for display - editing a listing's category needs
  /// the full tree from `categoriesProvider`, not just this string.
  final String? categoryName;
  final String title;
  final String description;

  /// Only "fashion" is meaningful for V1 - derived server-side from the
  /// chosen category, never set directly by the client.
  final String itemType;

  /// A++, A+, A, B, C, D, or X - see AppColors.gradeColor for the color map.
  final String conditionGrade;

  /// Required by the backend when [conditionGrade] is D or X.
  final String? faultDescription;
  final String? size;
  final String? brand;
  final String? model;
  final WeightTier weightTier;
  final double price;
  final bool isNegotiable;
  final double? minimumPrice;

  /// "Is functional" toggle, for electronics and appliances.
  final bool? isFunctional;
  final bool requiresInstallation;
  final int? lgaId;
  final String? lga;
  final String? landmark;
  final ListingSource listingSource;
  final bool isBale;
  final BaleType? baleType;
  final int? baleItemCount;
  final String? baleOriginCountry;
  final bool isWardrobeCleanout;
  final String verificationStatus;
  final ListingStatus status;
  final int viewsCount;
  final List<ListingPhoto> photos;
  final User? seller;
  final DateTime? createdAt;
  final DateTime? publishedAt;
  final DateTime? expiresAt;
  final DateTime? soldAt;

  bool get isActive => status == ListingStatus.active;

  factory Listing.fromJson(Map<String, dynamic> json) {
    return Listing(
      id: json['uuid'] as String,
      categoryId: json['category_id'] as int,
      categoryName: json['category_name'] as String?,
      title: json['title'] as String,
      description: json['description'] as String,
      itemType: json['item_type'] as String,
      conditionGrade: json['condition_grade'] as String,
      faultDescription: json['fault_description'] as String?,
      size: json['size'] as String?,
      brand: json['brand'] as String?,
      model: json['model'] as String?,
      weightTier: weightTierFromString(json['weight_tier'] as String?),
      price: parseDouble(json['price']),
      isNegotiable: json['is_negotiable'] as bool? ?? true,
      minimumPrice: parseNullableDouble(json['minimum_price']),
      isFunctional: json['is_functional'] as bool?,
      requiresInstallation: json['requires_installation'] as bool? ?? false,
      lgaId: json['lga_id'] as int?,
      // The backend sends the raw `lga_id` FK plus an appended `lga_name`
      // string for display - there is no plain `lga` key.
      lga: json['lga_name'] as String?,
      landmark: json['landmark'] as String?,
      listingSource: listingSourceFromString(json['listing_source'] as String?),
      isBale: json['is_bale'] as bool? ?? false,
      baleType: baleTypeFromString(json['bale_type'] as String?),
      baleItemCount: json['bale_item_count'] as int?,
      baleOriginCountry: json['bale_origin_country'] as String?,
      isWardrobeCleanout: json['is_wardrobe_cleanout'] as bool? ?? false,
      verificationStatus:
          json['verification_status'] as String? ?? 'not_submitted',
      status: listingStatusFromString(json['status'] as String?),
      viewsCount: json['views_count'] as int? ?? 0,
      photos: (json['photos'] as List<dynamic>? ?? [])
          .map((e) => ListingPhoto.fromJson(e as Map<String, dynamic>))
          .toList(),
      seller: json['seller'] != null
          ? User.fromJson(json['seller'] as Map<String, dynamic>)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'] as String)
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
      soldAt: json['sold_at'] != null
          ? DateTime.tryParse(json['sold_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': id,
      'category_id': categoryId,
      'category_name': categoryName,
      'title': title,
      'description': description,
      'item_type': itemType,
      'condition_grade': conditionGrade,
      'fault_description': faultDescription,
      'size': size,
      'brand': brand,
      'model': model,
      'weight_tier': weightTier.name,
      'price': price,
      'is_negotiable': isNegotiable,
      'minimum_price': minimumPrice,
      'is_functional': isFunctional,
      'requires_installation': requiresInstallation,
      'lga_id': lgaId,
      'lga_name': lga,
      'landmark': landmark,
      'listing_source': listingSource.name,
      'is_bale': isBale,
      'bale_type': baleType?.name,
      'bale_item_count': baleItemCount,
      'bale_origin_country': baleOriginCountry,
      'is_wardrobe_cleanout': isWardrobeCleanout,
      'verification_status': verificationStatus,
      'status': status.name,
      'views_count': viewsCount,
      'photos': photos.map((e) => e.toJson()).toList(),
      'seller': seller?.toJson(),
      'created_at': createdAt?.toIso8601String(),
      'published_at': publishedAt?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'sold_at': soldAt?.toIso8601String(),
    };
  }
}
