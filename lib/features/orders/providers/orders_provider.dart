import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../shared/models/order.dart';
import '../../../shared/providers/dio_provider.dart';

/// The current user's orders (as buyer and/or seller).
class OrdersNotifier extends AsyncNotifier<List<Order>> {
  @override
  Future<List<Order>> build() async {
    final response = await ref.read(dioProvider).get(ApiConstants.orders);
    final data = response.data['data'] as List<dynamic>;

    return data.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  Future<Order> getOrder(String uuid) async {
    final response = await ref.read(dioProvider).get(ApiConstants.order(uuid));

    return Order.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<Order> markPrepared(String uuid) => _mutate(ApiConstants.markOrderPrepared(uuid));

  Future<Order> markInTransit(
    String uuid, {
    String? logisticsProvider,
    required String trackingReference,
  }) {
    return _mutate(
      ApiConstants.markOrderInTransit(uuid),
      data: {
        'logistics_provider': ?logisticsProvider,
        'tracking_reference': trackingReference,
      },
    );
  }

  Future<Order> confirmDelivery(String uuid, String code) {
    return _mutate(ApiConstants.confirmOrderDelivery(uuid), data: {'code': code});
  }

  Future<Order> markDelivered(String uuid) => _mutate(ApiConstants.markOrderDelivered(uuid));

  Future<Order> confirmReceipt(String uuid) => _mutate(ApiConstants.confirmOrderReceipt(uuid));

  Future<Order> cancel(String uuid) => _mutate(ApiConstants.cancelOrder(uuid));

  Future<Order> _mutate(String path, {Map<String, dynamic>? data}) async {
    final response = await ref.read(dioProvider).post(path, data: data);
    final order = Order.fromJson(response.data['data'] as Map<String, dynamic>);

    await _replaceInList(order);

    return order;
  }

  /// Waits for the initial build() to have settled before touching state -
  /// same guard ChatNotifier._appendMessage established, needed since
  /// build() here does its own async GET.
  Future<void> _replaceInList(Order order) async {
    final current = await future;
    final index = current.indexWhere((o) => o.id == order.id);
    if (index == -1) return;

    final updated = [...current];
    updated[index] = order;
    state = AsyncData(updated);
  }
}

final ordersProvider = AsyncNotifierProvider<OrdersNotifier, List<Order>>(
  OrdersNotifier.new,
);
