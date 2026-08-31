// NOTE: This screen expects one additional method on GoalService that
// wasn't in the original file, used by the "add skill" sheet below:
//
//   Future<void> createSkill(String name)
//     -> creates a new skill with 0% progress under the given name.
//
// If your service method has a different name/signature, adjust
// `_submitNewSkill()` below accordingly.
//
// TODO(phase6): Tapping a _SkillCard currently shows a quick detail sheet
// (name + percent) as a placeholder. Replace `_openSkillDetail` with
// `Navigator.push(... SkillDetailScreen(skill) ...)` once that screen
// exists, and drop the placeholder sheet.
// TODO(phase6): once GoalService can delete/update skills, wire the
// "Delete" button in the detail sheet (currently a no-op close) and add
// an "Edit" path that reuses the add-skill sheet in edit mode.
// TODO(phase6): once `Skill` has an `id`, use it as the ListView key
// below instead of relying on list position.

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

  // Same three-color rotation used for the Spending list and Monthly bars
  // on the Analytics screen, so cards feel consistent across the app.
  static const _palette = [
    LifeTrackColors.highlight,
    LifeTrackColors.mint,
    LifeTrackColors.coral,
  ];

  @override
  void initState() {
    super.initState();
    _skillsFuture = _goalService.getSkills();
  }

  void _reload() => setState(() => _skillsFuture = _goalService.getSkills());

  void _openAddSkillSheet() {
    final controller = TextEditingController();
    String? errorText;

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
                      child: const Icon(Icons.school_rounded,
                          color: LifeTrackColors.highlight, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text('Add skill',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'e.g. Flutter, Spanish, Guitar',
                    errorText: errorText,
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
                  onSubmitted: (_) => _submitNewSkill(
                    context,
                    controller.text,
                    (msg) => setSheetState(() => errorText = msg),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _submitNewSkill(
                      context,
                      controller.text,
                      (msg) => setSheetState(() => errorText = msg),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: LifeTrackColors.highlight,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Add skill'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitNewSkill(
    BuildContext sheetContext,
    String rawName,
    void Function(String? error) setError,
  ) async {
    final name = rawName.trim();
    if (name.isEmpty) {
      setError('Enter a skill name');
      return;
    }

    try {
      await _goalService.createSkill(name);
      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      if (mounted) _reload();
    } catch (_) {
      setError('Unable to save skill');
    }
  }

  void _openSkillDetail(Skill skill, Color color) {
    // TODO(phase6): replace this placeholder sheet with a real
    // SkillDetailScreen push: Navigator.push(context,
    // MaterialPageRoute(builder: (_) => SkillDetailScreen(skill)));
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.12),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.school_rounded, size: 22, color: color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child:
                          Text(skill.name, style: theme.textTheme.titleLarge),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Progress',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color
                              ?.withValues(alpha: 0.6),
                        )),
                    Text('${(skill.percent * 100).round()}%',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: color)),
                  ],
                ),
                const SizedBox(height: 8),
                ProgressBar(
                    value: skill.percent, color: color, label: skill.name),
                // TODO(phase6): once `Skill` exposes createdAt / lastPracticed
                // fields, show them here below the progress bar.
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        // TODO(phase6): open the add-skill sheet in edit
                        // mode, pre-filled with this skill's name/progress.
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: LifeTrackColors.coral,
                        ),
                        // TODO(phase6): call GoalService delete for this
                        // skill, then pop and _reload().
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(LifeTrackMetrics.screenPadding),
        physics: const BouncingScrollPhysics(),
        children: [
          Row(
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
                child: Text('Skills',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              GestureDetector(
                onTap: _openAddSkillSheet,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: LifeTrackColors.highlight.withValues(alpha: 0.12),
                  ),
                  child: const Icon(Icons.add_rounded,
                      size: 20, color: LifeTrackColors.highlight),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('MY SKILLS', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 12),
          FutureBuilder<List<Skill>>(
            future: _skillsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return LifeTrackCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.error_outline_rounded,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.5),
                              size: 32),
                          const SizedBox(height: 8),
                          Text('Unable to load skills.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
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
                    ),
                  ),
                );
              }

              final skills = snapshot.data ?? const <Skill>[];
              if (skills.isEmpty) {
                return LifeTrackCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.school_outlined,
                              size: 32,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.5)),
                          const SizedBox(height: 8),
                          Text(
                            'No skills recorded yet.',
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
                            onPressed: _openAddSkillSheet,
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Add skill'),
                            style: TextButton.styleFrom(
                              foregroundColor: LifeTrackColors.highlight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  for (int i = 0; i < skills.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SkillCard(
                        skill: skills[i],
                        color: _palette[i % _palette.length],
                        onTap: () => _openSkillDetail(
                            skills[i], _palette[i % _palette.length]),
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

class _SkillCard extends StatelessWidget {
  const _SkillCard(
      {required this.skill, required this.color, required this.onTap});
  final Skill skill;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LifeTrackCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
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
                  child: Icon(Icons.school_rounded, size: 18, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(skill.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                Text(
                  '${(skill.percent * 100).round()}%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: color,
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
              child: ProgressBar(value: skill.percent, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
