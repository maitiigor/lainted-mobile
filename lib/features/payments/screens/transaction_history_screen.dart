import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/wallet_transaction.dart';
import '../providers/wallet_provider.dart';

const _sourceLabels = {
  WalletTransactionSource.saleEarning: 'Sale earning',
  WalletTransactionSource.withdrawal: 'Withdrawal',
  WalletTransactionSource.deposit: 'Deposit',
  WalletTransactionSource.refund: 'Refund',
  WalletTransactionSource.loyaltyRedemption: 'Loyalty redemption',
  WalletTransactionSource.referralReward: 'Referral reward',
  WalletTransactionSource.forfeiture: 'Forfeiture',
};

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends ConsumerState<TransactionHistoryScreen> {
  List<WalletTransaction>? _transactions;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final transactions = await ref.read(walletProvider.notifier).transactions();
      if (!mounted) return;
      setState(() => _transactions = transactions);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorMessageFrom(e, fallback: 'Could not load your transaction history.'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactions = _transactions;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Transaction History')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Text(_error!, style: const TextStyle(color: AppColors.error)),
                  )
                : transactions == null || transactions.isEmpty
                    ? Center(
                        child: Text(
                          'No transactions yet.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: transactions.length,
                        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
                        itemBuilder: (context, index) {
                          final transaction = transactions[index];
                          final isCredit = transaction.type == LedgerDirection.credit;

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                              color: isCredit ? AppColors.success : AppColors.error,
                            ),
                            title: Text(_sourceLabels[transaction.source] ?? 'Transaction'),
                            subtitle: transaction.createdAt != null
                                ? Text(Formatters.messageTime(transaction.createdAt!))
                                : null,
                            trailing: Text(
                              '${isCredit ? '+' : '-'}${Formatters.currency(transaction.amount)}',
                              style: TextStyle(
                                color: isCredit ? AppColors.success : AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
