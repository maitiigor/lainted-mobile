import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/error_message.dart';
import '../../../shared/models/bank_account.dart';
import '../providers/bank_accounts_provider.dart';

class BankAccountsScreen extends ConsumerWidget {
  const BankAccountsScreen({super.key});

  Future<void> _addAccount(BuildContext context) async {
    await showModalBottomSheet<BankAccount>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddBankAccountSheet(),
    );
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref, BankAccount account) async {
    try {
      await ref.read(bankAccountsProvider.notifier).delete(account.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessageFrom(e, fallback: 'Could not remove this account.')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(bankAccountsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Bank Accounts')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addAccount(context),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(bankAccountsProvider.future),
        child: accountsAsync.when(
          data: (accounts) {
            if (accounts.isEmpty) {
              return Center(
                child: Text(
                  'No bank accounts yet - add one to withdraw your earnings.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: accounts.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final account = accounts[index];
                return ListTile(
                  tileColor: AppColors.accent.withValues(alpha: 0.15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                  title: Text(account.bankName),
                  subtitle: Text('${account.accountName} · ****${account.accountNumberLast4}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.error),
                    onPressed: () => _deleteAccount(context, ref, account),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text(
              'Could not load your bank accounts.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.error),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddBankAccountSheet extends ConsumerStatefulWidget {
  const _AddBankAccountSheet();

  @override
  ConsumerState<_AddBankAccountSheet> createState() => _AddBankAccountSheetState();
}

class _AddBankAccountSheetState extends ConsumerState<_AddBankAccountSheet> {
  final _accountNumberController = TextEditingController();
  late final Future<List<Bank>> _banksFuture;
  Bank? _selectedBank;
  String? _resolvedName;
  bool _isResolving = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _banksFuture = ref.read(bankAccountsProvider.notifier).listBanks();
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    super.dispose();
  }

  bool get _isValid => _selectedBank != null && _resolvedName != null;

  Future<void> _tryResolve() async {
    final bank = _selectedBank;
    final accountNumber = _accountNumberController.text.trim();
    if (bank == null || accountNumber.length != 10) {
      setState(() => _resolvedName = null);
      return;
    }

    setState(() => _isResolving = true);
    try {
      final name = await ref
          .read(bankAccountsProvider.notifier)
          .resolveName(accountNumber: accountNumber, bankCode: bank.code);
      if (mounted) setState(() => _resolvedName = name);
    } catch (e) {
      if (!mounted) return;
      setState(() => _resolvedName = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessageFrom(e, fallback: 'Could not verify this account number.'))),
      );
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  Future<void> _submit() async {
    final bank = _selectedBank;
    final name = _resolvedName;
    if (_isSubmitting || bank == null || name == null) return;

    setState(() => _isSubmitting = true);
    try {
      final account = await ref.read(bankAccountsProvider.notifier).create(
            bankName: bank.name,
            bankCode: bank.code,
            accountNumber: _accountNumberController.text.trim(),
            accountName: name,
          );
      if (mounted) Navigator.pop(context, account);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessageFrom(e, fallback: 'Could not save this account.'))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New bank account', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          FutureBuilder<List<Bank>>(
            future: _banksFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError || snapshot.data == null) {
                return const Text('Could not load the list of banks.');
              }

              final banks = snapshot.data!;
              return Autocomplete<Bank>(
                displayStringForOption: (bank) => bank.name,
                optionsBuilder: (value) {
                  if (value.text.isEmpty) return const Iterable<Bank>.empty();
                  return banks.where(
                    (bank) => bank.name.toLowerCase().contains(value.text.toLowerCase()),
                  );
                },
                onSelected: (bank) {
                  setState(() => _selectedBank = bank);
                  _tryResolve();
                },
                fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(hintText: 'Search your bank'),
                  );
                },
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _accountNumberController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 10,
            decoration: const InputDecoration(hintText: '10-digit account number'),
            onChanged: (_) => _tryResolve(),
          ),
          if (_isResolving) ...[
            const SizedBox(height: AppSpacing.xs),
            const LinearProgressIndicator(),
          ] else if (_resolvedName != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              _resolvedName!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isValid && !_isSubmitting ? _submit : null,
              child: Text(_isSubmitting ? 'Saving…' : 'Save account'),
            ),
          ),
        ],
      ),
    );
  }
}
