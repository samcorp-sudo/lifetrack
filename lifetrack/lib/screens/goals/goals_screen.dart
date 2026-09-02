// ============================================================================
// Goals Screen
// ============================================================================
// Fully wired to GoalService: add contribution, edit goal, delete goal,
// contribution history, and a real progress bar. Uses only fields that
// exist on the Goal model (id, name, targetAmount, currentAmount,
// deadline, category, priority, status).
//
// Season-aware. All animations created in initState — no
// LateInitializationError.
//
// Goal-created celebration: after createGoal succeeds, a bottom sheet of
// confirmation is shown ("Goal created!" with an animated flag), then the
// list refreshes with the new goal visible.
// ============================================================================

import 'package:flutter/material.dart';

import '../../models/goal.dart';
import '../../models/goal_contribution.dart';
import '../../models/task.dart' show TaskPriority;
import '../../services/goal_service.dart';
import '../../app/currency_controller.dart';
import '../../core/utilities/date_formatter.dart';
import '../../theme/app_theme.dart';

import '../../widgets/lifetrack_card.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen>
    with SingleTickerProviderStateMixin {
  static const double _headerBottomGap = 20;
  static const double _sectionGap = 20;
  static const double _itemGap = 12;

  final _goalService = GoalService();

  late Future<List<Goal>> _goalsFuture;
  String _sortMode = 'default';

  AnimationController? _revealController;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _goalsFuture = _loadGoals();
  }

  @override
  void dispose() {
    _revealController?.dispose();
    super.dispose();
  }

  Future<List<Goal>> _loadGoals() async {
    final goals = await _goalService.getActiveGoals();
    if (mounted) {
      _revealController?.forward(from: 0);
    }
    return goals;
  }

  void _reload() {
    setState(() {
      _goalsFuture = _loadGoals();
    });
  }

  Future<void> _refresh() async {
    final next = _loadGoals();
    setState(() => _goalsFuture = next);
    await next;
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(LifeTrackMetrics.screenPadding),
            children: [
              _header(context),
              const SizedBox(height: _headerBottomGap),
              FutureBuilder<List<Goal>>(
                future: _goalsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _loadingState(context);
                  }
                  if (snapshot.hasError) {
                    return _errorState(context);
                  }
                  final goals =
                      List<Goal>.from(snapshot.data ?? const <Goal>[]);
                  if (goals.isEmpty) return _emptyState(context);
                  _sortGoals(goals);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _summaryCard(context, goals),
                      const SizedBox(height: _sectionGap),
                      _sectionHeader(context, goals.length),
                      const SizedBox(height: 12),
                      _goalsList(context, goals),
                      const SizedBox(height: 16),
                      _quickActions(context),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // HEADER
  // ==========================================================================

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;

    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: s.accent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.flag_rounded, color: s.accentText, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Goals',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                'Keep moving toward what matters.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Material(
          color: s.accent,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: _openAddGoalSheet,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 18, color: s.onAccent),
                  const SizedBox(width: 4),
                  Text(
                    'Add',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: s.onAccent,
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

  // ==========================================================================
  // SUMMARY
  // ==========================================================================

  Widget _summaryCard(BuildContext context, List<Goal> goals) {
    final theme = Theme.of(context);
    final s = context.season;

    final totalTarget =
        goals.fold<double>(0, (sum, g) => sum + g.targetAmount);
    final totalSaved =
        goals.fold<double>(0, (sum, g) => sum + g.currentAmount);
    final progress = totalTarget <= 0
        ? 0.0
        : (totalSaved / totalTarget).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [s.accent, s.accentDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: s.accent.withValues(alpha: 0.28),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(right: -40, top: -50, child: _decorCircle(160)),
          Positioned(right: 20, bottom: -60, child: _decorCircle(120)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: s.onAccent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.flag_rounded,
                        size: 20, color: s.onAccent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Active goals',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: s.onAccent.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: s.onAccent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${goals.length}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: s.onAccent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Saved of target',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: s.onAccent.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: RichText(
                  text: TextSpan(
                    style: theme.textTheme.displayLarge?.copyWith(
                      color: s.onAccent,
                      fontSize: 30,
                    ),
                    children: [
                      TextSpan(text: _peso(totalSaved)),
                      TextSpan(
                        text: ' / ${_peso(totalTarget)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: s.onAccent.withValues(alpha: 0.7),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: s.onAccent.withValues(alpha: 0.20),
                  valueColor: AlwaysStoppedAnimation<Color>(s.onAccent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _decorCircle(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.10),
        ),
      );

  // ==========================================================================
  // SECTION HEADER
  // ==========================================================================

  Widget _sectionHeader(BuildContext context, int goalCount) {
    final theme = Theme.of(context);
    final s = context.season;
    return Row(
      children: [
        Expanded(
          child: Text(
            'MY GOALS',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Material(
          color: s.accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => _showSortOptions(context),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sort_rounded, size: 16, color: s.accentText),
                  const SizedBox(width: 5),
                  Text(
                    _sortModeLabel,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: s.accentText,
                      fontWeight: FontWeight.w600,
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

  String get _sortModeLabel => switch (_sortMode) {
        'name' => 'Name',
        'target' => 'Target',
        'progress' => 'Progress',
        _ => 'Sort',
      };

  // ==========================================================================
  // GOALS LIST
  // ==========================================================================

  Widget _goalsList(BuildContext context, List<Goal> goals) {
    return Column(
      children: [
        for (int index = 0; index < goals.length; index++)
          Padding(
            padding: EdgeInsets.only(
              bottom: index == goals.length - 1 ? 0 : _itemGap,
            ),
            child: _staggeredFade(
              start: (0.10 + index * 0.08).clamp(0.0, 0.6),
              end: (0.55 + index * 0.08).clamp(0.0, 1.0),
              child: _GoalCard(
                goal: goals[index],
                formatCurrency: _peso,
                onTap: () => _openGoalDetails(context, goals[index]),
              ),
            ),
          ),
      ],
    );
  }

  Widget _staggeredFade({
    required double start,
    required double end,
    required Widget child,
  }) {
    final controller = _revealController;
    if (controller == null) return child;
    final anim = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, (1 - anim.value) * 14),
          child: child,
        ),
      ),
    );
  }

  // ==========================================================================
  // QUICK ACTIONS
  // ==========================================================================

  Widget _quickActions(BuildContext context) {
    final s = context.season;
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _openAddGoalSheet,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add goal'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showGoalOptions(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: s.accentText,
              side: BorderSide(color: s.accent.withValues(alpha: 0.35)),
            ),
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('Manage'),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // LOADING / ERROR / EMPTY
  // ==========================================================================

  Widget _loadingState(BuildContext context) {
    final s = context.season;
    return Column(
      children: [
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: s.accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        const SizedBox(height: _sectionGap),
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: _itemGap),
            child: Container(
              height: 96,
              decoration: BoxDecoration(
                color: s.accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
      ],
    );
  }

  Widget _errorState(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.color;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: muted?.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.cloud_off_rounded, size: 27, color: muted),
            ),
            const SizedBox(height: 14),
            Text('Unable to load goals',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text('Check your connection and try again.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;
    return Column(
      children: [
        const SizedBox(height: 12),
        LifeTrackCard(
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: s.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.flag_rounded,
                    size: 30, color: s.accentText),
              ),
              const SizedBox(height: 16),
              Text('No active goals yet',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Create a goal and start working toward it.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _openAddGoalSheet,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Create your first goal'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // SORTING
  // ==========================================================================

  void _sortGoals(List<Goal> goals) {
    switch (_sortMode) {
      case 'name':
        goals.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case 'target':
        goals.sort((a, b) => b.targetAmount.compareTo(a.targetAmount));
        break;
      case 'progress':
        goals.sort((a, b) => b.progress.compareTo(a.progress));
        break;
      case 'default':
      default:
        break;
    }
  }

  // ==========================================================================
  // ADD GOAL
  // ==========================================================================

  Future<void> _openAddGoalSheet() async {
    final nameController = TextEditingController();
    final targetController = TextEditingController();
    final s = context.season;
    DateTime? deadline;

    final goal = await showModalBottomSheet<Goal>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: s.accent.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(Icons.flag_rounded,
                                size: 24, color: s.accentText),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('New goal',
                                    style: Theme.of(sheetContext)
                                        .textTheme
                                        .titleLarge),
                                const SizedBox(height: 2),
                                Text('What are you working toward?',
                                    style: Theme.of(sheetContext)
                                        .textTheme
                                        .bodyMedium),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _fieldLabel(sheetContext, 'GOAL NAME'),
                      const SizedBox(height: 8),
                      _textField(sheetContext, nameController,
                          hint: 'e.g. Emergency fund',
                          autoFocus: true,
                          capWords: true),
                      const SizedBox(height: 16),
                      _fieldLabel(sheetContext, 'TARGET AMOUNT'),
                      const SizedBox(height: 8),
                      _textField(sheetContext, targetController,
                          hint: '0.00',
                          keyboard:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          prefix: '${CurrencyController.symbol} '),
                      const SizedBox(height: 16),
                      _fieldLabel(sheetContext, 'DEADLINE (OPTIONAL)'),
                      const SizedBox(height: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: sheetContext,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 3650)),
                            initialDate: deadline ??
                                DateTime.now()
                                    .add(const Duration(days: 30)),
                          );
                          if (picked != null) {
                            setSheetState(() => deadline = picked);
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: s.accent.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_outlined,
                                  size: 18, color: s.accentText),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  deadline == null
                                      ? 'No deadline'
                                      : DateFormatter.toDisplayDate(
                                          deadline!),
                                  style: Theme.of(sheetContext)
                                      .textTheme
                                      .bodyMedium,
                                ),
                              ),
                              if (deadline != null)
                                GestureDetector(
                                  onTap: () =>
                                      setSheetState(() => deadline = null),
                                  child: Icon(Icons.close_rounded,
                                      size: 18,
                                      color: Theme.of(sheetContext)
                                          .textTheme
                                          .bodyMedium
                                          ?.color),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            final name = nameController.text.trim();
                            final target = double.tryParse(
                                targetController.text.trim());
                            if (name.isNotEmpty &&
                                target != null &&
                                target > 0) {
                              Navigator.pop(
                                sheetContext,
                                Goal(
                                  name: name,
                                  targetAmount:
                                      CurrencyController.toPhp(target),
                                  deadline: deadline == null
                                      ? null
                                      : DateFormatter.toDbDate(deadline!),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(sheetContext)
                                  .showSnackBar(const SnackBar(
                                content: Text(
                                    'Enter a name and a valid target amount.'),
                              ));
                            }
                          },
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Create goal'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text('Cancel'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    targetController.dispose();
    if (goal == null) return;

    try {
      await _goalService.createGoal(goal);
      if (!mounted) return;
      _reload();
      // Small delay so the sheet is fully closed before the dialog appears.
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!mounted) return;
      _showGoalCreatedCelebration(goal);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save goal.')),
        );
      }
    }
  }

  // ==========================================================================
  // GOAL DETAILS — wires add contribution, edit, delete, history
  // ==========================================================================

  Future<void> _openGoalDetails(BuildContext context, Goal goal) async {
    final s = context.season;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.9,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: s.accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.flag_rounded,
                            size: 24, color: s.accentText),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              goal.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              goal.status == GoalStatus.completed
                                  ? 'Completed'
                                  : 'Target ${_peso(goal.targetAmount)}',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: s.accent.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _peso(goal.currentAmount),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: s.accentText,
                                ),
                              ),
                            ),
                            Text(
                              '${(goal.progress * 100).round()}%',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(color: s.accentText),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: goal.progress,
                            minHeight: 8,
                            backgroundColor:
                                s.accent.withValues(alpha: 0.15),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(s.accent),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_peso(goal.remaining)} remaining'
                          '${goal.deadline != null ? ' · due ${_formatDeadline(goal.deadline!)}' : ''}',
                          style: theme.textTheme.bodySmall,
                        ),
                        if (_suggestedWeekly(goal) != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Suggested weekly: ${_peso(_suggestedWeekly(goal)!)}',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: s.accentText),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (goal.status == GoalStatus.active)
                    _sheetAction(
                      sheetContext,
                      icon: Icons.add_rounded,
                      label: 'Add contribution',
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        await _openContributionSheet(goal);
                      },
                    ),
                  if (goal.status == GoalStatus.active)
                    const SizedBox(height: 8),
                  _sheetAction(
                    sheetContext,
                    icon: Icons.edit_rounded,
                    label: 'Edit goal',
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await _openEditGoalSheet(goal);
                    },
                  ),
                  const SizedBox(height: 8),
                  _sheetAction(
                    sheetContext,
                    icon: Icons.history_rounded,
                    label: 'Contribution history',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _openContributionHistory(goal);
                    },
                  ),
                  const SizedBox(height: 8),
                  _sheetAction(
                    sheetContext,
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete goal',
                    destructive: true,
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await _confirmDeleteGoal(goal);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sheetAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final s = context.season;
    final color = destructive ? LifeTrackColors.coral : s.accentText;
    return Material(
      color: destructive
          ? LifeTrackColors.coral.withValues(alpha: 0.06)
          : s.accent.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: destructive ? LifeTrackColors.coral : null,
                        )),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18,
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // ADD CONTRIBUTION
  // ==========================================================================

  Future<void> _openContributionSheet(Goal goal) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final s = context.season;

    final contribution = await showModalBottomSheet<GoalContribution>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: s.accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.savings_rounded,
                            size: 24, color: s.accentText),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Add to ${goal.name}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .titleLarge),
                            const SizedBox(height: 2),
                            Text(
                              '${_peso(goal.remaining)} remaining',
                              style: Theme.of(sheetContext)
                                  .textTheme
                                  .bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _fieldLabel(sheetContext, 'AMOUNT'),
                  const SizedBox(height: 8),
                  _textField(sheetContext, amountController,
                      hint: '0.00',
                      autoFocus: true,
                      keyboard: const TextInputType.numberWithOptions(
                          decimal: true),
                      prefix: '${CurrencyController.symbol} '),
                  const SizedBox(height: 16),
                  _fieldLabel(sheetContext, 'NOTE (OPTIONAL)'),
                  const SizedBox(height: 8),
                  _textField(sheetContext, noteController,
                      hint: 'e.g. From salary',
                      capSentences: true),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        final amount = double.tryParse(
                            amountController.text.trim());
                        if (amount != null && amount > 0) {
                          Navigator.pop(
                            sheetContext,
                            GoalContribution(
                              goalId: goal.id!,
                              amount: CurrencyController.toPhp(amount),
                              date: DateFormatter.toDbDate(DateTime.now()),
                              note: noteController.text.trim().isEmpty
                                  ? null
                                  : noteController.text.trim(),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(sheetContext)
                              .showSnackBar(const SnackBar(
                            content: Text('Enter a valid amount.'),
                          ));
                        }
                      },
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Add contribution'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    amountController.dispose();
    noteController.dispose();
    if (contribution == null) return;

    try {
      await _goalService.addContribution(contribution);
      if (!mounted) return;
      _reload();

      final wasCompleted = goal.status == GoalStatus.completed;
      final nowCompleted =
          goal.currentAmount + contribution.amount >= goal.targetAmount;
      if (!wasCompleted && nowCompleted) {
        _showCompletionCelebration(goal);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added ${_peso(contribution.amount)} to ${goal.name}.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to add contribution.')),
        );
      }
    }
  }

  // ==========================================================================
  // EDIT GOAL
  // ==========================================================================

  Future<void> _openEditGoalSheet(Goal goal) async {
    final nameController = TextEditingController(text: goal.name);
    final targetController = TextEditingController(
      text: goal.targetAmount.toStringAsFixed(2),
    );
    final s = context.season;
    DateTime? deadline = goal.deadline == null
        ? null
        : DateFormatter.fromDbDate(goal.deadline!);

    final updated = await showModalBottomSheet<Goal>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: s.accent.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(Icons.edit_rounded,
                                size: 24, color: s.accentText),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Edit goal',
                                    style: Theme.of(sheetContext)
                                        .textTheme
                                        .titleLarge),
                                const SizedBox(height: 2),
                                Text('Update the name or target.',
                                    style: Theme.of(sheetContext)
                                        .textTheme
                                        .bodyMedium),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _fieldLabel(sheetContext, 'GOAL NAME'),
                      const SizedBox(height: 8),
                      _textField(sheetContext, nameController,
                          capWords: true),
                      const SizedBox(height: 16),
                      _fieldLabel(sheetContext, 'TARGET AMOUNT'),
                      const SizedBox(height: 8),
                      _textField(sheetContext, targetController,
                          keyboard: const TextInputType.numberWithOptions(
                              decimal: true),
                          prefix: '${CurrencyController.symbol} '),
                      const SizedBox(height: 16),
                      _fieldLabel(sheetContext, 'DEADLINE'),
                      const SizedBox(height: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: sheetContext,
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 365)),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 3650)),
                            initialDate: deadline ?? DateTime.now(),
                          );
                          if (picked != null) {
                            setSheetState(() => deadline = picked);
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: s.accent.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_outlined,
                                  size: 18, color: s.accentText),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  deadline == null
                                      ? 'No deadline'
                                      : DateFormatter.toDisplayDate(
                                          deadline!),
                                  style: Theme.of(sheetContext)
                                      .textTheme
                                      .bodyMedium,
                                ),
                              ),
                              if (deadline != null)
                                GestureDetector(
                                  onTap: () =>
                                      setSheetState(() => deadline = null),
                                  child: Icon(Icons.close_rounded,
                                      size: 18,
                                      color: Theme.of(sheetContext)
                                          .textTheme
                                          .bodyMedium
                                          ?.color),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            final name = nameController.text.trim();
                            final target = double.tryParse(
                                targetController.text.trim());
                            if (name.isNotEmpty &&
                                target != null &&
                                target > 0) {
                              Navigator.pop(
                                sheetContext,
                                goal.copyWith(
                                  name: name,
                                  targetAmount:
                                      CurrencyController.toPhp(target),
                                  deadline: deadline == null
                                      ? ''
                                      : DateFormatter.toDbDate(deadline!),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(sheetContext)
                                  .showSnackBar(const SnackBar(
                                content: Text(
                                    'Enter a name and a valid target amount.'),
                              ));
                            }
                          },
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Save changes'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text('Cancel'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    targetController.dispose();
    if (updated == null) return;

    try {
      await _goalService.updateGoal(updated);
      if (mounted) _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to update goal.')),
        );
      }
    }
  }

  // ==========================================================================
  // CONTRIBUTION HISTORY
  // ==========================================================================

  Future<void> _openContributionHistory(Goal goal) async {
    final s = context.season;
    final history = await _goalService.getContributionHistory(goal.id!);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: s.accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.history_rounded,
                            size: 24, color: s.accentText),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Contributions',
                                style: theme.textTheme.titleLarge),
                            const SizedBox(height: 2),
                            Text(goal.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: history.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.savings_outlined,
                                    size: 36,
                                    color: theme
                                        .textTheme.bodyMedium?.color),
                                const SizedBox(height: 10),
                                Text('No contributions yet',
                                    style: theme.textTheme.titleMedium),
                                const SizedBox(height: 4),
                                Text(
                                  'Add one to start building toward this goal.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding:
                              const EdgeInsets.fromLTRB(20, 8, 20, 20),
                          itemCount: history.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final c = history[i];
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: s.accent.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color:
                                          s.accent.withValues(alpha: 0.14),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: Icon(Icons.savings_rounded,
                                        size: 18, color: s.accentText),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _peso(c.amount),
                                          style: theme.textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                  fontWeight:
                                                      FontWeight.w700),
                                        ),
                                        if (c.note != null)
                                          Text(
                                            c.note!,
                                            style:
                                                theme.textTheme.bodySmall,
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(c.date,
                                      style: theme.textTheme.bodySmall),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================================================
  // DELETE
  // ==========================================================================

  Future<void> _confirmDeleteGoal(Goal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.delete_outline_rounded,
            size: 32, color: LifeTrackColors.coral),
        title: const Text('Delete goal?'),
        content: Text(
          'This will permanently delete "${goal.name}" and its contribution '
          'history. This cannot be undone.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: LifeTrackColors.coral,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _goalService.deleteGoal(goal.id!);
      if (mounted) _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to delete goal.')),
        );
      }
    }
  }

  // ==========================================================================
  // GOAL CREATED CELEBRATION
  // ==========================================================================

  void _showGoalCreatedCelebration(Goal goal) {
    final s = context.season;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated: ring expands, flag icon scales in.
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 750),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) {
                    final ring = Curves.easeOutBack
                        .transform((value * 1.4).clamp(0.0, 1.0));
                    final icon = Curves.easeOut
                        .transform(((value - 0.3) / 0.7).clamp(0.0, 1.0));
                    return SizedBox(
                      width: 96,
                      height: 96,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 96 * ring,
                            height: 96 * ring,
                            decoration: BoxDecoration(
                              color: s.accent.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 72 * ring,
                            height: 72 * ring,
                            decoration: BoxDecoration(
                              color: s.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Opacity(
                            opacity: icon,
                            child: Transform.scale(
                              scale: 0.6 + icon * 0.4,
                              child: Icon(Icons.flag_rounded,
                                  size: 38, color: s.onAccent),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'Goal created!',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  '"${goal.name}" is now on your list. '
                  'Add a contribution to start making progress.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.flag_rounded, size: 18),
                    label: const Text('Let\u2019s go'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================================================
  // COMPLETION CELEBRATION
  // ==========================================================================

  void _showCompletionCelebration(Goal goal) {
    final s = context.season;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.elasticOut,
                builder: (context, value, child) =>
                    Transform.scale(scale: value, child: child),
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: s.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.emoji_events_rounded,
                      size: 42, color: s.onAccent),
                ),
              ),
              const SizedBox(height: 18),
              Text('Goal complete!',
                  style: Theme.of(dialogContext)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                'You saved the full ${_peso(goal.targetAmount)} for '
                '"${goal.name}".',
                textAlign: TextAlign.center,
                style: Theme.of(dialogContext).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Nice!'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // MANAGE / SORT
  // ==========================================================================

  void _showGoalOptions(BuildContext context) {
    final s = context.season;
    showModalBottomSheet<void>(
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
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: s.accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.tune_rounded,
                          size: 24, color: s.accentText),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Manage goals',
                              style: theme.textTheme.titleLarge),
                          const SizedBox(height: 2),
                          Text('Sort your active goals.',
                              style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _sheetAction(
                  sheetContext,
                  icon: Icons.sort_rounded,
                  label: 'Sort goals',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showSortOptions(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSortOptions(BuildContext context) {
    final s = context.season;
    showModalBottomSheet<void>(
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
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: s.accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.sort_rounded,
                          size: 24, color: s.accentText),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sort goals',
                              style: theme.textTheme.titleLarge),
                          const SizedBox(height: 2),
                          Text('Choose how your goals are listed.',
                              style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _sortOption(sheetContext,
                    value: 'default',
                    label: 'Default order',
                    icon: Icons.view_list_rounded),
                _sortOption(sheetContext,
                    value: 'name',
                    label: 'Name',
                    icon: Icons.sort_by_alpha_rounded),
                _sortOption(sheetContext,
                    value: 'target',
                    label: 'Target amount',
                    icon: Icons.payments_outlined),
                _sortOption(sheetContext,
                    value: 'progress',
                    label: 'Progress',
                    icon: Icons.trending_up_rounded),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sortOption(
    BuildContext context, {
    required String value,
    required String label,
    required IconData icon,
  }) {
    final selected = _sortMode == value;
    final s = context.season;
    return Material(
      color: selected
          ? s.accent.withValues(alpha: 0.10)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          setState(() => _sortMode = value);
          Navigator.pop(context);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: s.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: s.accentText),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: Theme.of(context).textTheme.bodyLarge),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: s.accent),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // SHARED HELPERS
  // ==========================================================================

  Widget _fieldLabel(BuildContext context, String text) => Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 0.7,
            ),
      );

  Widget _textField(
    BuildContext context,
    TextEditingController controller, {
    String? hint,
    bool autoFocus = false,
    bool capWords = false,
    bool capSentences = false,
    String? prefix,
    TextInputType? keyboard,
  }) {
    final s = context.season;
    return TextField(
      controller: controller,
      autofocus: autoFocus,
      keyboardType: keyboard,
      textCapitalization: capWords
          ? TextCapitalization.words
          : capSentences
              ? TextCapitalization.sentences
              : TextCapitalization.none,
      decoration: InputDecoration(
        hintText: hint,
        prefixText: prefix,
        filled: true,
        fillColor: s.accent.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: s.accent, width: 1.5),
        ),
      ),
    );
  }

  String _peso(double value) => CurrencyController.format(value);

  String _formatDeadline(String dbDate) {
    try {
      return DateFormatter.toDisplayDate(
        DateFormatter.fromDbDate(dbDate),
      );
    } catch (_) {
      return dbDate;
    }
  }

  double? _suggestedWeekly(Goal goal) =>
      _goalService.suggestedWeeklyAmount(goal);
}

// ============================================================================
// GOAL CARD — self-contained. Shows real progress.
// ============================================================================
class _GoalCard extends StatefulWidget {
  const _GoalCard({
    required this.goal,
    required this.formatCurrency,
    required this.onTap,
  });

  final Goal goal;
  final String Function(double) formatCurrency;
  final VoidCallback onTap;

  @override
  State<_GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<_GoalCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tap;

  @override
  void initState() {
    super.initState();
    _tap = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.96,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    await _tap.reverse();
    await _tap.forward();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;
    final goal = widget.goal;

    final isCompleted = goal.status == GoalStatus.completed;

    return ScaleTransition(
      scale: _tap,
      child: LifeTrackCard(
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(LifeTrackMetrics.cardRadius),
            onTap: _handleTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: s.accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          isCompleted
                              ? Icons.emoji_events_rounded
                              : Icons.flag_rounded,
                          size: 22,
                          color: s.accentText,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              goal.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.track_changes_rounded,
                                    size: 14, color: s.accentText),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '${widget.formatCurrency(goal.currentAmount)} of ${widget.formatCurrency(goal.targetAmount)}',
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                                if (goal.deadline != null) ...[
                                  const SizedBox(width: 8),
                                  Icon(Icons.event_outlined,
                                      size: 12,
                                      color: theme
                                          .textTheme.bodyMedium?.color),
                                  const SizedBox(width: 3),
                                  Text(
                                    _shortDate(goal.deadline!),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right_rounded,
                          color: theme.textTheme.bodyMedium?.color
                              ?.withValues(alpha: 0.4)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: goal.progress,
                      minHeight: 6,
                      backgroundColor: s.accent.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(s.accent),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '${(goal.progress * 100).round()}%',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: s.accentText),
                      ),
                      const Spacer(),
                      Text(
                        '${widget.formatCurrency(goal.remaining)} left',
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _shortDate(String dbDate) {
    try {
      final d = DateFormatter.fromDbDate(dbDate);
      return '${d.month}/${d.day}';
    } catch (_) {
      return dbDate;
    }
  }
}
