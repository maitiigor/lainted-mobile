import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/screens/blocked_users_screen.dart';
import '../../features/account/screens/change_phone_screen.dart';
import '../../features/account/screens/restore_account_screen.dart';
import '../../features/account/screens/subscription_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/otp_entry_screen.dart';
import '../../features/auth/screens/password_login_screen.dart';
import '../../features/auth/screens/phone_entry_screen.dart';
import '../../features/auth/screens/profile_setup_screen.dart';
import '../../features/auth/screens/set_password_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/checkout/screens/checkout_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/disputes/screens/dispute_detail_screen.dart';
import '../../features/disputes/screens/raise_dispute_screen.dart';
import '../../features/discovery/models/discovery_filters.dart';
import '../../features/discovery/screens/browse_all_screen.dart';
import '../../features/discovery/screens/preset_listings_screen.dart';
import '../../features/discovery/screens/saved_and_recent_screen.dart';
import '../../features/listings/screens/bundle_create_screen.dart';
import '../../features/listings/screens/listing_detail_screen.dart';
import '../../features/listings/screens/listing_form_screen.dart';
import '../../features/listings/screens/listing_photos_screen.dart';
import '../../features/listings/screens/wardrobe_quick_list_screen.dart';
import '../../features/orders/screens/order_detail_screen.dart';
import '../../features/orders/screens/orders_list_screen.dart';
import '../../features/payments/screens/bank_accounts_screen.dart';
import '../../features/payments/screens/transaction_history_screen.dart';
import '../../features/payments/screens/wallet_screen.dart';
import '../../features/payments/screens/withdraw_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/trust/screens/public_profile_screen.dart';
import '../models/listing.dart';
import '../models/offer.dart';
import '../widgets/main_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      // Primary door for returning users (no SMS cost) - not in the
      // original 10-route list, added once it became clear OTP-on-every
      // -login doesn't scale (Termii charges per SMS).
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const PasswordLoginScreen(),
      ),
      // Phone/OTP is now only for first-time signup and "forgot password".
      GoRoute(
        path: '/auth/phone',
        builder: (context, state) => const PhoneEntryScreen(),
      ),
      GoRoute(
        path: '/auth/otp',
        builder: (context, state) => OtpEntryScreen(phone: state.extra as String),
      ),
      // Shown once right after OTP verification for a brand-new account,
      // before profile completion.
      GoRoute(
        path: '/auth/set-password',
        builder: (context, state) => const SetPasswordScreen(),
      ),
      // Not in the original 10-route list - added once it became clear
      // profile setup needs its own screen between OTP and Home.
      GoRoute(
        path: '/auth/profile-setup',
        builder: (context, state) => ProfileSetupScreen(password: state.extra as String?),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const MainShell(),
      ),
      GoRoute(
        path: '/account/restore',
        builder: (context, state) => const RestoreAccountScreen(),
      ),
      GoRoute(
        path: '/account/edit',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/account/change-phone',
        builder: (context, state) => const ChangePhoneScreen(),
      ),
      GoRoute(
        path: '/account/blocked-users',
        builder: (context, state) => const BlockedUsersScreen(),
      ),
      GoRoute(
        path: '/account/subscription',
        builder: (context, state) => const SubscriptionScreen(),
      ),
      GoRoute(
        path: '/listings/create',
        builder: (context, state) => const ListingFormScreen(),
      ),
      GoRoute(
        path: '/listings/create/wardrobe',
        builder: (context, state) => const WardrobeQuickListScreen(),
      ),
      GoRoute(
        path: '/listings/:id/edit',
        builder: (context, state) => ListingFormScreen(
          listingId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/listings/:id',
        builder: (context, state) => ListingDetailScreen(
          listingId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/listings/:id/photos',
        builder: (context, state) => ListingPhotosScreen(
          listingId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/bundles/create',
        builder: (context, state) => const BundleCreateScreen(),
      ),
      GoRoute(
        path: '/saved',
        builder: (context, state) => const SavedAndRecentScreen(),
      ),
      GoRoute(
        path: '/browse',
        builder: (context, state) => const BrowseAllScreen(),
      ),
      GoRoute(
        path: '/preset-listings',
        builder: (context, state) {
          final (title, filters) = state.extra! as (String, DiscoveryFilters);
          return PresetListingsScreen(title: title, filters: filters);
        },
      ),
      GoRoute(
        path: '/chat/:conversationId',
        builder: (context, state) => ChatScreen(
          conversationId: state.pathParameters['conversationId']!,
        ),
      ),
      GoRoute(
        path: '/profile/:userId',
        builder: (context, state) => PublicProfileScreen(
          userId: state.pathParameters['userId']!,
        ),
      ),
      GoRoute(
        path: '/orders',
        builder: (context, state) => const OrdersListScreen(),
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (context, state) => OrderDetailScreen(
          orderId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/wallet',
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: '/wallet/withdraw',
        builder: (context, state) => const WithdrawScreen(),
      ),
      GoRoute(
        path: '/wallet/transactions',
        builder: (context, state) => const TransactionHistoryScreen(),
      ),
      GoRoute(
        path: '/wallet/bank-accounts',
        builder: (context, state) => const BankAccountsScreen(),
      ),
      GoRoute(
        path: '/orders/:id/dispute/raise',
        builder: (context, state) => RaiseDisputeScreen(
          orderId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/disputes/:id',
        builder: (context, state) => DisputeDetailScreen(
          disputeId: state.pathParameters['id']!,
        ),
      ),
      // No single-offer GET endpoint exists on the backend (offers are
      // only ever returned embedded in conversation/message payloads), so
      // the full Offer/Listing object is passed via `extra` rather than
      // re-fetched by id here.
      GoRoute(
        path: '/checkout/offer',
        builder: (context, state) => CheckoutScreen.fromOffer(offer: state.extra! as Offer),
      ),
      GoRoute(
        path: '/checkout/listing',
        builder: (context, state) => CheckoutScreen.fromListing(listing: state.extra! as Listing),
      ),
    ],
  );
});
