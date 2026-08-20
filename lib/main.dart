import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/constants/api_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/notifications/services/push_registration_service.dart';
import 'shared/providers/router_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox(ApiConstants.prefsBoxName);

  try {
    // No google-services.json/GoogleService-Info.plist configured yet in
    // this project (matches the backend's own missing Firebase
    // service-account credential) - degrade gracefully, same as every
    // other optional third-party integration in this app, rather than
    // crashing the whole app at launch over an unconfigured push feature.
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init skipped: $e');
  }

  runApp(const ProviderScope(child: LaintedApp()));
}

class LaintedApp extends ConsumerWidget {
  const LaintedApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    ref.listen(authProvider, (previous, next) {
      final justSignedIn = next.value != null && previous?.value == null;
      if (justSignedIn) {
        ref.read(pushRegistrationServiceProvider).register().catchError((_) {});
      }
    });

    return MaterialApp.router(
      title: 'Lainted',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
