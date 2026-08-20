/// Sentinel for [DiscoveryFilters.copyWith] - distinguishes "field not
/// passed" from "field explicitly cleared to null".
const Object _unset = Object();

/// Filter/sort state for the discovery feed - mirrors the backend's
/// `DiscoveryService::feed()` filter keys 1:1. No `itemType` field: only
/// Fashion is active in V1, so a filter control for it would offer a
/// single, useless option.
class DiscoveryFilters {
  const DiscoveryFilters({
    this.q,
    this.categoryId,
    this.size,
    this.brand,
    this.priceMin,
    this.priceMax,
    this.minGrade,
    this.lgaId,
    this.sellerType,
    this.isWardrobeCleanout = false,
    this.nearYou = false,
    this.sort,
  });

  final String? q;
  final int? categoryId;
  final String? size;
  final String? brand;
  final double? priceMin;
  final double? priceMax;

  /// A++, A+, A, B, C, D, or X - "this grade and better".
  final String? minGrade;
  final int? lgaId;

  /// 'business' or 'wardrobe' - maps to the backend's `listing_source`.
  final String? sellerType;
  final bool isWardrobeCleanout;
  final bool nearYou;

  /// newest | price_asc | price_desc | popular - null means the backend's
  /// default (soft same-LGA-first, then newest).
  final String? sort;

  bool get hasActiveFilters =>
      categoryId != null ||
      size != null ||
      brand != null ||
      priceMin != null ||
      priceMax != null ||
      minGrade != null ||
      lgaId != null ||
      sellerType != null ||
      isWardrobeCleanout ||
      nearYou ||
      sort != null;

  /// Every nullable field defaults to a sentinel, not `null` - a filter
  /// sheet needs to explicitly clear a field back to "any" (pass `null`),
  /// which a plain `value ?? this.value` pattern can't distinguish from
  /// "field not touched".
  DiscoveryFilters copyWith({
    Object? q = _unset,
    Object? categoryId = _unset,
    Object? size = _unset,
    Object? brand = _unset,
    Object? priceMin = _unset,
    Object? priceMax = _unset,
    Object? minGrade = _unset,
    Object? lgaId = _unset,
    Object? sellerType = _unset,
    bool? isWardrobeCleanout,
    bool? nearYou,
    Object? sort = _unset,
  }) {
    return DiscoveryFilters(
      q: q == _unset ? this.q : q as String?,
      categoryId: categoryId == _unset ? this.categoryId : categoryId as int?,
      size: size == _unset ? this.size : size as String?,
      brand: brand == _unset ? this.brand : brand as String?,
      priceMin: priceMin == _unset ? this.priceMin : priceMin as double?,
      priceMax: priceMax == _unset ? this.priceMax : priceMax as double?,
      minGrade: minGrade == _unset ? this.minGrade : minGrade as String?,
      lgaId: lgaId == _unset ? this.lgaId : lgaId as int?,
      sellerType: sellerType == _unset ? this.sellerType : sellerType as String?,
      isWardrobeCleanout: isWardrobeCleanout ?? this.isWardrobeCleanout,
      nearYou: nearYou ?? this.nearYou,
      sort: sort == _unset ? this.sort : sort as String?,
    );
  }

  Map<String, dynamic> toQueryParams() {
    return {
      if (q != null && q!.isNotEmpty) 'q': q,
      if (categoryId != null) 'category_id': categoryId,
      if (size != null) 'size': size,
      if (brand != null) 'brand': brand,
      if (priceMin != null) 'price_min': priceMin,
      if (priceMax != null) 'price_max': priceMax,
      if (minGrade != null) 'min_grade': minGrade,
      if (lgaId != null) 'lga_id': lgaId,
      if (sellerType != null) 'seller_type': sellerType,
      if (isWardrobeCleanout) 'is_wardrobe_cleanout': true,
      if (nearYou) 'near_you': true,
      if (sort != null) 'sort': sort,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is DiscoveryFilters &&
        other.q == q &&
        other.categoryId == categoryId &&
        other.size == size &&
        other.brand == brand &&
        other.priceMin == priceMin &&
        other.priceMax == priceMax &&
        other.minGrade == minGrade &&
        other.lgaId == lgaId &&
        other.sellerType == sellerType &&
        other.isWardrobeCleanout == isWardrobeCleanout &&
        other.nearYou == nearYou &&
        other.sort == sort;
  }

  @override
  int get hashCode => Object.hash(
    q,
    categoryId,
    size,
    brand,
    priceMin,
    priceMax,
    minGrade,
    lgaId,
    sellerType,
    isWardrobeCleanout,
    nearYou,
    sort,
  );
}
