import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/bank_account.dart';
import '../providers/bank_accounts_provider.dart';
import '../providers/wallet_provider.dart';

class WithdrawScreen extends ConsumerStatefulWidget {
  const WithdrawScreen({super.key});

  @override
  ConsumerState<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends ConsumerState<WithdrawScreen> {
  final _amountController = TextEditingController();
  BankAccount? _selectedAccount;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double? get _amount => double.tryParse(_amountController.text);

  Future<void> _submit(double balance) async {
    if (_isSubmitting) return;

    final account = _selectedAccount;
    final amount = _amount;
    if (account == null) {
      _showError('Choose a bank account first.');
      return;
    }
    if (amount == null || amount <= 0 || amount > balance) {
      _showError('Enter a valid amount.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(walletProvider.notifier).withdraw(bankAccountId: account.id, amount: amount);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Withdrawal requested.')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      _showError(errorMessageFrom(e, fallback: 'Could not process this withdrawal.'));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(walletProvider);
    final accountsAsync = ref.watch(bankAccountsProvider);
    final balance = walletAsync.value?.balance ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Withdraw')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Available balance: ${Formatters.currency(balance)}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(left: AppSpacing.md),
                    child: Text('₦'),
                  ),
                  prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
                  hintText: 'Amount to withdraw',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Send to', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              accountsAsync.when(
                data: (accounts) {
                  if (accounts.isEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add a bank account before withdrawing.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        OutlinedButton(
                          onPressed: () => context.push('/wallet/bank-accounts'),
                          child: const Text('Add Bank Account'),
                        ),
                      ],
                    );
                  }

                  _selectedAccount ??= accounts.first;

                  return RadioGroup<String>(
                    groupValue: _selectedAccount?.id,
                    onChanged: (id) => setState(
                      () => _selectedAccount = accounts.firstWhere((a) => a.id == id),
                    ),
                    child: Column(
                      children: [
                        for (final account in accounts)
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            value: account.id,
                            title: Text(account.bankName),
                            subtitle: Text('${account.accountName} · ****${account.accountNumberLast4}'),
                          ),
                      ],
                    ),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (error, stack) => const Text('Could not load your bank accounts.'),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : () => _submit(balance),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.surface),
                        )
                      : const Text('Withdraw'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
