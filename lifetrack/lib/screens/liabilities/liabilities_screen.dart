// NOTE: This screen expects one additional method on MoneyService that
// wasn't in the original file, used by the "add liability" sheet below:
//
//   Future<void> createLiability(String name, double amount)
//     -> creates a new liability with the given name and outstanding amount.
//
// If your service method has a different name/signature, adjust
// `_submitNewLiability()` below accordingly. Also assumes `Liability`
// exposes `name` (String) and `amount` (double) — if there's a
// `type`/`category` field too, tell me and I'll use it to pick icons
// instead of guessing from the name.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/liability.dart';
import '../../services/money_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/lifetrack_card.dart';

class LiabilitiesScreen extends StatefulWidget {
  const LiabilitiesScreen({super.key});
  @override
  State<LiabilitiesScreen> createState() => _LiabilitiesScreenState();
}

class _LiabilitiesScreenState extends State<LiabilitiesScreen> {
  final _service = MoneyService();
  late Future<List<Liability>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getLiabilities();
  }

  void _reload() {
    setState(() {
      _future = _service.getLiabilities();
    });
  }

  String _peso(double value) => '₱${NumberFormat('#,##0').format(value)}';

  IconData _iconForLiability(String name) {
    final key = name.toLowerCase();
    if (key.contains('credit') || key.contains('card')) {
      return Icons.credit_card_rounded;
    }
    if (key.contains('mortgage') ||
        key.contains('house') ||
        key.contains('home')) {
      return Icons.home_rounded;
    }
    if (key.contains('car') ||
        key.contains('auto') ||
        key.contains('vehicle')) {
      return Icons.directions_car_rounded;
    }
    if (key.contains('student') ||
        key.contains('tuition') ||
        key.contains('school')) {
      return Icons.school_rounded;
    }
    if (key.contains('personal') || key.contains('loan')) {
      return Icons.request_quote_rounded;
    }
    if (key.contains('medical') || key.contains('hospital')) {
      return Icons.local_hospital_rounded;
    }
    return Icons.receipt_long_rounded;
  }

  void _openAddLiabilitySheet() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    String? nameError;
    String? amountError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: LifeTrackColors.coral.withValues(alpha: 0.12),
                      ),
                      child: const Icon(Icons.receipt_long_rounded,
                          color: LifeTrackColors.coral, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text('Add liability',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'e.g. Credit card, Car loan, Mortgage',
                    errorText: nameError,
                    filled: true,
                    fillColor: Colors.grey.withValues(alpha: 0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'Outstanding amount',
                    prefixText: '₱ ',
                    errorText: amountError,
                    filled: true,
                    fillColor: Colors.grey.withValues(alpha: 0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  onSubmitted: (_) => _submitNewLiability(
                    context,
                    nameController.text,
                    amountController.text,
                    (name, amount) => setSheetState(() {
                      nameError = name;
                      amountError = amount;
                    }),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _submitNewLiability(
                      context,
                      nameController.text,
                      amountController.text,
                      (name, amount) => setSheetState(() {
                        nameError = name;
                        amountError = amount;
                      }),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: LifeTrackColors.coral,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Add liability'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitNewLiability(
    BuildContext sheetContext,
    String rawName,
    String rawAmount,
    void Function(String? nameError, String? amountError) setErrors,
  ) async {
    final name = rawName.trim();
    final amount = double.tryParse(rawAmount.trim());

    String? nameError;
    String? amountError;
    if (name.isEmpty) nameError = 'Enter a liability name';
    if (amount == null || amount < 0) amountError = 'Enter a valid amount';

    if (nameError != null || amountError != null) {
      setErrors(nameError, amountError);
      return;
    }

    Navigator.of(sheetContext).pop();
    await _service.createLiability(Liability(
      name: name,
      type: 'Other',
      amount: amount!,
    ));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<List<Liability>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded,
                      color: Colors.grey.withValues(alpha: 0.5), size: 32),
                  const SizedBox(height: 8),
                  Text('Unable to load liability records.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey)),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Retry'),
                    style: TextButton.styleFrom(
                      foregroundColor: LifeTrackColors.highlight,
                    ),
                  ),
                ],
              ),
            );
          }

          final liabilities = snapshot.data ?? const <Liability>[];
          final total = liabilities.fold<double>(0, (sum, l) => sum + l.amount);
          final sortedLiabilities = [...liabilities]
            ..sort((a, b) => b.amount.compareTo(a.amount));

          return ListView(
            padding: const EdgeInsets.all(LifeTrackMetrics.screenPadding),
            physics: const BouncingScrollPhysics(),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey.withValues(alpha: 0.08),
                      ),
                      child: const Icon(Icons.arrow_back_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Liabilities',
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  GestureDetector(
                    onTap: _openAddLiabilitySheet,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: LifeTrackColors.coral.withValues(alpha: 0.12),
                      ),
                      child: const Icon(Icons.add_rounded,
                          size: 20, color: LifeTrackColors.coral),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Hero total-owed card
              LifeTrackCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TOTAL OWED',
                        style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Icon(Icons.receipt_long_rounded,
                            color: LifeTrackColors.coral, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          _peso(total),
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: LifeTrackColors.coral,
                              ),
                        ),
                      ],
                    ),
                    if (liabilities.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${liabilities.length} ${liabilities.length == 1 ? 'liability' : 'liabilities'} tracked',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Text('LIABILITIES',
                  style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 12),

              if (liabilities.isEmpty)
                LifeTrackCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_rounded,
                              size: 32,
                              color: Colors.grey.withValues(alpha: 0.5)),
                          const SizedBox(height: 8),
                          Text(
                            'No liabilities recorded yet.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey),
                          ),
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: _openAddLiabilitySheet,
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Add liability'),
                            style: TextButton.styleFrom(
                              foregroundColor: LifeTrackColors.coral,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    for (final liability in sortedLiabilities)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _LiabilityCard(
                          liability: liability,
                          icon: _iconForLiability(liability.name),
                          share: total == 0 ? 0 : liability.amount / total,
                          peso: _peso,
                        ),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LiabilityCard extends StatelessWidget {
  const _LiabilityCard({
    required this.liability,
    required this.icon,
    required this.share,
    required this.peso,
  });
  final Liability liability;
  final IconData icon;
  final double share;
  final String Function(double) peso;

  @override
  Widget build(BuildContext context) {
    return LifeTrackCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {},
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: LifeTrackColors.coral.withValues(alpha: 0.12),
                  ),
                  child: Icon(icon, size: 18, color: LifeTrackColors.coral),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(liability.name,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Text(
                  peso(liability.amount),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: LifeTrackColors.coral,
                      ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: Colors.grey.withValues(alpha: 0.6)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: share,
                minHeight: 5,
                backgroundColor: Colors.grey.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation(LifeTrackColors.coral),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
