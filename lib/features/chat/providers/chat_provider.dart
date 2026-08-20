import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../shared/models/message.dart';
import '../../../shared/models/offer.dart';
import '../../../shared/providers/dio_provider.dart';
import 'reverb_socket_provider.dart';

/// Messages for a single conversation, keyed by conversationId (uuid).
class ChatNotifier extends FamilyAsyncNotifier<List<Message>, String> {
  Timer? _typingDebounce;

  @override
  Future<List<Message>> build(String conversationId) async {
    final messages = await _fetch(conversationId);
    await _subscribe(conversationId);
    ref.onDispose(() {
      _typingDebounce?.cancel();
      ref.read(reverbSocketProvider).unsubscribe('private-conversation.$conversationId');
    });

    return messages;
  }

  Future<List<Message>> _fetch(String conversationId) async {
    final response = await ref
        .read(dioProvider)
        .get(ApiConstants.conversationMessages(conversationId));
    final data = response.data['data'] as List<dynamic>;

    return data.map((e) => Message.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> _subscribe(String conversationId) async {
    final socket = ref.read(reverbSocketProvider);
    await socket.connect();
    await socket.listen(
      channelName: 'private-conversation.$conversationId',
      eventName: 'message.sent',
      onEvent: (data) => _appendMessage(Message.fromJson(data as Map<String, dynamic>)),
    );
    await socket.listen(
      channelName: 'private-conversation.$conversationId',
      eventName: 'offer.updated',
      onEvent: (data) => _updateOffer(Offer.fromJson(data as Map<String, dynamic>)),
    );
  }

  Future<void> sendMessage(String body) async {
    final conversationId = arg;
    final response = await ref.read(dioProvider).post(
      ApiConstants.conversationMessages(conversationId),
      data: {'type': 'text', 'body': body},
    );
    await _appendMessage(Message.fromJson(response.data['data'] as Map<String, dynamic>));
  }

  Future<void> sendImage({required List<int> bytes, required String filename}) async {
    final conversationId = arg;
    final formData = FormData.fromMap({
      'type': 'image',
      'image': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await ref
        .read(dioProvider)
        .post(ApiConstants.conversationMessages(conversationId), data: formData);
    await _appendMessage(Message.fromJson(response.data['data'] as Map<String, dynamic>));
  }

  /// Always waits for the initial `build()` to have actually settled
  /// before touching `state` - `build()` here does a GET plus an async
  /// socket connect+subscribe, so appending straight to `state.value`
  /// while that's still in flight was a real bug: whichever finished
  /// last - our manual append, or `build()` finally resolving - won, and
  /// `build()` finishing second silently clobbered the just-sent message
  /// back to the pre-send list. Awaiting `future` guarantees there's no
  /// pending `build()` left that could still overwrite us afterwards.
  Future<void> _appendMessage(Message message) async {
    final current = await future;

    if (current.any((m) => m.id == message.id)) return;
    state = AsyncData([...current, message]);
  }

  /// Patches the offer nested inside whichever message wraps it, in place -
  /// used both for the live `offer.updated` broadcast (the other party) and
  /// for accept/decline/retract's own direct response (no new message is
  /// created by those three, so there's nothing to append, only to patch).
  Future<void> _updateOffer(Offer offer) async {
    final current = await future;
    final index = current.indexWhere((m) => m.offerId == offer.id);
    if (index == -1) return;

    final message = current[index];
    final updated = [...current];
    updated[index] = Message(
      id: message.id,
      conversationId: message.conversationId,
      senderId: message.senderId,
      sender: message.sender,
      type: message.type,
      body: message.body,
      imageUrl: message.imageUrl,
      offerId: message.offerId,
      offer: offer,
      isFlagged: message.isFlagged,
      readAt: message.readAt,
      createdAt: message.createdAt,
    );
    state = AsyncData(updated);
  }

  /// create/counter only return the bare `Offer` from their POST response,
  /// with no id for the new wrapping `Message` the backend created as a
  /// side effect - and since that message's own `MessageSent` broadcast
  /// goes out `->toOthers()`, the sender never receives it over the socket
  /// either. A full refetch is the only way the sender's own client learns
  /// that message's real id, short of changing the backend's response
  /// shape - a fine trade for an infrequent, deliberate action like this.
  Future<void> _refresh() async {
    await future;
    final messages = await _fetch(arg);
    state = AsyncData(messages);
  }

  Future<void> makeOffer(double amount) async {
    await ref.read(dioProvider).post(
      ApiConstants.conversationOffers(arg),
      data: {'amount': amount},
    );
    await _refresh();
  }

  Future<void> counterOffer(String offerId, double amount) async {
    await ref.read(dioProvider).post(
      ApiConstants.counterOffer(offerId),
      data: {'amount': amount},
    );
    await _refresh();
  }

  Future<void> acceptOffer(String offerId) async {
    final response = await ref.read(dioProvider).post(ApiConstants.acceptOffer(offerId));
    await _updateOffer(Offer.fromJson(response.data['data'] as Map<String, dynamic>));
  }

  Future<void> declineOffer(String offerId) async {
    final response = await ref.read(dioProvider).post(ApiConstants.declineOffer(offerId));
    await _updateOffer(Offer.fromJson(response.data['data'] as Map<String, dynamic>));
  }

  Future<void> retractOffer(String offerId) async {
    final response = await ref.read(dioProvider).post(ApiConstants.retractOffer(offerId));
    await _updateOffer(Offer.fromJson(response.data['data'] as Map<String, dynamic>));
  }

  /// Ephemeral, no persistence, no backend round-trip - a client event
  /// relayed directly between subscribed clients by Reverb. Debounced so
  /// every keystroke doesn't fire a separate signal.
  void notifyTyping() {
    if (_typingDebounce?.isActive ?? false) return;

    _typingDebounce = Timer(const Duration(seconds: 2), () {});
    ref
        .read(reverbSocketProvider)
        .whisper('private-conversation.$arg', 'typing', const {'typing': true});
  }
}

final chatProvider =
    AsyncNotifierProvider.family<ChatNotifier, List<Message>, String>(
  ChatNotifier.new,
);
