import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../shared/models/user.dart';
import '../../../shared/providers/dio_provider.dart';

class BlockedUsersNotifier extends AsyncNotifier<List<User>> {
  @override
  Future<List<User>> build() => _fetch();

  Future<List<User>> _fetch() async {
    final response = await ref.read(dioProvider).get(ApiConstants.blockedUsers);
    final data = response.data['data'] as List<dynamic>;

    return data.map((e) => User.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> block(User user, {String? reason}) async {
    await ref.read(dioProvider).post(
      ApiConstants.blockUser,
      data: {'user_id': user.id, 'reason': ?reason},
    );
    await refresh();
  }

  Future<void> unblock(User user) async {
    await ref.read(dioProvider).delete(ApiConstants.unblockUser(user.id));
    await refresh();
  }
}

final blockedUsersProvider =
    AsyncNotifierProvider<BlockedUsersNotifier, List<User>>(
      BlockedUsersNotifier.new,
    );

final blockedUserIdsProvider = Provider<Set<String>>((ref) {
  return ref.watch(blockedUsersProvider).value?.map((u) => u.id).toSet() ?? {};
});
