import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../shared/models/conversation.dart';
import '../../../shared/providers/dio_provider.dart';

class ConversationsNotifier extends AsyncNotifier<List<Conversation>> {
  @override
  Future<List<Conversation>> build() => _fetch();

  Future<List<Conversation>> _fetch() async {
    final response = await ref.read(dioProvider).get(ApiConstants.conversations);
    final data = response.data['data'] as List<dynamic>;

    return data
        .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Chat is buyer-initiated from the listing page - starting again on
  /// an already-existing thread just returns that same conversation
  /// (backend does firstOrCreate on listing_id+buyer_id).
  Future<Conversation> startConversation(String listingUuid) async {
    final response = await ref
        .read(dioProvider)
        .post(ApiConstants.conversations, data: {'listing_id': listingUuid});
    await refresh();

    return Conversation.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> markRead(String conversationUuid) async {
    await ref.read(dioProvider).post(ApiConstants.markConversationRead(conversationUuid));
  }
}

final conversationsProvider =
    AsyncNotifierProvider<ConversationsNotifier, List<Conversation>>(
      ConversationsNotifier.new,
    );
