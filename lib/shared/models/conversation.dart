import 'listing.dart';
import 'user.dart';

class Conversation {
  const Conversation({
    required this.id,
    required this.listingId,
    required this.buyerId,
    required this.sellerId,
    this.listing,
    this.buyer,
    this.seller,
    this.lastMessageAt,
  });

  final String id;

  /// Raw internal bigint FKs, turned into strings - NOT the same id space
  /// as any User/Listing's own `.id` (which is a uuid). Never compare
  /// these against `User.id`/`Listing.id` - use the nested [buyer],
  /// [seller], [listing] objects below for identity checks instead
  /// (mirrors how `Listing.seller` already works).
  final String listingId;
  final String buyerId;
  final String sellerId;

  final Listing? listing;
  final User? buyer;
  final User? seller;
  final DateTime? lastMessageAt;

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['uuid'] as String,
      listingId: json['listing_id'].toString(),
      buyerId: json['buyer_id'].toString(),
      sellerId: json['seller_id'].toString(),
      listing: json['listing'] != null
          ? Listing.fromJson(json['listing'] as Map<String, dynamic>)
          : null,
      buyer: json['buyer'] != null
          ? User.fromJson(json['buyer'] as Map<String, dynamic>)
          : null,
      seller: json['seller'] != null
          ? User.fromJson(json['seller'] as Map<String, dynamic>)
          : null,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'listing_id': listingId,
      'buyer_id': buyerId,
      'seller_id': sellerId,
      'listing': listing?.toJson(),
      'buyer': buyer?.toJson(),
      'seller': seller?.toJson(),
      'last_message_at': lastMessageAt?.toIso8601String(),
    };
  }

  /// The other participant, from [currentUserId]'s point of view -
  /// compares via the nested User objects' own uuid, never the raw
  /// [buyerId]/[sellerId] strings.
  User? otherParticipant(String? currentUserId) {
    if (buyer?.id == currentUserId) return seller;
    if (seller?.id == currentUserId) return buyer;

    return null;
  }
}
