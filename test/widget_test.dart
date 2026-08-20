import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lainted_mobile/features/auth/providers/auth_provider.dart';
import 'package:lainted_mobile/main.dart';
import 'package:lainted_mobile/shared/models/user.dart';
import 'package:lainted_mobile/shared/providers/onboarding_prefs_provider.dart';

class _SignedOutAuthNotifier extends AuthNotifier {
  @override
  Future<User?> build() async => null;
}

class _FakeOnboardingPrefs implements OnboardingPrefs {
  @override
  bool get hasSeenOnboarding => true;

  @override
  Future<void> markOnboardingSeen() async {}
}

void main() {
  testWidgets('Signed-out returning device boots to password login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_SignedOutAuthNotifier.new),
          onboardingPrefsProvider.overrideWithValue(_FakeOnboardingPrefs()),
        ],
        child: const LaintedApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back 👋'), findsOneWidget);
  });
}
