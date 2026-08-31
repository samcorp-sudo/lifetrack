// ============================================================================
// Account Detail Screen
// ----------------------------------------------------------------------------
// Reached by tapping an account on the Money screen. Shows:
//   - Large current balance
//   - Interest rate + "Apply Interest" action (only shown if rate > 0)
//   - "Add Balance" action (manual top-up, recorded as a Deposit transaction)
//   - That account's recent transactions
// ============================================================================

import 'package:flutter/material.dart';
import '../../models/account.dart';
import '../../models/transaction.dart';
import '../../services/money_service.dart';
import '../../theme/app_theme.dart';
import '../../app/currency_controller.dart';
import '../../widgets/lifetrack_card.dart';
import '../../widgets/transaction_item.dart';

class AccountDetailScreen extends StatefulWidget {
  final Account account;
  final MoneyService moneyService;

  const AccountDetailScreen({
    super.key,
    required this.account,
    required this.moneyService,
  });

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  late Account _account;
  late Future<List<Transaction>> _transactionsFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _account = widget.account;
    _reloadTransactions();
  }

  void _reloadTransactions() {
    _transactionsFuture =
        widget.moneyService.getTransactionsForAccount(_account.id!);
  }

  Future<void> _refreshAccount() async {
    // MoneyService doesn't expose getAccountById directly in this codebase's
    // known shape — re-pull from getAccounts() and find by id as a safe
    // fallback. Swap for a direct lookup if one exists on your service.
    final accounts = await widget.moneyService.getAccounts();
    final refreshed = accounts.where((a) => a.id == _account.id);
    if (refreshed.isNotEmpty && mounted) {
      setState(() {
        _account = refreshed.first;
        _reloadTransactions();
      });
    } else if (mounted) {
      setState(_reloadTransactions);
    }
  }

  Future<void> _addBalance() async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String? error;

    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add balance'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Amount', prefixText: ' '),
              ),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              if (error != null)
                Text(error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text.trim());
                if (amount == null || amount <= 0) {
                  setDialogState(() => error = 'Enter a valid amount.');
                  return;
                }
                Navigator.pop(dialogContext, amount);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    final note = noteController.text.trim();
    amountController.dispose();
    noteController.dispose();

    if (result == null) return;
    setState(() => _busy = true);
    try {
      await widget.moneyService
          .addBalance(_account, result, note: note.isEmpty ? null : note);
      if (mounted) await _refreshAccount();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to add balance.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _applyInterest() async {
    final estimated = _account.balance * (_account.interestRate / 100);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply interest'),
        content: Text(
          'This will add ${_peso(estimated)} to ${_account.name} '
          '(${_account.interestRate}% of ${_peso(_account.balance)}).',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Apply')),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await widget.moneyService.applyInterest(_account);
      if (mounted) await _refreshAccount();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to apply interest.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: ListView(
          padding: const EdgeInsets.all(LifeTrackMetrics.screenPadding),
          children: [
            _header(context),
            const SizedBox(height: 20),
            _balanceCard(context, primary),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _addBalance,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Balance'),
                  ),
                ),
                if (_account.interestRate > 0) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _applyInterest,
                      icon: const Icon(Icons.percent_rounded),
                      label: const Text('Apply Interest'),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            Text('Transactions',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            FutureBuilder<List<Transaction>>(
              future: _transactionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return const Center(
                      child: Text('Unable to load transactions.'));
                }
                final transactions = snapshot.data ?? const <Transaction>[];
                if (transactions.isEmpty) {
                  return LifeTrackCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('No transactions on this account yet.',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  );
                }
                return LifeTrackCard(
                  child: Column(
                    children: transactions
                        .map((t) =>
                            TransactionItem(entry: t, formatCurrency: _peso))
                        .toList(),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        Expanded(
          child: Text(_account.name,
              style: Theme.of(context).textTheme.titleLarge),
        ),
      ],
    );
  }

  Widget _balanceCard(BuildContext context, Color primary) {
    return LifeTrackCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    Icon(_accountIcon(_account.type), size: 20, color: primary),
              ),
              const SizedBox(width: 10),
              Text(_account.type, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 12),
          Text('Current Balance', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(_peso(_account.balance),
              style: Theme.of(context).textTheme.headlineLarge),
          if (_account.interestRate > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: LifeTrackColors.mint.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${_account.interestRate}% interest per year · ~${_peso(_account.balance * _account.interestRate / 100)}/yr',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: LifeTrackColors.mint,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _accountIcon(String type) => switch (type.toLowerCase()) {
        'cash' => Icons.payments_rounded,
        'gcash' => Icons.phone_android_rounded,
        'bank' => Icons.account_balance_rounded,
        'paypal' => Icons.account_balance_wallet_rounded,
        _ => Icons.wallet_rounded,
      };

  String _peso(double value) => CurrencyController.format(value);
}
