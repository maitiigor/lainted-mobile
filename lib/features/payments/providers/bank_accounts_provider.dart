import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../shared/models/bank_account.dart';
import '../../../shared/providers/dio_provider.dart';

class BankAccountsNotifier extends AsyncNotifier<List<BankAccount>> {
  @override
  Future<List<BankAccount>> build() async {
    final response = await ref.read(dioProvider).get(ApiConstants.bankAccounts);
    final data = response.data['data'] as List<dynamic>;

    return data.map((e) => BankAccount.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Bank>> listBanks() async {
    final response = await ref.read(dioProvider).get(ApiConstants.banks);
    final data = response.data['data'] as List<dynamic>;

    return data.map((e) => Bank.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Resolves the account holder's name from Paystack before the account
  /// is saved - the mobile form's "account name" field is read-only,
  /// filled from this call, never freely typed.
  Future<String> resolveName({required String accountNumber, required String bankCode}) async {
    final response = await ref.read(dioProvider).post(
      ApiConstants.resolveBankAccount,
      data: {'account_number': accountNumber, 'bank_code': bankCode},
    );

    return response.data['data']['account_name'] as String;
  }

  Future<BankAccount> create({
    required String bankName,
    required String bankCode,
    required String accountNumber,
    required String accountName,
  }) async {
    final response = await ref.read(dioProvider).post(
      ApiConstants.bankAccounts,
      data: {
        'bank_name': bankName,
        'bank_code': bankCode,
        'account_number': accountNumber,
        'account_name': accountName,
      },
    );

    final account = BankAccount.fromJson(response.data['data'] as Map<String, dynamic>);
    await _appendAccount(account);

    return account;
  }

  Future<void> delete(String uuid) async {
    await ref.read(dioProvider).delete(ApiConstants.bankAccount(uuid));

    final current = await future;
    state = AsyncData(current.where((a) => a.id != uuid).toList());
  }

  Future<void> _appendAccount(BankAccount account) async {
    final current = await future;
    state = AsyncData([...current, account]);
  }
}

final bankAccountsProvider = AsyncNotifierProvider<BankAccountsNotifier, List<BankAccount>>(
  BankAccountsNotifier.new,
);
