import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../shared/models/wallet_account.dart';
import '../../../shared/models/wallet_transaction.dart';
import '../../../shared/providers/dio_provider.dart';

/// In-app wallet balance + loyalty points for the current user.
class WalletNotifier extends AsyncNotifier<WalletAccount?> {
  @override
  Future<WalletAccount?> build() async {
    final response = await ref.read(dioProvider).get(ApiConstants.wallet);

    return WalletAccount.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  Future<List<WalletTransaction>> transactions() async {
    final response = await ref.read(dioProvider).get(ApiConstants.walletTransactions);
    final data = response.data['data']['data'] as List<dynamic>;

    return data.map((e) => WalletTransaction.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// The backend debits the wallet synchronously before ever calling
  /// Paystack (see WithdrawalService::request), so a fresh balance is
  /// always correct to show immediately after this returns - no need to
  /// wait for the transfer itself to settle.
  Future<void> withdraw({required String bankAccountId, required double amount}) async {
    await ref.read(dioProvider).post(
      ApiConstants.walletWithdraw,
      data: {'bank_account_id': bankAccountId, 'amount': amount},
    );
    await refresh();
  }
}

final walletProvider = AsyncNotifierProvider<WalletNotifier, WalletAccount?>(
  WalletNotifier.new,
);
