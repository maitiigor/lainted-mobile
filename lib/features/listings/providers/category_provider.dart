import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../shared/models/category.dart';
import '../../../shared/providers/dio_provider.dart';

final categoryListProvider = FutureProvider<List<Category>>((ref) async {
  final response = await ref.read(dioProvider).get(ApiConstants.categories);
  final data = response.data['data'] as List<dynamic>;

  return data.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
});
