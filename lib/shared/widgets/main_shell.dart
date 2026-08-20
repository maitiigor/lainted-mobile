import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/chat/screens/conversations_list_screen.dart';
import '../../features/discovery/screens/home_feed_screen.dart';
import '../../features/listings/screens/my_listings_screen.dart';
import '../../features/orders/screens/orders_list_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../models/user.dart';

/// Bottom-nav shell for the signed-in app. Plain `IndexedStack` +
/// `BottomNavigationBar` rather than a `StatefulShellRoute` - the
/// Profile tab doesn't need an independent back-stack yet, so the
/// simpler widget is enough. Orders now pushes its own detail route
/// (`/orders/:id`) from on top of this shell, same as every other tab's
/// drill-down screens.
///
/// The "My Listings" tab only exists for `seller_type != none` - a buyer
/// account has no seller role and the backend already 403s them out of
/// creating a listing (see StoreListingRequest::authorize()), so showing
/// a fully-functional "Create a listing" tab to someone who can't
/// actually use it was a real gap, not just a missing explanation.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final sellerType = ref.watch(authProvider).value?.sellerType;
    final isSeller = sellerType != null && sellerType != SellerType.none;

    final tabs = [
      const HomeFeedScreen(),
      if (isSeller) const MyListingsScreen(),
      const ConversationsListScreen(),
      const OrdersListScreen(),
      const ProfileScreen(),
    ];

    final items = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.storefront_outlined),
        label: 'Home',
      ),
      if (isSeller)
        const BottomNavigationBarItem(
          icon: Icon(Icons.inventory_2_outlined),
          label: 'My Listings',
        ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.chat_bubble_outline),
        label: 'Chat',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.receipt_long_outlined),
        label: 'Orders',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        label: 'Profile',
      ),
    ];

    // Guards the rare mid-session transition (a buyer completes seller
    // profile setup while sitting on a tab index that no longer exists
    // once the list shrinks/grows) rather than crashing IndexedStack.
    final currentIndex = _index < tabs.length ? _index : 0;

    return Scaffold(
      body: IndexedStack(index: currentIndex, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => setState(() => _index = index),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        items: items,
      ),
    );
  }
}
