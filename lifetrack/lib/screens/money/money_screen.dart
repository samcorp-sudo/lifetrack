// ============================================================================
// Money Screen
// ----------------------------------------------------------------------------
// CHANGES IN THIS VERSION:
// - Accounts are now tappable rows -> push AccountDetailScreen for that
//   account (balance, add balance, interest, that account's transactions).
// - Add flow matches the Schedule screen's pattern: an extended FAB
//   ("Add") opening a bottom sheet with two options (Add transaction /
//   Add account) via the same _AddOptionTile look, instead of a header
//   PopupMenuButton.
// - Recent Transactions is capped to 4 items with a "View All" row that
//   pushes AllTransactionsScreen (grouped by week/month).
//
// UNCHANGED: MoneyService calls, CurrencyController usage, the two
// add-transaction/add-account dialogs, colors, and data models.
// ============================================================================

import 'package:flutter/material.dart';
import '../../models/account.dart';
import '../../models/transaction.dart';
import '../../services/money_service.dart';
import '../../theme/app_theme.dart';
import '../../app/currency_controller.dart';

import '../../widgets/lifetrack_card.dart';
import '../../widgets/cards/money_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/transaction_item.dart';
import 'account_detail_screen.dart';
import 'all_transactions_screen.dart';

class MoneyScreen extends StatefulWidget {
  const MoneyScreen({super.key});

