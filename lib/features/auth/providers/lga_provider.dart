import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../shared/models/lga.dart';
import '../../../shared/providers/dio_provider.dart';

final lgaListProvider = FutureProvider<List<Lga>>((ref) async {
  final response = await ref.read(dioProvider).get(ApiConstants.lgas);
  final data = response.data['data'] as List<dynamic>;

  return data.map((e) => Lga.fromJson(e as Map<String, dynamic>)).toList();
});
