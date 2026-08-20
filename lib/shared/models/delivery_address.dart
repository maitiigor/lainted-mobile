import 'lga.dart';

class DeliveryAddress {
  const DeliveryAddress({
    required this.id,
    required this.lgaId,
    this.lga,
    required this.landmark,
    required this.fullAddress,
    required this.recipientPhone,
  });

  final String id;
  final int lgaId;
  final Lga? lga;
  final String landmark;

  /// Backend keys are `_encrypted` (the raw Eloquent attribute names) but
  /// values arrive already decrypted - Laravel's encrypted cast is
  /// transparent on read.
  final String fullAddress;
  final String recipientPhone;

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) {
    return DeliveryAddress(
      id: json['uuid'] as String,
      lgaId: json['lga_id'] as int,
      lga: json['lga'] != null
          ? Lga.fromJson(json['lga'] as Map<String, dynamic>)
          : null,
      landmark: json['landmark'] as String,
      fullAddress: json['full_address_encrypted'] as String,
      recipientPhone: json['recipient_phone_encrypted'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': id,
      'lga_id': lgaId,
      'landmark': landmark,
      'full_address_encrypted': fullAddress,
      'recipient_phone_encrypted': recipientPhone,
    };
  }

  String get summary => '$landmark, ${lga?.name ?? ''}';
}
