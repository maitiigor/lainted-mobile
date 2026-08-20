import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/api_constants.dart';

/// Whether the onboarding carousel has already been shown on this device.
/// Not sensitive data, so Hive rather than secure storage.
class OnboardingPrefs {
  Box get _box => Hive.box(ApiConstants.prefsBoxName);

  bool get hasSeenOnboarding =>
      _box.get(ApiConstants.hasSeenOnboardingKey, defaultValue: false) as bool;

  Future<void> markOnboardingSeen() =>
      _box.put(ApiConstants.hasSeenOnboardingKey, true);
}

final onboardingPrefsProvider = Provider<OnboardingPrefs>((ref) {
  return OnboardingPrefs();
});
