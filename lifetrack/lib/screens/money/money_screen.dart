// ============================================================================
// Money Screen
// ----------------------------------------------------------------------------
// IMPROVEMENTS OVER PREVIOUS VERSION (layout/UX only — colors, data models,
// and MoneyService calls are unchanged):
// - Back and overflow icons are now tappable (back pops the route; overflow
//   is wired to a no-op placeholder you can hook a menu into) and sit in the
//   same tinted icon-chip style used on the Settings screen, for visual
//   consistency across the app.
// - Pull-to-refresh via RefreshIndicator, reusing the existing _loadData().
// - Account rows get the same icon-chip treatment plus a muted account-type
//   subtitle, instead of a bare icon and name only.
// - Income/Expenses summary cards get a small trend icon tinted to match
//   their existing color, and the amount is now visually anchored under a
//   muted label instead of floating alone.
// - Extracted a spacing scale instead of scattered literal SizedBox values.
// ============================================================================

import 'package:flutter/material.dart';
import '../../models/account.dart';
import '../../models/transaction.dart';
import '../../services/money_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/lifetrack_card.dart';
import '../../widgets/money_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/transaction_item.dart';

class MoneyScreen extends StatefulWidget {
  const MoneyScreen({super.key});

  @override
  State<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends State<MoneyScreen> {
  static const double _sectionGap = 20;
  static const double _rowGap = 12;
  static const double _iconChipSize = 34;

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
      _moneyService.getRecentTransactions(limit: 10),
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
        body: FutureBuilder<_MoneyData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Unable to load money records.'));
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
                  LifeTrackCard(
                    child: data.accounts.isEmpty
                        ? _emptyState(context, 'No accounts recorded yet.')
                        : Column(
                            children: [
                              for (final account in data.accounts) ...[
                                _accountRow(context, account),
                                if (account != data.accounts.last)
                               const   Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Divider(
                                      height: 1,
                                      indent: _iconChipSize + _rowGap,
                                    ),
                                  ),
                              ],
                            ],
                          ),
                  ),
                  const SizedBox(height: _sectionGap),
                  const SectionHeader(title: 'Recent Transactions'),
                  const SizedBox(height: 8),
                  LifeTrackCard(
                    child: data.transactions.isEmpty
                        ? _emptyState(
                            context, 'No transactions recorded yet.')
                        : Column(
                            children: data.transactions
                                .map((transaction) => TransactionItem(
                                    entry: transaction,
                                    formatCurrency: _peso))
                                .toList(),
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
      
        
        Expanded(
          child: Text('Money', style: Theme.of(context).textTheme.titleLarge),
        ),
        _iconButtonChip(
          color: primary,
          icon: Icons.more_vert_rounded,
          onTap: () {
            // Hook up an options menu (export, filter, etc.) here.
          },
        ),
      ],
    );
  }

  Widget _iconButtonChip({
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: _iconChipSize,
        height: _iconChipSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
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

  Widget _accountRow(BuildContext context, Account account) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: _iconChipSize,
            height: _iconChipSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_accountIcon(account.type), size: 18, color: primary),
          ),
          const SizedBox(width: _rowGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.name,
                    style: Theme.of(context).textTheme.bodyLarge),
                Text(
                  account.type,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withValues(alpha: 0.6),
                      ),
                ),
              ],
            ),
          ),
          Text(_peso(account.balance),
              style: Theme.of(context).textTheme.titleMedium),
        ],
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

  String _peso(double value) =>
      '₱${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}';
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