  @override
  State<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends State<MoneyScreen> {
  static const double _sectionGap = 20;
  static const double _rowGap = 12;
  static const double _iconChipSize = 40;
  static const int _recentTransactionsLimit = 4;

  final _moneyService = MoneyService();
  late Future<_MoneyData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_MoneyData> _loadData() async {
    final now = DateTime.now();
    final results = await Future.wait<dynamic>([
      _moneyService.getAccounts(),
      _moneyService.getRecentTransactions(limit: _recentTransactionsLimit),
      _moneyService.getMonthlySummary(now.year, now.month),
      _moneyService.getTotalBalance(),
    ]);
    return _MoneyData(
      accounts: results[0] as List<Account>,
      transactions: results[1] as List<Transaction>,
      summary: results[2] as Map<String, double>,
      totalBalance: results[3] as double,
    );
  }

  Future<void> _refresh() async {
    final next = _loadData();
    setState(() => _dataFuture = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: LifeTrackColors.highlight,
          elevation: 2,
          onPressed: () => _openAddOptions(context),
          icon: const Icon(Icons.add, color: LifeTrackColors.ink),
          label: const Text('Add',
              style: TextStyle(
                  color: LifeTrackColors.ink, fontWeight: FontWeight.w600)),
        ),
        body: FutureBuilder<_MoneyData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(
                  child: Text('Unable to load wallet records.'));
            }
            
            final data = snapshot.data!;
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(LifeTrackMetrics.screenPadding),
                children: [
                  _header(context),
                  const SizedBox(height: 18),
                  MoneyCard(balanceLabel: _peso(data.totalBalance)),
                  const SizedBox(height: _rowGap),
                  Row(
                    children: [
                      Expanded(
                        child: _summaryCard(
                          context,
                          label: 'Income',
                          amount: data.summary['income'] ?? 0,
                          color: LifeTrackColors.mint,
                          icon: Icons.trending_up_rounded,
                        ),
                      ),
                      const SizedBox(width: _rowGap),
                      Expanded(
                        child: _summaryCard(
                          context,
                          label: 'Expenses',
                          amount: data.summary['expenses'] ?? 0,
                          color: LifeTrackColors.coral,
                          icon: Icons.trending_down_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: _sectionGap),
                  const SectionHeader(title: 'Accounts'),
                  const SizedBox(height: 8),
                  data.accounts.isEmpty
                      ? LifeTrackCard(
                          child:
                              _emptyState(context, 'No accounts recorded yet.'))
                      : Column(
                          children: [
                            for (final account in data.accounts)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _accountCard(context, account),
                              ),
                          ],
                        ),
                  const SizedBox(height: _sectionGap),
                  _recentTransactionsHeader(context, data.transactions.length),
                  const SizedBox(height: 8),
                  LifeTrackCard(
                    child: data.transactions.isEmpty
                        ? _emptyState(context, 'No transactions recorded yet.')
                        : Column(
                            children: data.transactions
                                .take(_recentTransactionsLimit)
                                .map((transaction) => TransactionItem(
                                    entry: transaction, formatCurrency: _peso))
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Add flow — matches Schedule screen's FAB + bottom sheet pattern.
  // ---------------------------------------------------------------------

  Future<void> _openAddOptions(BuildContext context) async {
    // Need the current accounts list for the transaction dialog's dropdown.
    final data = await _dataFuture;
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _MoneyAddOptionsSheet(
        onAddTransaction: () {
          Navigator.of(sheetContext).pop();
          _openAddTransactionDialog(data.accounts);
        },
        onAddAccount: () {
          Navigator.of(sheetContext).pop();
          _openAddAccountDialog();
        },
      ),
    );
  }

  Future<void> _openAddAccountDialog() async {
    final nameController = TextEditingController();
    final balanceController = TextEditingController(text: '0');
    final interestController = TextEditingController(text: '0');
    var type = 'Cash';
    String? error;

    final account = await showDialog<Account>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add account'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration:
                        const InputDecoration(labelText: 'Account name')),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Account type'),
                  items: const ['Cash', 'Bank', 'GCash', 'PayPal', 'Other']
                      .map((item) =>
                          DropdownMenuItem(value: item, child: Text(item)))
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => type = value ?? type),
                ),
                TextField(
                    controller: balanceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Starting balance', prefixText: ' ')),
                TextField(
                    controller: interestController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Interest rate (% per year, optional)')),
                if (error != null)
                  Text(error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final balance = double.tryParse(balanceController.text.trim());
                final interest =
                    double.tryParse(interestController.text.trim()) ?? 0;
                if (name.isEmpty || balance == null || balance < 0) {
                  setDialogState(
                      () => error = 'Enter a name and valid balance.');
                  return;
                }
                Navigator.pop(
                    dialogContext,
                    Account(
                        name: name,
                        type: type,
                        balance: CurrencyController.toPhp(balance),
                        createdAt: DateTime.now().toIso8601String(),
                        interestRate: interest));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    balanceController.dispose();
    interestController.dispose();
    if (account == null) return;
    try {
      await _moneyService.createAccount(account);
      if (mounted) await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save account.')),
        );
      }
    }
  }

  Future<void> _openAddTransactionDialog(List<Account> accounts) async {
    final availableAccounts =
        accounts.where((account) => account.id != null).toList();
    if (availableAccounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Add an account before recording a transaction.')),
      );
      return;
    }

    final amountController = TextEditingController();
    final categoryController = TextEditingController();
    final noteController = TextEditingController();
    var type = TransactionType.expense;
    var accountId = availableAccounts.first.id!;
    var date = DateTime.now();
    String? error;

    final transaction = await showDialog<Transaction>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add transaction'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<TransactionType>(
                  segments: const [
                    ButtonSegment(
                        value: TransactionType.expense,
                        label: Text('Expense'),
                        icon: Icon(Icons.trending_down_rounded)),
                    ButtonSegment(
                        value: TransactionType.income,
                        label: Text('Income'),
                        icon: Icon(Icons.trending_up_rounded)),
                  ],
                  selected: {type},
                  onSelectionChanged: (selected) =>
                      setDialogState(() => type = selected.first),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: accountId,
                  decoration: const InputDecoration(labelText: 'Account'),
                  items: availableAccounts
                      .map((account) => DropdownMenuItem(
                          value: account.id, child: Text(account.name)))
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => accountId = value ?? accountId),
                ),
                TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Amount', prefixText: ' '),
                ),
                TextField(
                  controller: categoryController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                TextField(
                  controller: noteController,
                  decoration:
                      const InputDecoration(labelText: 'Note (optional)'),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      final selected = await showDatePicker(
                        context: dialogContext,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        initialDate: date,
                      );
                      if (selected != null) {
                        setDialogState(() => date = selected);
                      }
                    },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(_formatTransactionDate(date)),
                  ),
                ),
                if (error != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text.trim());
                final category = categoryController.text.trim();
                if (amount == null || amount <= 0) {
                  setDialogState(() => error = 'Enter a valid amount.');
                  return;
                }
                if (category.isEmpty) {
                  setDialogState(() => error = 'Enter a category.');
                  return;
                }
                Navigator.pop(
                    dialogContext,
                    Transaction(
                      accountId: accountId,
                      type: type,
                      amount: CurrencyController.toPhp(amount),
                      category: category,
                      note: noteController.text.trim().isEmpty
                          ? null
                          : noteController.text.trim(),
                      date: _formatTransactionDate(date),
                    ));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    amountController.dispose();
    categoryController.dispose();
    noteController.dispose();

    if (transaction == null) return;
    try {
      await _moneyService.recordTransaction(transaction);
      if (mounted) await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to save transaction.')));
      }
    }
  }

  String _formatTransactionDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Widget _header(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text('Wallet', style: Theme.of(context).textTheme.titleLarge),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  Widget _recentTransactionsHeader(BuildContext context, int shownCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const SectionHeader(title: 'Recent Transactions'),
        TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  AllTransactionsScreen(moneyService: _moneyService),
            ),
          ),
          child: const Text('View All'),
        ),
      ],
    );
  }

  Widget _summaryCard(
    BuildContext context, {
    required String label,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return LifeTrackCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _peso(amount),
            style:
                Theme.of(context).textTheme.titleLarge?.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  // Redesigned: whole account is now one tappable card -> AccountDetailScreen.
  Widget _accountCard(BuildContext context, Account account) {
    final primary = Theme.of(context).colorScheme.primary;
    return LifeTrackCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AccountDetailScreen(
                  account: account,
                  moneyService: _moneyService,
                ),
              ),
            );
            if (mounted) await _refresh();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: _iconChipSize,
                  height: _iconChipSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_accountIcon(account.type),
                      size: 20, color: primary),
                ),
                const SizedBox(width: _rowGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(account.name,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            account.type,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.color
                                          ?.withValues(alpha: 0.6),
                                    ),
                          ),
                          if (account.interestRate > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: LifeTrackColors.mint
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${account.interestRate}% APY',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: LifeTrackColors.mint,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Text(_peso(account.balance),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded,
                    color: Theme.of(context).textTheme.bodyMedium?.color),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.color
                  ?.withValues(alpha: 0.6),
            ),
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

