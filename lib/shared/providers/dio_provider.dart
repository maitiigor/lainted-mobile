import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'router_provider.dart';

final dioProvider = Provider<Dio>((ref) {
  return DioClient.create(
    // No BuildContext/navigator lives inside the interceptor itself, so
    // the actual session-clear + redirect happens here instead - both
    // reads are lazy (only evaluated if this ever actually fires), so
    // this isn't a circular dependency at provider-construction time.
    onAccountRestricted: () {
      ref.read(authProvider.notifier).logout();
      ref.read(routerProvider).go('/auth/login');
    },
  );
});
