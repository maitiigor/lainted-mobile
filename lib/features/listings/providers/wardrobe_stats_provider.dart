import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../shared/models/wardrobe_stats.dart';
import '../../../shared/providers/dio_provider.dart';

final wardrobeStatsProvider = FutureProvider<WardrobeStats>((ref) async {
  final response = await ref.read(dioProvider).get(ApiConstants.wardrobeStats);

  return WardrobeStats.fromJson(response.data['data'] as Map<String, dynamic>);
});
