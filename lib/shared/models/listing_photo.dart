class ListingPhoto {
  const ListingPhoto({
    required this.id,
    required this.listingId,
    required this.url,
    required this.position,
  });

  final String id;
  final String listingId;

  /// Watermarked photo URL - all listing photos are auto-watermarked
  /// per the product document's anti-leakage architecture.
  final String url;
  final int position;

  factory ListingPhoto.fromJson(Map<String, dynamic> json) {
    return ListingPhoto(
      // listing_photos has no `uuid` column on the backend (non-addressable
      // child entity) - unlike every other model here, this really is the
      // raw bigint id, just represented as a string on this side.
      id: (json['id'] as num).toString(),
      // Also a raw bigint FK on the backend (no cast defined), not a
      // string - same "int arrives as a JSON number" gotcha as `id` above.
      listingId: (json['listing_id'] as num).toString(),
      url: json['url'] as String,
      position: json['position'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'listing_id': listingId,
      'url': url,
      'position': position,
    };
  }
}
