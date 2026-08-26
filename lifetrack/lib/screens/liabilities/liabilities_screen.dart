import 'package:flutter/material.dart';
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
            return const Center(
                child: Text('Unable to load liability records.'));
          }
          final liabilities = snapshot.data ?? const <Liability>[];
          return ListView(
            padding: const EdgeInsets.all(LifeTrackMetrics.screenPadding),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Liabilities',
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  IconButton(
                    tooltip: 'Add liability',
                    icon: const Icon(Icons.add_rounded),
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text('LIABILITIES',
                  style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 12),
              LifeTrackCard(
                child: liabilities.isEmpty
                    ? const Text('No liabilities recorded yet.')
                    : Column(
                        children: [
                          for (final liability in liabilities)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.credit_card_rounded),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(liability.name)),
                                  Text(_peso(liability.amount)),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _peso(double value) => '₱${value.toStringAsFixed(0)}';
}
