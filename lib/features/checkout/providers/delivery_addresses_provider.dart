import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../shared/models/delivery_address.dart';
import '../../../shared/providers/dio_provider.dart';

class DeliveryAddressesNotifier extends AsyncNotifier<List<DeliveryAddress>> {
  @override
  Future<List<DeliveryAddress>> build() async {
    final response = await ref.read(dioProvider).get(ApiConstants.deliveryAddresses);
    final data = response.data['data'] as List<dynamic>;

    return data.map((e) => DeliveryAddress.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<DeliveryAddress> create({
    required int lgaId,
    required String landmark,
    required String fullAddress,
    required String recipientPhone,
  }) async {
    final response = await ref.read(dioProvider).post(
      ApiConstants.deliveryAddresses,
      data: {
        'lga_id': lgaId,
        'landmark': landmark,
        'full_address': fullAddress,
        'recipient_phone': recipientPhone,
      },
    );

    final address = DeliveryAddress.fromJson(response.data['data'] as Map<String, dynamic>);
    await _appendAddress(address);

    return address;
  }

  /// Waits for the initial build() to have settled before touching state -
  /// same guard ChatNotifier._appendMessage established.
  Future<void> _appendAddress(DeliveryAddress address) async {
    final current = await future;
    state = AsyncData([...current, address]);
  }
}

final deliveryAddressesProvider =
    AsyncNotifierProvider<DeliveryAddressesNotifier, List<DeliveryAddress>>(
  DeliveryAddressesNotifier.new,
);
