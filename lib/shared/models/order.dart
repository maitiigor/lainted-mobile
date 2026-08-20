import '../../core/utils/json_parsing.dart';
import 'delivery_address.dart';
import 'dispute.dart';
import 'listing.dart';
import 'review.dart';
import 'user.dart';

/// Pickup, standard (bike), bulky (car), or furniture (van/truck) tier.
enum DeliveryTier { pickup, standard, bulky, furniture }

DeliveryTier deliveryTierFromString(String? value) {
  return DeliveryTier.values.firstWhere(
    (e) => e.name == value,
    orElse: () => DeliveryTier.standard,
  );
}

/// Order lifecycle: Pending -> Confirmed -> Prepared -> In Transit ->
/// Delivered -> Completed, per the product document's order flow.
enum OrderStatus {
  pending,
  confirmed,
  prepared,
  inTransit,
  delivered,
  completed,
  cancelled,
}

OrderStatus orderStatusFromString(String? value) {
  const map = {
    'pending': OrderStatus.pending,
    'confirmed': OrderStatus.confirmed,
    'prepared': OrderStatus.prepared,
    'in_transit': OrderStatus.inTransit,
    'delivered': OrderStatus.delivered,
    'completed': OrderStatus.completed,
    'cancelled': OrderStatus.cancelled,
  };
  return map[value] ?? OrderStatus.pending;
}

enum PaymentMethod { online, cashOnDelivery }

PaymentMethod paymentMethodFromString(String? value) {
  return value == 'cash_on_delivery' ? PaymentMethod.cashOnDelivery : PaymentMethod.online;
}

/// Null for cash-on-delivery orders - no escrow is ever created for them
/// (see OrderService's design: COD skips the protection fee and escrow
/// entirely since no online payment ever touches the platform).
enum EscrowStatus { held, released, refunded, disputed }

EscrowStatus? escrowStatusFromString(String? value) {
  const map = {
    'held': EscrowStatus.held,
    'released': EscrowStatus.released,
    'refunded': EscrowStatus.refunded,
    'disputed': EscrowStatus.disputed,
  };
  return value != null ? map[value] : null;
}

class Order {
  const Order({
    required this.id,
    required this.listingId,
    required this.buyerId,
    required this.sellerId,
    this.offerId,
    this.listing,
    this.buyer,
    this.seller,
    this.deliveryAddress,
    this.deliveryTier = DeliveryTier.standard,
    this.paymentMethod = PaymentMethod.online,
    this.logisticsProvider,
    this.trackingReference,
    required this.itemPrice,
    this.commissionRate,
    this.commissionAmount = 0,
    this.protectionFee = 0,
    this.deliveryFee = 0,
    this.discountAmount = 0,
    required this.totalAmount,
    this.status = OrderStatus.pending,
    this.pickupCode,
    this.escrowStatus,
    this.deliveredAt,
    this.disputeDeadlineAt,
    this.completedAt,
    this.createdAt,
    this.disputes = const [],
    this.reviews = const [],
  });

  final String id;

  /// Raw bigint FKs, not uuids - see Conversation.buyerId/sellerId. Never
  /// compare these against `User.id` - use [buyer]/[seller] instead.
  final String listingId;
  final String buyerId;
  final String sellerId;

  /// Set only when this order came from an accepted negotiation, not a
  /// fixed-price Buy Now.
  final String? offerId;

  final Listing? listing;
  final User? buyer;
  final User? seller;
  final DeliveryAddress? deliveryAddress;

  final DeliveryTier deliveryTier;
  final PaymentMethod paymentMethod;
  final String? logisticsProvider;

  /// Required by the backend when marking a non-Pickup order in transit -
  /// the seller-protection mechanism for courier tiers (see OrderService).
  final String? trackingReference;
  final double itemPrice;
  final double? commissionRate;
  final double commissionAmount;

  /// 1.5% buyer protection fee added on top of the agreed price - 0 for
  /// cash-on-delivery orders.
  final double protectionFee;
  final double deliveryFee;
  final double discountAmount;
  final double totalAmount;
  final OrderStatus status;

  /// Present only in the buyer's own view of their order - the backend
  /// hides it from the seller entirely (they learn it face to face at
  /// pickup handoff).
  final String? pickupCode;
  final EscrowStatus? escrowStatus;

  final DateTime? deliveredAt;

  /// 48-hour window after delivery in which a buyer can raise a dispute.
  final DateTime? disputeDeadlineAt;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final List<Dispute> disputes;
  final List<Review> reviews;

