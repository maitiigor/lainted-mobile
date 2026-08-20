import 'dart:io';

/// API and storage configuration. Base URL is supplied at build time via
/// `--dart-define=API_BASE_URL=...`; falls back to the local backend's
/// /api/v1 prefix for development.
class ApiConstants {
  ApiConstants._();

  static const String _dartDefineBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );

  /// No explicit override -> pick the right localhost alias for the
  /// simulator/emulator we're actually running on: the Android emulator's
  /// virtual network maps `10.0.2.2` to the host machine, but the iOS
  /// Simulator shares the host's network directly, so it needs `localhost`
  /// - using the Android-only alias there just times out every request.
  static String get baseUrl {
    if (_dartDefineBaseUrl.isNotEmpty) return _dartDefineBaseUrl;
    return Platform.isAndroid
        ? 'http://10.0.2.2:8000/api/v1'
        : 'http://localhost:8000/api/v1';
  }

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  /// Laravel registers /broadcasting/auth at the app root, not nested
  /// under /api/v1 like every other endpoint - strip that suffix off
  /// [baseUrl] rather than hardcoding a second host/port pair to keep in
  /// sync.
  static String get broadcastingAuthUrl =>
      '${baseUrl.replaceFirst('/api/v1', '')}/broadcasting/auth';

  static const String _dartDefineReverbHost = String.fromEnvironment(
    'REVERB_HOST',
  );

  /// Same emulator/simulator localhost-alias reasoning as [baseUrl].
  static String get reverbHost {
    if (_dartDefineReverbHost.isNotEmpty) return _dartDefineReverbHost;
    return Platform.isAndroid ? '10.0.2.2' : 'localhost';
  }

  static const int reverbPort = int.fromEnvironment(
    'REVERB_PORT',
    defaultValue: 8080,
  );

  static const bool reverbUseTls = bool.fromEnvironment('REVERB_USE_TLS');

  /// Reverb's app key is embedded in every client connection URL by
  /// design (like Pusher's) - not a secret, unlike REVERB_APP_SECRET
  /// which never leaves the backend. Matches the local dev value in
  /// this project's .env; override via --dart-define for anything else.
  static const String reverbAppKey = String.fromEnvironment(
    'REVERB_APP_KEY',
    defaultValue: '38a5f0e0519be47a48e2',
  );

  // Auth
  static const String otpRequest = '/auth/otp/request';
  static const String otpVerify = '/auth/otp/verify';
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';

  // Users
  static const String me = '/me';
  static const String updatePickupAddress = '/me/pickup-address';
  static const String wardrobeStats = '/me/wardrobe-stats';
  static const String subscriptionPlans = '/subscription-plans';
  static const String subscriptionCheckout = '/subscriptions/checkout';
  static const String confirmSubscriptionPayment = '/subscriptions/payment/confirm';
  static const String deleteAccount = '/me/delete';
  static const String restoreAccount = '/me/restore-account';
  static const String requestPhoneChangeOtp = '/me/phone/request-otp';
  static const String confirmPhoneChange = '/me/phone/confirm';
  static const String lgas = '/lgas';

  // Listings
  static const String categories = '/categories';
  static const String listings = '/listings';
  static String listing(String uuid) => '/listings/$uuid';
  static String publishListing(String uuid) => '/listings/$uuid/publish';
  static String markListingSold(String uuid) => '/listings/$uuid/mark-sold';
  static String listingPhotos(String uuid) => '/listings/$uuid/photos';
  static String listingPhoto(String listingUuid, String photoId) =>
      '/listings/$listingUuid/photos/$photoId';

  // Bundles
  static const String bundles = '/bundles';
  static String bundle(String uuid) => '/bundles/$uuid';

  // Discovery
  static const String discover = '/discover';
  static const String savedListings = '/saved-listings';
  static String saveListing(String uuid) => '/listings/$uuid/save';
  static const String recentlyViewed = '/recently-viewed';

  // Chat
  static const String conversations = '/conversations';
  static String conversation(String uuid) => '/conversations/$uuid';
  static String markConversationRead(String uuid) =>
      '/conversations/$uuid/read';
  static String conversationMessages(String uuid) =>
      '/conversations/$uuid/messages';

  // Negotiation
  static String conversationOffers(String uuid) =>
      '/conversations/$uuid/offers';
  static String counterOffer(String uuid) => '/offers/$uuid/counter';
  static String acceptOffer(String uuid) => '/offers/$uuid/accept';
  static String declineOffer(String uuid) => '/offers/$uuid/decline';
  static String retractOffer(String uuid) => '/offers/$uuid/retract';

  // Orders & checkout
  static const String orders = '/orders';
  static String order(String uuid) => '/orders/$uuid';
  static String checkoutOffer(String uuid) => '/offers/$uuid/checkout';
  static String checkoutListing(String uuid) => '/listings/$uuid/checkout';
  static String confirmOrderPayment(String uuid) => '/orders/$uuid/payment/confirm';
  static String markOrderPrepared(String uuid) => '/orders/$uuid/prepared';
  static String markOrderInTransit(String uuid) => '/orders/$uuid/in-transit';
  static String confirmOrderDelivery(String uuid) => '/orders/$uuid/confirm-delivery';
  static String markOrderDelivered(String uuid) => '/orders/$uuid/mark-delivered';
  static String confirmOrderReceipt(String uuid) => '/orders/$uuid/confirm-receipt';
  static String cancelOrder(String uuid) => '/orders/$uuid/cancel';
  static const String deliveryAddresses = '/delivery-addresses';
  static const String deliveryQuote = '/delivery-quote';

  // Disputes
  static const String disputes = '/disputes';
  static String dispute(String uuid) => '/disputes/$uuid';
  static const String disputePhotos = '/disputes/photos';
  static String raiseDispute(String orderUuid) => '/orders/$orderUuid/disputes';
  static String respondToDispute(String uuid) => '/disputes/$uuid/respond';
  static String acceptDisputeResolution(String uuid) => '/disputes/$uuid/accept-resolution';
  static String rejectDisputeResolution(String uuid) => '/disputes/$uuid/reject-resolution';

  // Trust & Ratings
  static String createReview(String orderUuid) => '/orders/$orderUuid/reviews';
  static String userReviews(String userUuid) => '/users/$userUuid/reviews';
  static String publicProfile(String userUuid) => '/users/$userUuid';
  static const String reports = '/reports';

  // Payments
  static const String wallet = '/wallet';
  static const String walletTransactions = '/wallet/transactions';
  static const String walletWithdraw = '/wallet/withdraw';
  static const String banks = '/banks';
  static const String resolveBankAccount = '/bank-accounts/resolve';
  static const String bankAccounts = '/bank-accounts';
  static String bankAccount(String uuid) => '/bank-accounts/$uuid';

  /// Must match `PaystackService::CALLBACK_URL` on the backend exactly -
  /// flutter_paystack_plus's WebView watches its navigation for a URL
  /// containing this string to know the checkout flow has ended. Doesn't
  /// need to resolve to a real page.
  static const String paystackCallbackUrl = 'https://lainted.app/payment/callback';

  // Blocking
  static const String blockedUsers = '/blocked-users';
  static const String blockUser = '/blocked-users';
  static String unblockUser(String uuid) => '/blocked-users/$uuid';

  // Push notifications
  static const String deviceTokens = '/device-tokens';

  // Secure storage keys
  static const String accessTokenKey = 'access_token';

  // Hive
  static const String prefsBoxName = 'prefs';
  static const String hasSeenOnboardingKey = 'has_seen_onboarding';
}
