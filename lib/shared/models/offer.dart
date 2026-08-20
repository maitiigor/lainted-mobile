import '../../core/utils/json_parsing.dart';
import 'listing.dart';
import 'user.dart';

/// Negotiation states, per the product document's negotiation engine.
enum OfferStatus {
  pending,
  countered,
  accepted,
  declined,
  expired,
  retracted,
  checkoutExpired,
  completed,
}

OfferStatus offerStatusFromString(String? value) {
  const map = {
    'pending': OfferStatus.pending,
    'countered': OfferStatus.countered,
    'accepted': OfferStatus.accepted,
    'declined': OfferStatus.declined,
    'expired': OfferStatus.expired,
    'retracted': OfferStatus.retracted,
    'checkout_expired': OfferStatus.checkoutExpired,
    'completed': OfferStatus.completed,
  };
  return map[value] ?? OfferStatus.pending;
}

/// Which party proposed the current round - rounds strictly alternate, so
/// this is the only way to know who's allowed to respond.
enum OfferParty { buyer, seller }

OfferParty offerPartyFromString(String? value) {
  return value == 'seller' ? OfferParty.seller : OfferParty.buyer;
}

class Offer {
  const Offer({
    required this.id,
    required this.listingId,
    required this.conversationId,
    required this.buyerId,
    required this.sellerId,
    this.listing,
    this.buyer,
    this.seller,
    required this.amount,
    this.roundNumber = 1,
    this.status = OfferStatus.pending,
    this.initiatedBy = OfferParty.buyer,
    this.isLowball = false,
    this.expiresAt,
    this.agreedAt,
    this.checkoutExpiresAt,
    this.orderId,
  });

  final String id;

  /// Raw bigint FKs, not uuids - see Conversation.buyerId/sellerId. Never
  /// compare these against `User.id` - use [buyer]/[seller] instead.
  final String listingId;
  final String conversationId;
  final String buyerId;
  final String sellerId;

  final Listing? listing;
  final User? buyer;
  final User? seller;

  final double amount;
  final int roundNumber;
  final OfferStatus status;
  final OfferParty initiatedBy;

  /// True when [amount] is below 30% of the listing's price - a flat
  /// threshold across every condition grade, not grade-conditioned.
  final bool isLowball;

  /// Offers auto-cancel after 24 hours with no response.
  final DateTime? expiresAt;

  /// Set once [status] reaches accepted.
  final DateTime? agreedAt;

  /// Checkout window closes 2 hours after [agreedAt].
  final DateTime? checkoutExpiresAt;

  /// Set once this offer has been paid for (status == completed) - lets
  /// the chat card link straight to the order.
  final String? orderId;

  factory Offer.fromJson(Map<String, dynamic> json) {
    return Offer(
      id: json['uuid'] as String,
      // Raw bigint FKs, not uuids - see ListingPhoto.listingId.
      listingId: json['listing_id'].toString(),
      conversationId: json['conversation_id'].toString(),
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
      amount: parseDouble(json['amount']),
      roundNumber: json['round_number'] as int? ?? 1,
      status: offerStatusFromString(json['status'] as String?),
      initiatedBy: offerPartyFromString(json['initiated_by'] as String?),
      isLowball: json['is_lowball'] as bool? ?? false,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
      agreedAt: json['agreed_at'] != null
          ? DateTime.tryParse(json['agreed_at'] as String)
          : null,
      checkoutExpiresAt: json['checkout_expires_at'] != null
          ? DateTime.tryParse(json['checkout_expires_at'] as String)
          : null,
      orderId: json['order'] != null
          ? (json['order'] as Map<String, dynamic>)['uuid'] as String?
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': id,
      'listing_id': listingId,
      'conversation_id': conversationId,
      'buyer_id': buyerId,
      'seller_id': sellerId,
      'listing': listing?.toJson(),
      'buyer': buyer?.toJson(),
      'seller': seller?.toJson(),
      'amount': amount,
      'round_number': roundNumber,
      'status': status == OfferStatus.checkoutExpired
          ? 'checkout_expired'
          : status.name,
      'initiated_by': initiatedBy.name,
      'is_lowball': isLowball,
      'expires_at': expiresAt?.toIso8601String(),
      'agreed_at': agreedAt?.toIso8601String(),
      'checkout_expires_at': checkoutExpiresAt?.toIso8601String(),
      'order': orderId != null ? {'uuid': orderId} : null,
    };
  }
}
