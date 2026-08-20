import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../shared/providers/dio_provider.dart';

/// "Thin" push scope: register this device's FCM token once the user is
/// signed in, no notification-preference UI, no in-app notification
/// center. OS handles displaying the notification tray entry itself.
class PushRegistrationService {
  PushRegistrationService(this._ref);

  final Ref _ref;

  Future<void> register() async {
    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    await _ref.read(dioProvider).post(
      ApiConstants.deviceTokens,
      data: {
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
      },
    );
  }
}

final pushRegistrationServiceProvider = Provider<PushRegistrationService>((ref) {
  return PushRegistrationService(ref);
});
