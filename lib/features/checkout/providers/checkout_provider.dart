import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../shared/models/order.dart';
import '../../../shared/providers/dio_provider.dart';
import '../../orders/providers/orders_provider.dart';

class CheckoutResult {
  const CheckoutResult({required this.order, this.authorizationUrl, this.reference});

  final Order order;

  /// Both null for cash-on-delivery orders - there's no Paystack step to
  /// open. [reference] is needed both to hand to flutter_paystack_plus
  /// (a required param, even though it's functionally inert in
  /// authorizationUrl mode) and for the later confirmPayment() call.
  final String? authorizationUrl;
  final String? reference;
}

/// One-shot checkout actions - no persistent state of its own beyond what
/// [ordersProvider] already owns once an order exists, so a bare
/// `Notifier<void>` is enough to get `ref` access for these calls.
class CheckoutNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<CheckoutResult> checkoutFromOffer(
    String offerId, {
    required String deliveryAddressId,
    required DeliveryTier tier,
    required PaymentMethod method,
    String? email,
  }) {
    return _checkout(ApiConstants.checkoutOffer(offerId), deliveryAddressId, tier, method, email);
  }

  Future<CheckoutResult> checkoutFromListing(
    String listingId, {
    required String deliveryAddressId,
    required DeliveryTier tier,
    required PaymentMethod method,
    String? email,
  }) {
    return _checkout(ApiConstants.checkoutListing(listingId), deliveryAddressId, tier, method, email);
  }

  /// Untrusted client signal only - flutter_paystack_plus's authorizationUrl
  /// mode skips its own verification, so this always hits the backend's
  /// server-side Paystack Verify Transaction call before an order is ever
  /// treated as paid.
  Future<Order> confirmPayment(String orderUuid, String reference) async {
    final response = await ref.read(dioProvider).post(
      ApiConstants.confirmOrderPayment(orderUuid),
      data: {'reference': reference},
    );

    final order = Order.fromJson(response.data['data'] as Map<String, dynamic>);
    await ref.read(ordersProvider.notifier).refresh();

    return order;
  }

  /// Live-preview only - checkoutFromOffer/checkoutFromListing always
  /// re-quote fresh server-side regardless of what this returned, so a
  /// stale/failed preview here never risks charging the wrong amount.
  Future<double> getDeliveryQuote({
    required String listingId,
    required String deliveryAddressId,
    required DeliveryTier tier,
  }) async {
    final response = await ref.read(dioProvider).post(
      ApiConstants.deliveryQuote,
      data: {
        'listing_id': listingId,
        'delivery_address_id': deliveryAddressId,
        'delivery_tier': tier.name,
      },
    );

    return (response.data['data']['fee'] as num).toDouble();
  }

  Future<CheckoutResult> _checkout(
    String path,
    String deliveryAddressId,
    DeliveryTier tier,
    PaymentMethod method,
    String? email,
  ) async {
    final response = await ref.read(dioProvider).post(
      path,
      data: {
        'delivery_address_id': deliveryAddressId,
        'delivery_tier': tier.name,
        'payment_method': method == PaymentMethod.cashOnDelivery ? 'cash_on_delivery' : 'online',
        'email': ?email,
      },
    );

    final data = response.data['data'] as Map<String, dynamic>;
    final order = Order.fromJson(data['order'] as Map<String, dynamic>);

    await ref.read(ordersProvider.notifier).refresh();

    return CheckoutResult(
      order: order,
      authorizationUrl: data['authorization_url'] as String?,
      reference: data['reference'] as String?,
    );
  }
}

final checkoutProvider = NotifierProvider<CheckoutNotifier, void>(CheckoutNotifier.new);
