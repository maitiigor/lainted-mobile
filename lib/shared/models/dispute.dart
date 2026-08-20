import '../../core/utils/json_parsing.dart';
import 'user.dart';

/// Dispute reasons, per the schema the backend's Trust domain already
/// encoded before this phase had any business logic on top of it.
enum DisputeType { notReceived, gradeMismatch, wrongItem, itemDamaged, sellerNoShow, other }

DisputeType disputeTypeFromString(String? value) {
  const map = {
    'not_received': DisputeType.notReceived,
    'grade_mismatch': DisputeType.gradeMismatch,
    'wrong_item': DisputeType.wrongItem,
    'item_damaged': DisputeType.itemDamaged,
    'seller_no_show': DisputeType.sellerNoShow,
    'other': DisputeType.other,
  };
  return map[value] ?? DisputeType.other;
}

String disputeTypeToApiValue(DisputeType type) {
  const map = {
    DisputeType.notReceived: 'not_received',
    DisputeType.gradeMismatch: 'grade_mismatch',
    DisputeType.wrongItem: 'wrong_item',
    DisputeType.itemDamaged: 'item_damaged',
    DisputeType.sellerNoShow: 'seller_no_show',
    DisputeType.other: 'other',
  };
  return map[type]!;
}

/// Buyer raises -> seller responds (optionally with a self-resolution
/// offer) -> buyer accepts/rejects -> rejection or silence escalates to
/// admin review -> admin resolves. See DisputeService on the backend.
enum DisputeStatus { open, selfResolving, adminReview, resolvedRefund, resolvedRelease, resolvedPartial }

DisputeStatus disputeStatusFromString(String? value) {
  const map = {
    'open': DisputeStatus.open,
    'self_resolving': DisputeStatus.selfResolving,
    'admin_review': DisputeStatus.adminReview,
    'resolved_refund': DisputeStatus.resolvedRefund,
    'resolved_release': DisputeStatus.resolvedRelease,
    'resolved_partial': DisputeStatus.resolvedPartial,
  };
  return map[value] ?? DisputeStatus.open;
}

class Dispute {
  const Dispute({
    required this.id,
    required this.orderId,
    this.orderListingTitle,
    this.raisedBy,
    required this.disputeType,
    required this.buyerStatement,
    this.buyerPhotos = const [],
    this.sellerStatement,
    this.sellerPhotos = const [],
    this.selfResolutionOffered,
    this.selfResolutionAccepted,
    this.status = DisputeStatus.open,
    this.admin,
    this.adminNotes,
    this.resolvedAt,
    this.selfResolveExpiresAt,
    this.createdAt,
  });

  final String id;
  final String orderId;

  /// Denormalized for the disputes-list screen, so it doesn't need a
  /// full nested Order (which would be a circular import) just to show
  /// what each dispute is about.
  final String? orderListingTitle;

  final User? raisedBy;
  final DisputeType disputeType;
  final String buyerStatement;
  final List<String> buyerPhotos;
  final String? sellerStatement;
  final List<String> sellerPhotos;

  /// Amount the seller offered to refund the buyer - null until the
  /// seller responds with an offer (a bare response with no offer skips
  /// straight to admin review, see DisputeService::respondAsSeller).
  final double? selfResolutionOffered;
  final bool? selfResolutionAccepted;
  final DisputeStatus status;
  final User? admin;
  final String? adminNotes;
  final DateTime? resolvedAt;

  /// 48h after the seller's offer - past this with no buyer action, the
  /// backend's disputes:sweep-stale command escalates to admin review.
  final DateTime? selfResolveExpiresAt;
  final DateTime? createdAt;

  bool get isResolved => switch (status) {
        DisputeStatus.resolvedRefund || DisputeStatus.resolvedRelease || DisputeStatus.resolvedPartial => true,
        _ => false,
      };

  factory Dispute.fromJson(Map<String, dynamic> json) {
    final order = json['order'] as Map<String, dynamic>?;

    return Dispute(
      id: json['uuid'] as String,
      orderId: order?['uuid'] as String? ?? json['order_id'].toString(),
      orderListingTitle: (order?['listing'] as Map<String, dynamic>?)?['title'] as String?,
      raisedBy: json['raised_by'] is Map<String, dynamic>
          ? User.fromJson(json['raised_by'] as Map<String, dynamic>)
          : null,
      disputeType: disputeTypeFromString(json['dispute_type'] as String?),
      buyerStatement: json['buyer_statement'] as String? ?? '',
      buyerPhotos: (json['buyer_photos'] as List<dynamic>?)?.cast<String>() ?? const [],
      sellerStatement: json['seller_statement'] as String?,
      sellerPhotos: (json['seller_photos'] as List<dynamic>?)?.cast<String>() ?? const [],
      selfResolutionOffered: parseNullableDouble(json['self_resolution_offered']),
      selfResolutionAccepted: json['self_resolution_accepted'] as bool?,
      status: disputeStatusFromString(json['status'] as String?),
      admin: json['admin'] is Map<String, dynamic> ? User.fromJson(json['admin'] as Map<String, dynamic>) : null,
      adminNotes: json['admin_notes'] as String?,
      resolvedAt: json['resolved_at'] != null ? DateTime.tryParse(json['resolved_at'] as String) : null,
      selfResolveExpiresAt: json['self_resolve_expires_at'] != null
          ? DateTime.tryParse(json['self_resolve_expires_at'] as String)
          : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': id,
      'order': {
        'uuid': orderId,
        if (orderListingTitle != null) 'listing': {'title': orderListingTitle},
      },
      'raised_by': raisedBy?.toJson(),
      'dispute_type': disputeTypeToApiValue(disputeType),
      'buyer_statement': buyerStatement,
      'buyer_photos': buyerPhotos,
      'seller_statement': sellerStatement,
      'seller_photos': sellerPhotos,
      'self_resolution_offered': selfResolutionOffered,
      'self_resolution_accepted': selfResolutionAccepted,
      'status': switch (status) {
        DisputeStatus.selfResolving => 'self_resolving',
        DisputeStatus.adminReview => 'admin_review',
        DisputeStatus.resolvedRefund => 'resolved_refund',
        DisputeStatus.resolvedRelease => 'resolved_release',
        DisputeStatus.resolvedPartial => 'resolved_partial',
        DisputeStatus.open => 'open',
      },
      'admin': admin?.toJson(),
      'admin_notes': adminNotes,
      'resolved_at': resolvedAt?.toIso8601String(),
      'self_resolve_expires_at': selfResolveExpiresAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
