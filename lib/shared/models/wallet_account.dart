import '../../core/utils/json_parsing.dart';

class WalletAccount {
  const WalletAccount({
    this.balance = 0,
    this.loyaltyPoints = 0,
  });

  final double balance;

  /// Earned on every in-app transaction; spendable in-app only (not
  /// withdrawable), per the product document's anti-leakage design.
  final int loyaltyPoints;

  factory WalletAccount.fromJson(Map<String, dynamic> json) {
    return WalletAccount(
      balance: parseDouble(json['balance']),
      loyaltyPoints: json['loyalty_points'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'balance': balance,
      'loyalty_points': loyaltyPoints,
    };
  }
}
