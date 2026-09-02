// ============================================================================
// Money Screen
// ----------------------------------------------------------------------------
// LAYOUT:
// - Top bar (LifeTrack, notification bell with badge, profile avatar).
// - Total Balance hero card in the active season color, with a LIVE chip,
//   an eye toggle to hide / show the amount, and this month's net change.
// - "Wallets" section with a "+ Add Wallet" pill and tappable wallet rows
//   -> AccountDetailScreen.
// - Income / Expenses summary cards.
// - Recent Transactions capped to 4 with a "View All" row.
// - Extended FAB ("Add") still opens the Add transaction / Add account sheet.
//
// UNCHANGED: MoneyService calls, CurrencyController usage, the two
// add-transaction/add-account dialogs, and data models.
// ============================================================================

import 'package:flutter/material.dart';
import '../../models/account.dart';
import '../../models/transaction.dart';
import '../../services/money_service.dart';
import '../../theme/app_theme.dart';
import '../../app/currency_controller.dart';

import '../../widgets/app_top_bar.dart';
import '../../widgets/lifetrack_card.dart';
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
  static const double _iconChipSize = 44;
  static const int _recentTransactionsLimit = 4;

  final _moneyService = MoneyService();
  late Future<_MoneyData> _dataFuture;
  bool _hideBalance = false;

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
    final season = context.season;

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'money_add_fab',
          backgroundColor: season.accent,
          elevation: 2,
          onPressed: () => _openAddOptions(context),
          icon: Icon(Icons.add, color: season.onAccent),
          label: Text('Add',
              style: TextStyle(
                  color: season.onAccent, fontWeight: FontWeight.w600)),
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
                  const AppTopBar(),
                  const SizedBox(height: _sectionGap),
                  _balanceCard(context, data),
                  const SizedBox(height: _sectionGap),
                  _walletsHeader(context),
                  const SizedBox(height: _rowGap),
                  data.accounts.isEmpty
                      ? LifeTrackCard(
                          child:
                              _emptyState(context, 'No wallets recorded yet.'))
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
                  _recentTransactionsHeader(context, data.transactions.length),
                  const SizedBox(height: 8),
                  LifeTrackCard(
                    child: data.transactions.isEmpty
                        ? _emptyState(context, 'No transactions recorded yet.')
                        : Column(
                            children: data.transactions
                                .take(_recentTransactionsLimit)
                                .map((transaction) => TransactionItem(
                                      entry: transaction,
                                      formatCurrency: _peso,
                                      onDelete: () async {
                                        await _moneyService
                                            .deleteTransaction(transaction);
                                        if (mounted) await _refresh();
                                      },
                                    ))
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
  // Total Balance hero card
  // ---------------------------------------------------------------------

  Widget _balanceCard(BuildContext context, _MoneyData data) {
    final s = context.season;
    final theme = Theme.of(context);

    final income = data.summary['income'] ?? 0;
    final expenses = data.summary['expenses'] ?? 0;
    final net = data.summary['saved'] ?? (income - expenses);
    final positive = net >= 0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [s.accent, s.accentDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: s.accent.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Soft decorative circles.
            Positioned(right: -40, top: -50, child: _decorCircle(170)),
            Positioned(right: 30, bottom: -70, child: _decorCircle(140)),
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Total Balance',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: s.onAccent.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        _liveChip(context),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _hideBalance
                                  ? '\u2022\u2022\u2022\u2022\u2022\u2022'
                                  : _peso(data.totalBalance),
                              style: theme.textTheme.displayLarge?.copyWith(
                                color: s.onAccent,
                                fontSize: 38,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () =>
                              setState(() => _hideBalance = !_hideBalance),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              _hideBalance
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: s.onAccent.withValues(alpha: 0.85),
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          positive
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          size: 16,
                          color: s.onAccent.withValues(alpha: 0.85),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _hideBalance
                                ? (positive
                                    ? '+ \u2022\u2022\u2022\u2022 this month'
                                    : '- \u2022\u2022\u2022\u2022 this month')
                                : '${positive ? '+' : '-'} ${_peso(net.abs())} this month',
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: s.onAccent.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _decorCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.10),
      ),
    );
  }

  Widget _liveChip(BuildContext context) {
    final s = context.season;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: s.onAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: s.onAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Live',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: s.onAccent,
                  fontSize: 12,
                  letterSpacing: 0,
                ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Wallets header + "+ Add Wallet" pill
  // ---------------------------------------------------------------------

  Widget _walletsHeader(BuildContext context) {
    final s = context.season;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const SectionHeader(title: 'Wallets'),
        Material(
          color: s.accent.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => _openAddAccountDialog(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 18, color: s.accentText),
                  const SizedBox(width: 4),
                  Text(
                    'Add Wallet',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: s.accentText,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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

  // Each wallet is one tappable card -> AccountDetailScreen.
  Widget _accountCard(BuildContext context, Account account) {
    final theme = Theme.of(context);
    final tint = _accountTint(context, account.type);
    final subtitle = account.interestRate > 0
        ? '${account.type} \u00B7 ${account.interestRate}% APY'
        : account.type;

    return LifeTrackCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(LifeTrackMetrics.cardRadius),
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
                    color: tint.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child:
                      Icon(_accountIcon(account.type), size: 22, color: tint),
                ),
                const SizedBox(width: _rowGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _hideBalance
                      ? '\u2022\u2022\u2022\u2022\u2022\u2022'
                      : _peso(account.balance),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded,
                    color: theme.textTheme.bodyMedium?.color),
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

  // Colored chip per wallet type.
  Color _accountTint(BuildContext context, String type) =>
      switch (type.toLowerCase()) {
        'cash' => LifeTrackColors.mint,
        'gcash' => LifeTrackColors.skyInfo,
        'bank' => context.season.accentText,
        'paypal' => LifeTrackColors.skyInfo,
        _ => Theme.of(context).textTheme.bodyMedium?.color ??
            LifeTrackColors.textMutedOnLight,
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
    final s = context.season;
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
                  color: s.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: s.accentText),
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
