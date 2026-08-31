// NOTE: This screen expects one additional method on MoneyService that
// wasn't in the original file, used by the "add asset" sheet below:
//
//   Future<void> createAsset(String name, double value)
//     -> creates a new asset with the given name and value.
//
// If your service method has a different name/signature, adjust
// `_submitNewAsset()` below accordingly. Also assumes `Asset` exposes
// `name` (String) and `value` (double) — if there's a `type`/`category`
// field too, tell me and I'll use it to pick icons instead of guessing
// from the name.

import 'package:flutter/material.dart';
import '../../models/asset.dart';
import '../../services/money_service.dart';
import '../../theme/app_theme.dart';
import '../../app/currency_controller.dart';

import '../../widgets/lifetrack_card.dart';

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});
  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  final _service = MoneyService();
  late Future<List<Asset>> _future;

  // Same three-color rotation used across Analytics (Spending list, Monthly
  // bars) and Skills, so cards feel consistent across the app.
  static const _palette = [
    LifeTrackColors.highlight,
    LifeTrackColors.mint,
    LifeTrackColors.coral,
  ];

  @override
  void initState() {
    super.initState();
    _future = _service.getAssets();
  }

  void _reload() {
    setState(() {
      _future = _service.getAssets();
    });
  }

  String _peso(double value) => CurrencyController.format(value);

  IconData _iconForAsset(String name) {
    final key = name.toLowerCase();
    if (key.contains('cash') || key.contains('wallet')) {
      return Icons.account_balance_wallet_rounded;
    }
    if (key.contains('bank') || key.contains('savings')) {
      return Icons.account_balance_rounded;
    }
    if (key.contains('stock') ||
        key.contains('invest') ||
        key.contains('fund')) {
      return Icons.trending_up_rounded;
    }
    if (key.contains('crypto') || key.contains('bitcoin')) {
      return Icons.currency_bitcoin_rounded;
    }
    if (key.contains('car') ||
        key.contains('vehicle') ||
        key.contains('motor')) {
      return Icons.directions_car_rounded;
    }
    if (key.contains('house') ||
        key.contains('property') ||
        key.contains('condo')) {
      return Icons.home_rounded;
    }
    if (key.contains('gold') || key.contains('jewel')) {
      return Icons.diamond_rounded;
    }
    return Icons.savings_rounded;
  }

  void _openAddAssetSheet() {
    final nameController = TextEditingController();
    final valueController = TextEditingController();
    String? nameError;
    String? valueError;

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
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: 0.3),
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
                        color:
                            LifeTrackColors.highlight.withValues(alpha: 0.12),
                      ),
                      child: const Icon(Icons.savings_rounded,
                          color: LifeTrackColors.highlight, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text('Add asset',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'e.g. Savings account, Car, Gold',
                    errorText: nameError,
                    filled: true,
                    fillColor: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.06),
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
                  controller: valueController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'Current value',
                    prefixText: '${CurrencyController.symbol} ',
                    errorText: valueError,
                    filled: true,
                    fillColor: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  onSubmitted: (_) => _submitNewAsset(
                    context,
                    nameController.text,
                    valueController.text,
                    (name, value) => setSheetState(() {
                      nameError = name;
                      valueError = value;
                    }),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _submitNewAsset(
                      context,
                      nameController.text,
                      valueController.text,
                      (name, value) => setSheetState(() {
                        nameError = name;
                        valueError = value;
                      }),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: LifeTrackColors.highlight,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Add asset'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitNewAsset(
    BuildContext sheetContext,
    String rawName,
    String rawValue,
    void Function(String? nameError, String? valueError) setErrors,
  ) async {
    final name = rawName.trim();
    final value = double.tryParse(rawValue.trim());

    String? nameError;
    String? valueError;
    if (name.isEmpty) nameError = 'Enter an asset name';
    if (value == null || value < 0) valueError = 'Enter a valid amount';

    if (nameError != null || valueError != null) {
      setErrors(nameError, valueError);
      return;
    }

    try {
      await _service.createAsset(Asset(
        name: name,
        type: 'Other',
        value: CurrencyController.toPhp(value!),
        updatedAt: DateTime.now().toIso8601String(),
      ));
      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      if (mounted) _reload();
    } catch (_) {
      setErrors('Unable to save asset', null);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: FutureBuilder<List<Asset>>(
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
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.5),
                        size: 32),
                    const SizedBox(height: 8),
                    Text('Unable to load asset records.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
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

            final assets = snapshot.data ?? const <Asset>[];
            final total = assets.fold<double>(0, (sum, a) => sum + a.value);
            final sortedAssets = [...assets]
              ..sort((a, b) => b.value.compareTo(a.value));

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
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.08),
                        ),
                        child: const Icon(Icons.arrow_back_rounded, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Assets',
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                    GestureDetector(
                      onTap: _openAddAssetSheet,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              LifeTrackColors.highlight.withValues(alpha: 0.12),
                        ),
                        child: const Icon(Icons.add_rounded,
                            size: 20, color: LifeTrackColors.highlight),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Hero net-worth card
                LifeTrackCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TOTAL NET WORTH',
                          style: Theme.of(context).textTheme.labelSmall),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Icon(Icons.account_balance_wallet_rounded,
                              color: LifeTrackColors.highlight, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            _peso(total),
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      if (assets.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${assets.length} ${assets.length == 1 ? 'asset' : 'assets'} tracked',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Text('ASSETS', style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 12),

                if (assets.isEmpty)
                  LifeTrackCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.savings_rounded,
                                size: 32,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withValues(alpha: 0.5)),
                            const SizedBox(height: 8),
                            Text(
                              'No assets recorded yet.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant),
                            ),
                            const SizedBox(height: 10),
                            TextButton.icon(
                              onPressed: _openAddAssetSheet,
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Add asset'),
                              style: TextButton.styleFrom(
                                foregroundColor: LifeTrackColors.highlight,
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
                      for (int i = 0; i < sortedAssets.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _AssetCard(
                            asset: sortedAssets[i],
                            color: _palette[i % _palette.length],
                            icon: _iconForAsset(sortedAssets[i].name),
                            share:
                                total == 0 ? 0 : sortedAssets[i].value / total,
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

class _AssetCard extends StatelessWidget {
  const _AssetCard({
    required this.asset,
    required this.color,
    required this.icon,
    required this.share,
    required this.peso,
  });
  final Asset asset;
  final Color color;
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
                    color: color.withValues(alpha: 0.12),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(asset.name,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Text(
                  peso(asset.value),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded,
                    size: 18,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.6)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: share,
                minHeight: 5,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