  /// A dispute that's still open/self-resolving/under admin review -
  /// mutually exclusive with confirming receipt (see OrderService's
  /// confirmReceipt guard on the backend).
  Dispute? get activeDispute {
    for (final dispute in disputes) {
      if (!dispute.isResolved) return dispute;
    }
    return null;
  }

  /// The current user's own review on this order, if they've already
  /// left one - null means they haven't (or the order isn't reviewable
  /// yet regardless).
  Review? myReview(String? currentUserId) {
    for (final review in reviews) {
      if (review.reviewerId == currentUserId) return review;
    }
    return null;
  }

  /// The other party's review of [currentUserId], if they've left one -
  /// both directions are always embedded together, so this is free once
  /// [myReview] is already being checked.
  Review? theirReview(String? currentUserId) {
    for (final review in reviews) {
      if (review.reviewerId != currentUserId) return review;
    }
    return null;
  }

  /// The other party from [currentUserId]'s point of view - mirrors
  /// Conversation.otherParticipant.
  User? otherParty(String? currentUserId) {
    if (buyer?.id == currentUserId) return seller;
    if (seller?.id == currentUserId) return buyer;

    return null;
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['uuid'] as String,
      listingId: json['listing_id'].toString(),
      buyerId: json['buyer_id'].toString(),
      sellerId: json['seller_id'].toString(),
      offerId: json['offer_id']?.toString(),
      listing: json['listing'] != null
          ? Listing.fromJson(json['listing'] as Map<String, dynamic>)
          : null,
      buyer: json['buyer'] != null
          ? User.fromJson(json['buyer'] as Map<String, dynamic>)
          : null,
      seller: json['seller'] != null
          ? User.fromJson(json['seller'] as Map<String, dynamic>)
          : null,
      deliveryAddress: json['delivery_address'] != null
          ? DeliveryAddress.fromJson(json['delivery_address'] as Map<String, dynamic>)
          : null,
      deliveryTier: deliveryTierFromString(json['delivery_tier'] as String?),
      paymentMethod: paymentMethodFromString(json['payment_method'] as String?),
      logisticsProvider: json['logistics_provider'] as String?,
      trackingReference: json['tracking_reference'] as String?,
      itemPrice: parseDouble(json['item_price']),
      commissionRate: parseNullableDouble(json['commission_rate']),
      commissionAmount: parseDouble(json['commission_amount']),
      protectionFee: parseDouble(json['protection_fee']),
      deliveryFee: parseDouble(json['delivery_fee']),
      discountAmount: parseDouble(json['discount_amount']),
      totalAmount: parseDouble(json['total_amount']),
      status: orderStatusFromString(json['status'] as String?),
      pickupCode: json['pickup_code'] as String?,
      escrowStatus: json['escrow'] != null
          ? escrowStatusFromString((json['escrow'] as Map<String, dynamic>)['status'] as String?)
          : null,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.tryParse(json['delivered_at'] as String)
          : null,
      disputeDeadlineAt: json['dispute_deadline_at'] != null
          ? DateTime.tryParse(json['dispute_deadline_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      disputes: (json['disputes'] as List<dynamic>?)
              ?.map((e) => Dispute.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      reviews: (json['reviews'] as List<dynamic>?)
              ?.map((e) => Review.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': id,
      'listing_id': listingId,
      'buyer_id': buyerId,
      'seller_id': sellerId,
      'offer_id': offerId,
      'listing': listing?.toJson(),
      'buyer': buyer?.toJson(),
      'seller': seller?.toJson(),
      'delivery_address': deliveryAddress?.toJson(),
      'delivery_tier': deliveryTier.name,
      'payment_method': paymentMethod == PaymentMethod.cashOnDelivery ? 'cash_on_delivery' : 'online',
      'logistics_provider': logisticsProvider,
      'tracking_reference': trackingReference,
      'item_price': itemPrice,
      'commission_rate': commissionRate,
      'commission_amount': commissionAmount,
      'protection_fee': protectionFee,
      'delivery_fee': deliveryFee,
      'discount_amount': discountAmount,
      'total_amount': totalAmount,
      'status': status == OrderStatus.inTransit ? 'in_transit' : status.name,
      'pickup_code': pickupCode,
      'delivered_at': deliveredAt?.toIso8601String(),
      'dispute_deadline_at': disputeDeadlineAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'disputes': disputes.map((d) => d.toJson()).toList(),
      'reviews': reviews.map((r) => r.toJson()).toList(),
    };
  }
}