class _MoneyData {
  const _MoneyData(
      {required this.accounts,
      required this.transactions,
      required this.summary,
      required this.totalBalance});
  final List<Account> accounts;
  final List<Transaction> transactions;
  final Map<String, double> summary;
  final double totalBalance;
}

// ============================================================================
// Add-options bottom sheet — same visual pattern as the Schedule screen's.
// ============================================================================

class _MoneyAddOptionsSheet extends StatelessWidget {
  final VoidCallback onAddTransaction;
  final VoidCallback onAddAccount;

  const _MoneyAddOptionsSheet({
    required this.onAddTransaction,
    required this.onAddAccount,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Text('Add to wallet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _MoneyAddOptionTile(
              icon: Icons.swap_vert_rounded,
              title: 'Add transaction',
              subtitle: 'Log an income or expense',
              onTap: onAddTransaction,
            ),
            const SizedBox(height: 8),
            _MoneyAddOptionTile(
              icon: Icons.account_balance_wallet_rounded,
              title: 'Add account',
              subtitle: 'Cash, GCash, Bank, or another wallet',
              onTap: onAddAccount,
            ),
          ],
        ),
      ),
    );
  }
}

class _MoneyAddOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MoneyAddOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            )),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Theme.of(context).textTheme.bodyMedium?.color),
            ],
          ),
        ),
      ),
    );
  }
}
