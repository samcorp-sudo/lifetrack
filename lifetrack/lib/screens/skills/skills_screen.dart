import 'package:flutter/material.dart';
import '../../models/skill.dart';
import '../../services/goal_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/lifetrack_card.dart';
import '../../widgets/progress_bar.dart';

class SkillsScreen extends StatefulWidget {
  const SkillsScreen({super.key});

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  final _goalService = GoalService();
  late Future<List<Skill>> _skillsFuture;

  @override
  void initState() {
    super.initState();
    _skillsFuture = _goalService.getSkills();
  }

  void _reload() {
    setState(() => _skillsFuture = _goalService.getSkills());
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(LifeTrackMetrics.screenPadding),
        children: [
          Row(
            children: [
              GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: const Icon(Icons.arrow_back_rounded)),
              const SizedBox(width: 12),
              Expanded(child: Text('Skills', style: Theme.of(context).textTheme.titleLarge)),
              IconButton(onPressed: () {}, icon: const Icon(Icons.add_rounded)),
            ],
          ),
          const SizedBox(height: 18),
          Text('MY SKILLS', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 12),
          FutureBuilder<List<Skill>>(
            future: _skillsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return LifeTrackCard(
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline_rounded),
                      const SizedBox(height: 8),
                      const Text('Unable to load skills.'),
                      TextButton(onPressed: _reload, child: const Text('Retry')),
                    ],
                  ),
                );
              }

              final skills = snapshot.data ?? const <Skill>[];
              if (skills.isEmpty) {
                return const LifeTrackCard(
                  child: Column(
                    children: [
                      Icon(Icons.school_outlined, size: 32),
                      SizedBox(height: 8),
                      Text('No skills recorded yet.'),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  for (final skill in skills)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: LifeTrackCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.school_rounded, size: 22, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 8),
                                Expanded(child: Text(skill.name, style: Theme.of(context).textTheme.titleMedium)),
                                Text('${(skill.percent * 100).round()}%', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: LifeTrackColors.highlight)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ProgressBar(value: skill.percent),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}