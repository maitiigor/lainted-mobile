/// A saved payout destination for wallet withdrawals. The backend never
/// sends back the full account number - only a masked last4, matching
/// standard saved-payment-method UX.
class BankAccount {
  const BankAccount({
    required this.id,
    required this.bankName,
    required this.bankCode,
    required this.accountName,
    required this.accountNumberLast4,
    this.isDefault = false,
  });

  final String id;
  final String bankName;
  final String bankCode;
  final String accountName;
  final String accountNumberLast4;
  final bool isDefault;

  factory BankAccount.fromJson(Map<String, dynamic> json) {
    return BankAccount(
      id: json['uuid'] as String,
      bankName: json['bank_name'] as String,
      bankCode: json['bank_code'] as String,
      accountName: json['account_name'] as String,
      accountNumberLast4: json['account_number_last4'] as String? ?? '',
      isDefault: json['is_default'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': id,
      'bank_name': bankName,
      'bank_code': bankCode,
      'account_name': accountName,
      'account_number_last4': accountNumberLast4,
      'is_default': isDefault,
    };
  }
}

/// One entry in Paystack's bank list (GET /banks) - used to populate the
/// bank picker before an account number is even entered.
class Bank {
  const Bank({required this.name, required this.code});

  final String name;
  final String code;

  factory Bank.fromJson(Map<String, dynamic> json) {
    return Bank(
      name: json['name'] as String,
      code: json['code'] as String,
    );
  }
}
