import 'package:flutter/material.dart';
import '../../models/goal.dart';
import '../../services/goal_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/goal_card.dart';
import '../../widgets/lifetrack_card.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final _goalService = GoalService();
  late Future<List<Goal>> _goalsFuture;

  @override
  void initState() {
    super.initState();
    _goalsFuture = _goalService.getActiveGoals();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(LifeTrackMetrics.screenPadding),
          children: [
            Row(
              children: [
                const Icon(Icons.arrow_back_rounded),
                const SizedBox(width: 12),
                Expanded(
                    child: Text('Goals',
                        style: Theme.of(context).textTheme.titleLarge)),
                IconButton(
                    onPressed: () {}, icon: const Icon(Icons.add_rounded)),
              ],
            ),
            const SizedBox(height: 18),
            Text('MY GOALS', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 12),
            FutureBuilder<List<Goal>>(
              future: _goalsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return const LifeTrackCard(
                      child: Text('Unable to load goals.'));
                }
                final goals = snapshot.data ?? const <Goal>[];
                if (goals.isEmpty) {
                  return const LifeTrackCard(
                    child: Column(children: [
                      Icon(Icons.flag_outlined, size: 32),
                      SizedBox(height: 8),
                      Text('No active goals recorded yet.')
                    ]),
                  );
                }
                return Column(
                  children: [
                    for (final goal in goals)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GoalCard(goal: goal, formatCurrency: _peso),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _peso(double value) =>
      '₱${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}';
}
