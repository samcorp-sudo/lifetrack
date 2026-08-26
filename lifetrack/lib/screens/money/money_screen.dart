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
            return ListView(
              padding: const EdgeInsets.all(LifeTrackMetrics.screenPadding),
              children: [
                Row(children: [
                  const Icon(Icons.arrow_back_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text('Money',
                          style: Theme.of(context).textTheme.titleLarge)),
                  const Icon(Icons.more_vert_rounded),
                ]),
                const SizedBox(height: 18),
                MoneyCard(balanceLabel: _peso(data.totalBalance)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: _summaryCard(context, 'Income',
                          data.summary['income'] ?? 0, LifeTrackColors.mint)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _summaryCard(
                          context,
                          'Expenses',
                          data.summary['expenses'] ?? 0,
                          LifeTrackColors.coral)),
                ]),
                const SizedBox(height: 20),
                const SectionHeader(title: 'Accounts'),
                LifeTrackCard(
                  child: data.accounts.isEmpty
                      ? const Text('No accounts recorded yet.')
                      : Column(children: [
                          for (final account in data.accounts) ...[
                            Row(children: [
                              Icon(_accountIcon(account.type),
                                  size: 20,
                                  color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Text(account.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge)),
                              Text(_peso(account.balance),
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                            ]),
                            if (account != data.accounts.last)
                              const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Divider(height: 1)),
                          ],
                        ]),
                ),
                const SizedBox(height: 20),
                const SectionHeader(title: 'Recent Transactions'),
                LifeTrackCard(
                  child: data.transactions.isEmpty
                      ? const Text('No transactions recorded yet.')
                      : Column(
                          children: data.transactions
                              .map((transaction) => TransactionItem(
                                  entry: transaction, formatCurrency: _peso))
                              .toList()),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _summaryCard(
          BuildContext context, String label, double amount, Color color) =>
      LifeTrackCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(_peso(amount),
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: color)),
        ]),
      );

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
