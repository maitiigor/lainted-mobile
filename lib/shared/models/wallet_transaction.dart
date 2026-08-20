import '../../core/utils/json_parsing.dart';

enum LedgerDirection { credit, debit }

LedgerDirection ledgerDirectionFromString(String? value) {
  return value == 'debit' ? LedgerDirection.debit : LedgerDirection.credit;
}

enum WalletTransactionSource {
  saleEarning,
  withdrawal,
  deposit,
  refund,
  loyaltyRedemption,
  referralReward,
  forfeiture,
}

WalletTransactionSource walletTransactionSourceFromString(String? value) {
  const map = {
    'sale_earning': WalletTransactionSource.saleEarning,
    'withdrawal': WalletTransactionSource.withdrawal,
    'deposit': WalletTransactionSource.deposit,
    'refund': WalletTransactionSource.refund,
    'loyalty_redemption': WalletTransactionSource.loyaltyRedemption,
    'referral_reward': WalletTransactionSource.referralReward,
    'forfeiture': WalletTransactionSource.forfeiture,
  };
  return map[value] ?? WalletTransactionSource.deposit;
}

/// One immutable row in the wallet's ledger - a failed withdrawal is
/// reversed with a new credit row, never a deleted/mutated debit, so this
/// list is always a complete history (see WithdrawalService on the
/// backend).
class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.type,
    required this.source,
    required this.amount,
    required this.balanceAfter,
    this.createdAt,
  });

  final String id;
  final LedgerDirection type;
  final WalletTransactionSource source;
  final double amount;
  final double balanceAfter;
  final DateTime? createdAt;

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['uuid'] as String,
      type: ledgerDirectionFromString(json['type'] as String?),
      source: walletTransactionSourceFromString(json['source'] as String?),
      amount: parseDouble(json['amount']),
      balanceAfter: parseDouble(json['balance_after']),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }
}
