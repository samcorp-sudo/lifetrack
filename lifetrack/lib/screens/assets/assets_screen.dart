import 'package:flutter/material.dart';
import '../../models/asset.dart';
import '../../services/money_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/lifetrack_card.dart';

/// AssetsScreen displays a list of assets and their values.
/// Add assets button is not implemented yet.

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});
  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  final _service = MoneyService();
  late Future<List<Asset>> _future;
  @override
  void initState() {
    super.initState();
    _future = _service.getAssets();
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
              return const Center(child: Text('Unable to load asset records.'));
            }
            final assets = snapshot.data ?? const <Asset>[];
            return ListView(
                padding: const EdgeInsets.all(LifeTrackMetrics.screenPadding),
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text('Assets',
                            style: Theme.of(context).textTheme.titleLarge)),
                    IconButton(
                      tooltip: 'Add asset',
                      icon: const Icon(Icons.add_rounded),
                      onPressed: () {},
                    ),
                  ]),
                  const SizedBox(height: 18),
                  Text('ASSETS', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 12),
                  LifeTrackCard(
                      child: assets.isEmpty
                          ? const Text('No assets recorded yet.')
                          : Column(children: [
                              for (final asset in assets)
                                Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(children: [
                                      const Icon(
                                          Icons.account_balance_wallet_rounded),
                                      const SizedBox(width: 10),
                                      Expanded(child: Text(asset.name)),
                                      Text(_peso(asset.value))
                                    ]))
                            ]))
                ]);
          }));
  String _peso(double value) => '₱${value.toStringAsFixed(0)}';
}
