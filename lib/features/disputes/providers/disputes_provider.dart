import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../shared/models/dispute.dart';
import '../../../shared/providers/dio_provider.dart';

/// The current user's disputes (as buyer and/or seller). Mutations return
/// the updated Dispute directly - callers (usually a detail screen that
/// already has its own local copy) patch it in themselves, the same
/// division of responsibility as OrdersNotifier's action methods.
class DisputesNotifier extends AsyncNotifier<List<Dispute>> {
  @override
  Future<List<Dispute>> build() async {
    final response = await ref.read(dioProvider).get(ApiConstants.disputes);
    final data = response.data['data'] as List<dynamic>;

    return data.map((e) => Dispute.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  Future<Dispute> getDispute(String uuid) async {
    final response = await ref.read(dioProvider).get(ApiConstants.dispute(uuid));

    return Dispute.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<Dispute> raise(
    String orderUuid, {
    required DisputeType disputeType,
    required String buyerStatement,
    List<String>? buyerPhotos,
  }) {
    return _mutate(
      ApiConstants.raiseDispute(orderUuid),
      data: {
        'dispute_type': disputeTypeToApiValue(disputeType),
        'buyer_statement': buyerStatement,
        'buyer_photos': buyerPhotos,
      },
    );
  }

  Future<Dispute> respond(
    String uuid, {
    required String sellerStatement,
    List<String>? sellerPhotos,
    double? selfResolutionOffered,
  }) {
    return _mutate(
      ApiConstants.respondToDispute(uuid),
      data: {
        'seller_statement': sellerStatement,
        'seller_photos': sellerPhotos,
        'self_resolution_offered': selfResolutionOffered,
      },
    );
  }

  Future<Dispute> acceptResolution(String uuid) => _mutate(ApiConstants.acceptDisputeResolution(uuid));

  Future<Dispute> rejectResolution(String uuid) => _mutate(ApiConstants.rejectDisputeResolution(uuid));

  /// Evidence photos are uploaded one at a time before the dispute (or
  /// response) they'll be attached to even exists - the returned URL
  /// goes straight into that request's buyer_photos/seller_photos array.
  Future<String> uploadPhoto({required List<int> bytes, required String filename}) async {
    final formData = FormData.fromMap({
      'photo': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await ref.read(dioProvider).post(ApiConstants.disputePhotos, data: formData);

    return response.data['data']['url'] as String;
  }

  Future<Dispute> _mutate(String path, {Map<String, dynamic>? data}) async {
    final response = await ref.read(dioProvider).post(path, data: data);
    final dispute = Dispute.fromJson(response.data['data'] as Map<String, dynamic>);

    await _replaceInList(dispute);

    return dispute;
  }

  Future<void> _replaceInList(Dispute dispute) async {
    final current = await future;
    final index = current.indexWhere((d) => d.id == dispute.id);
    if (index == -1) return;

    final updated = [...current];
    updated[index] = dispute;
    state = AsyncData(updated);
  }
}

final disputesProvider = AsyncNotifierProvider<DisputesNotifier, List<Dispute>>(
  DisputesNotifier.new,
);
