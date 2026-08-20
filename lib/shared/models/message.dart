import 'offer.dart';
import 'user.dart';

/// Message card type - "offer" renders as a special negotiation card in
/// chat, "system" is used for automated notices (e.g. contact-leak warnings).
enum MessageType { text, image, offer, system }

MessageType messageTypeFromString(String? value) {
  return MessageType.values.firstWhere(
    (e) => e.name == value,
    orElse: () => MessageType.text,
  );
}

class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.sender,
    this.type = MessageType.text,
    this.body,
    this.imageUrl,
    this.offerId,
    this.offer,
    this.isFlagged = false,
    this.readAt,
    this.createdAt,
  });

  final String id;

  /// Raw bigint FKs, not uuids - see Conversation.buyerId/sellerId. Never
  /// compare these against `User.id` - use [sender] instead.
  final String conversationId;
  final String senderId;

  final User? sender;
  final MessageType type;
  final String? body;
  final String? imageUrl;

  /// Set only when [type] is offer - the negotiation-card content, with
  /// its own nested buyer/seller/listing for identity checks. [offerId] is
  /// [offer]'s own uuid, NOT the raw `offer_id` bigint FK the backend
  /// sends - that FK lives in the same id-space as `conversationId`, not
  /// `Offer.id`, so matching against it would silently never find a hit.
  final String? offerId;
  final Offer? offer;

  /// Set when the anti-leakage contact detector redacted content in [body].
  final bool isFlagged;
  final DateTime? readAt;
  final DateTime? createdAt;

  factory Message.fromJson(Map<String, dynamic> json) {
    final offer = json['offer'] != null
        ? Offer.fromJson(json['offer'] as Map<String, dynamic>)
        : null;

    return Message(
      id: json['uuid'] as String,
      conversationId: json['conversation_id'].toString(),
      senderId: json['sender_id'].toString(),
      sender: json['sender'] != null
          ? User.fromJson(json['sender'] as Map<String, dynamic>)
          : null,
      type: messageTypeFromString(json['type'] as String?),
      body: json['body'] as String?,
      imageUrl: json['image_url'] as String?,
      offerId: offer?.id,
      offer: offer,
      isFlagged: json['is_flagged'] as bool? ?? false,
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'sender': sender?.toJson(),
      'type': type.name,
      'body': body,
      'image_url': imageUrl,
      'offer_id': offerId,
      'offer': offer?.toJson(),
      'is_flagged': isFlagged,
      'read_at': readAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
