import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/constants/api_constants.dart';
import '../../../shared/models/user.dart';
import '../../../shared/providers/dio_provider.dart';

const _secureStorage = FlutterSecureStorage();

/// Holds the current authenticated user (null when signed out).
class AuthNotifier extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    final token = await _secureStorage.read(key: ApiConstants.accessTokenKey);
    if (token == null) return null;

    try {
      final response = await ref.read(dioProvider).get(ApiConstants.me);
      return User.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException {
      // Stored token is invalid/expired - fall back to signed-out.
      await _secureStorage.delete(key: ApiConstants.accessTokenKey);
      return null;
    }
  }

  /// Returns true if this phone has no account yet.
  Future<bool> requestOtp(String phone) async {
    final response = await ref
        .read(dioProvider)
        .post(ApiConstants.otpRequest, data: {'phone': phone});

    return response.data['data']['is_new_user'] as bool;
  }

  /// Returns true if the mobile app should route to profile setup next.
  Future<bool> verifyOtp(String phone, String code) async {
    final response = await ref.read(dioProvider).post(
      ApiConstants.otpVerify,
      data: {'phone': phone, 'code': code},
    );

    final data = response.data['data'] as Map<String, dynamic>;
    await _secureStorage.write(
      key: ApiConstants.accessTokenKey,
      value: data['token'] as String,
    );

    state = AsyncData(User.fromJson(data['user'] as Map<String, dynamic>));

    return data['needs_profile_setup'] as bool;
  }

  /// Fast alternative to OTP for returning users, so a login doesn't cost an
  /// SMS every time. Returns true if the app should route to profile setup.
  Future<bool> loginWithPassword(String phone, String password) async {
    final response = await ref.read(dioProvider).post(
      ApiConstants.login,
      data: {'phone': phone, 'password': password},
    );

    final data = response.data['data'] as Map<String, dynamic>;
    await _secureStorage.write(
      key: ApiConstants.accessTokenKey,
      value: data['token'] as String,
    );

    state = AsyncData(User.fromJson(data['user'] as Map<String, dynamic>));

    return data['needs_profile_setup'] as bool;
  }

  Future<void> updateProfile({
    required String name,
    required String sellerType,
    required bool acceptedAgreement,
    String? email,
    int? lgaId,
    String? landmark,
    String? bio,
    String? verificationType,
    String? verificationNumber,
    String? password,
    String? passwordConfirmation,
    List<int>? photoBytes,
    String? photoFilename,
  }) async {
    final formData = FormData.fromMap({
      'name': name,
      'seller_type': sellerType,
      'accepted_agreement': acceptedAgreement,
      'email': ?email,
      'lga_id': ?lgaId,
      'landmark': ?landmark,
      'bio': ?bio,
      'verification_type': ?verificationType,
      'verification_number': ?verificationNumber,
      'password': ?password,
      'password_confirmation': ?passwordConfirmation,
      if (photoBytes != null)
        'photo': MultipartFile.fromBytes(photoBytes, filename: photoFilename),
    });

    final response = await ref.read(dioProvider).post(
      ApiConstants.me,
      data: formData,
    );

    state = AsyncData(User.fromJson(response.data['data'] as Map<String, dynamic>));
  }

  /// The address itself is created via the existing generic delivery-
  /// addresses provider/endpoint - this just points the current user at
  /// one they already own as their saved pickup location.
  Future<void> setPickupAddress(String deliveryAddressId) async {
    final response = await ref.read(dioProvider).post(
      ApiConstants.updatePickupAddress,
      data: {'delivery_address_id': deliveryAddressId},
    );

    state = AsyncData(User.fromJson(response.data['data'] as Map<String, dynamic>));
  }

  /// Doesn't change local state - the natural next step after requesting
  /// deletion is logging out (see profile_screen.dart), not staying
  /// signed in with a "pending deletion" account.
  Future<void> deleteAccount() async {
    await ref.read(dioProvider).post(ApiConstants.deleteAccount);
  }

  Future<void> restoreAccount() async {
    final response = await ref.read(dioProvider).post(ApiConstants.restoreAccount);

    state = AsyncData(User.fromJson(response.data['data'] as Map<String, dynamic>));
  }

  Future<void> requestPhoneChangeOtp(String phone) async {
    await ref.read(dioProvider).post(ApiConstants.requestPhoneChangeOtp, data: {'phone': phone});
  }

  Future<void> confirmPhoneChange(String phone, String code) async {
    final response = await ref.read(dioProvider).post(
      ApiConstants.confirmPhoneChange,
      data: {'phone': phone, 'code': code},
    );

    state = AsyncData(User.fromJson(response.data['data'] as Map<String, dynamic>));
  }

  Future<void> confirmSubscriptionPayment(String reference) async {
    final response = await ref.read(dioProvider).post(
      ApiConstants.confirmSubscriptionPayment,
      data: {'reference': reference},
    );

    state = AsyncData(User.fromJson(response.data['data'] as Map<String, dynamic>));
  }

  Future<void> logout() async {
    try {
      await ref.read(dioProvider).post(ApiConstants.logout);
    } on DioException {
      // Token may already be invalid server-side - clearing it locally is
      // what actually matters for logout.
    }

    await _secureStorage.delete(key: ApiConstants.accessTokenKey);
    state = const AsyncData(null);
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, User?>(
  AuthNotifier.new,
);
