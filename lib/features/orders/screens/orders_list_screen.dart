import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/order.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/orders_provider.dart';

enum _OrderRole { buying, selling }

/// A user can be both buyer and seller across different orders, so this
/// is one flat list from `GET /orders` filtered client-side by role,
/// rather than two separate endpoints.
class OrdersListScreen extends ConsumerStatefulWidget {
  const OrdersListScreen({super.key});

  @override
  ConsumerState<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends ConsumerState<OrdersListScreen> {
  _OrderRole _role = _OrderRole.buying;

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersProvider);
    final currentUserId = ref.watch(authProvider).value?.id;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Orders')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SegmentedButton<_OrderRole>(
              segments: const [
                ButtonSegment(value: _OrderRole.buying, label: Text('Buying')),
                ButtonSegment(value: _OrderRole.selling, label: Text('Selling')),
              ],
              selected: {_role},
              onSelectionChanged: (selection) => setState(() => _role = selection.first),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(ordersProvider.notifier).refresh(),
              child: ordersAsync.when(
                data: (orders) {
                  final filtered = orders
                      .where(
                        (o) => _role == _OrderRole.buying
                            ? o.buyer?.id == currentUserId
                            : o.seller?.id == currentUserId,
                      )
                      .toList();

                  if (filtered.isEmpty) {
                    return ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                          child: Center(
                            child: Text(
                              _role == _OrderRole.buying ? 'No purchases yet.' : 'No sales yet.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.textMuted),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) => _OrderRow(order: filtered[index]),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Text(
                    'Could not load orders.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.error),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});

  final Order order;

  String get _statusLabel {
    switch (order.status) {
      case OrderStatus.pending:
        return 'Awaiting payment';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.prepared:
        return 'Prepared';
      case OrderStatus.inTransit:
        return 'In transit';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = order.listing?.photos ?? const [];

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: photos.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: Image.network(
                photos.first.url,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            )
          : Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: const Icon(Icons.image_outlined, color: AppColors.textMuted),
            ),
      title: Text(
        order.listing?.title ?? 'Order',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(_statusLabel),
      trailing: Text(
        Formatters.currency(order.totalAmount),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      onTap: () => context.push('/orders/${order.id}'),
    );
  }
}
