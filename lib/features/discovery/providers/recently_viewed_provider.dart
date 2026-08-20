import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../shared/models/listing.dart';
import '../../../shared/providers/dio_provider.dart';

final recentlyViewedProvider = FutureProvider<List<Listing>>((ref) async {
  final response = await ref.read(dioProvider).get(ApiConstants.recentlyViewed);
  final data = response.data['data'] as List<dynamic>;

  return data.map((e) => Listing.fromJson(e as Map<String, dynamic>)).toList();
});
