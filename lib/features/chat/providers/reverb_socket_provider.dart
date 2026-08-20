import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/dio_provider.dart';
import '../services/reverb_socket_service.dart';

/// App-lifetime singleton - the underlying WebSocket connects lazily
/// (see ReverbSocketService.connect()), called by whichever provider
/// first needs to listen on a channel, not eagerly at app start.
final reverbSocketProvider = Provider<ReverbSocketService>((ref) {
  final service = ReverbSocketService(ref.read(dioProvider));
  ref.onDispose(service.dispose);

  return service;
});
