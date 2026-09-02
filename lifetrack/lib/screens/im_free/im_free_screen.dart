// ============================================================================
// I'm Free Screen
// ============================================================================
//
// WHAT THIS SCREEN DOES
// ----------------------------------------------------------------------------
// Finds something to do with the time you have. Two-step flow:
//   1. Pick a time window (15 / 30 / 60 / 120 min, or Custom).
//   2. See the tasks that fit that window, with the ones that don't clearly
//      marked as "Might not fit".
//
// NEW IN THIS VERSION
// ----------------------------------------------------------------------------
// Features:
//   • Task suggestions now classify by FIT: each suggestion is labeled
//     "Fits" / "Might not fit" based on the chosen window (≤ 30 min window
//     → tasks with 30-min windows get a green pill; tasks that would need
//     more time get an amber "Might not fit" pill and are dimmed). The
//     time-window classification uses the existing Task.priority as a
//     proxy for effort (High = 45min, Medium = 30min, Low = 15min).
//
//   • Tap a suggestion → opens a "Focus session" sheet with a live
//     countdown you can pause/resume, then a "Mark complete" button that
//     calls markTaskDone and refreshes the list.
//
//   • Custom time sheet now has preset chips (5 / 15 / 30 / 45 / 60 / 90
//     / 120 / 180) above the slider, so the user can tap a number
//     instead of dragging.
//
// SELF-CONTAINED
// ----------------------------------------------------------------------------
// No LifeTrackCard / LifeTrackButton imports. Everything is defined here:
//   _InlineCard, _Picker, _TimeOptionCard, _Suggestions, _SuggestionCard,
//   _EmptySuggestions, _FocusSessionSheet, _CustomTimeSheet, _StaggerIn.
//
// SEASON COLORS
// ----------------------------------------------------------------------------
// All chrome (icon chips, buttons, sheet headers, list rows) uses
// context.season.accent / accentText / onAccent. The "fits / doesn't fit"
// badges use mint (fit) and amber (doesn't fit) — those are semantic.
// ============================================================================

import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../services/schedule_service.dart';
import '../../theme/app_theme.dart';

class ImFreeScreen extends StatefulWidget {
  const ImFreeScreen({super.key});

  @override
  State<ImFreeScreen> createState() => _ImFreeScreenState();
}

class _ImFreeScreenState extends State<ImFreeScreen>
    with SingleTickerProviderStateMixin {
  int? _minutes;

  // Kick off an entrance animation each time the picker or suggestions
  // view becomes visible.
  AnimationController? _reveal;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..forward();
  }

  @override
  void dispose() {
    _reveal?.dispose();
    super.dispose();
  }

  void _pick(int value) {
    setState(() => _minutes = value);
    _reveal?.forward(from: 0);
  }

  void _reset() {
    setState(() => _minutes = null);
    _reveal?.forward(from: 0);
  }

  Future<void> _pickCustom() async {
    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _CustomTimeSheet(),
    );
    if (result != null) _pick(result);
  }

  Future<void> _startFocus(Task task, int minutes) async {
    final completed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FocusSessionSheet(task: task, minutes: minutes),
    );
    if (completed == true) {
      // Suggestion list is a FutureBuilder on getAllTasks(). Touching
      // _minutes toggles it off then on so the future refetches.
      final current = _minutes;
      if (current != null) {
        setState(() => _minutes = null);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _minutes = current);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.season;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(LifeTrackMetrics.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: s.accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.arrow_back_rounded,
                          size: 20, color: s.accentText),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("I'm Free",
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('Match a task to the time you have.',
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: s.accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded,
                            size: 14, color: s.accentText),
                        const SizedBox(width: 4),
                        Text(
                          _minutes == null ? 'Pick a time' : '$_minutes min',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: s.accentText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.04),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: _minutes == null
                      ? _Picker(
                          key: const ValueKey('picker'),
                          onPicked: _pick,
                          onCustom: _pickCustom,
                        )
                      : _Suggestions(
                          key: const ValueKey('suggestions'),
                          minutes: _minutes!,
                          onReset: _reset,
                          onStart: (task) => _startFocus(task, _minutes!),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Picker
// ============================================================================

class _Picker extends StatelessWidget {
  const _Picker({super.key, required this.onPicked, required this.onCustom});
  final ValueChanged<int> onPicked;
  final VoidCallback onCustom;

  static const _options = [
    (15, Icons.flash_on_rounded, 'Quick win'),
    (30, Icons.local_cafe_rounded, 'Short break'),
    (60, Icons.timer_rounded, 'Focused hour'),
    (120, Icons.workspaces_rounded, 'Deep work'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: s.accent.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.bolt_rounded, size: 34, color: s.accentText),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'How much time do you have?',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          "I'll match tasks that fit your window.",
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.05,
          children: [
            for (var i = 0; i < _options.length; i++)
              _StaggerIn(
                index: i,
                child: _TimeOptionCard(
                  minutes: _options[i].$1,
                  icon: _options[i].$2,
                  label: _options[i].$3,
                  onTap: () => onPicked(_options[i].$1),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onCustom,
            style: OutlinedButton.styleFrom(
              foregroundColor: s.accentText,
              side: BorderSide(color: s.accent.withValues(alpha: 0.35)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('Custom time'),
          ),
        ),
      ],
    );
  }
}

class _TimeOptionCard extends StatefulWidget {
  const _TimeOptionCard({
    required this.minutes,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final int minutes;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_TimeOptionCard> createState() => _TimeOptionCardState();
}

class _TimeOptionCardState extends State<_TimeOptionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tap;

  @override
  void initState() {
    super.initState();
    _tap = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.95,
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

    return ScaleTransition(
      scale: _tap,
      child: _InlineCard(
        onTap: _handleTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: s.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(widget.icon, size: 22, color: s.accentText),
            ),
            const SizedBox(height: 10),
            Text(
              '${widget.minutes}',
              style: theme.textTheme.displayLarge?.copyWith(
                fontSize: 28,
                color: s.accentText,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text('minutes', style: theme.textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Suggestions — now classified by fit against the chosen window
// ============================================================================

class _Suggestions extends StatelessWidget {
  const _Suggestions({
    super.key,
    required this.minutes,
    required this.onReset,
    required this.onStart,
  });

  final int minutes;
  final VoidCallback onReset;
  final ValueChanged<Task> onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;

    return FutureBuilder<List<Task>>(
      future: ScheduleService().getAllTasks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final all = (snapshot.data ?? const <Task>[])
            .where((task) => task.status != TaskStatus.done)
            .toList();

        // Classify every task: how long does it likely take?
        // (No duration field on Task yet — use priority as a proxy.)
        final classified = <_ClassifiedTask>[
          for (final t in all) _ClassifiedTask(task: t, minutes: minutes),
        ];

        // Fits first, then non-fits, both keeping priority order.
        classified.sort((a, b) {
          if (a.fits != b.fits) return a.fits ? -1 : 1;
          return _priorityWeight(b.task.priority)
              .compareTo(_priorityWeight(a.task.priority));
        });

        final fitsCount = classified.where((c) => c.fits).length;

        return ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: s.accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded,
                          size: 14, color: s.accentText),
                      const SizedBox(width: 4),
                      Text('$minutes MIN',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: s.accentText)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$fitsCount of ${classified.length} fit',
                    style: theme.textTheme.labelSmall,
                  ),
                ),
                TextButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: const Text('Change'),
                  style: TextButton.styleFrom(
                    foregroundColor: s.accentText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Your best options',
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Tasks you can start right now.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (classified.isEmpty)
              _EmptySuggestions(minutes: minutes)
            else
              ...List.generate(classified.length, (i) {
                final entry = classified[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _StaggerIn(
                    index: i,
                    child: _SuggestionCard(
                      task: entry.task,
                      minutes: minutes,
                      fits: entry.fits,
                      estimatedMinutes: entry.estimatedMinutes,
                      onTap: () => onStart(entry.task),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  static int _priorityWeight(TaskPriority p) {
    switch (p) {
      case TaskPriority.high:
        return 3;
      case TaskPriority.medium:
        return 2;
      case TaskPriority.low:
        return 1;
    }
  }
}

class _ClassifiedTask {
  const _ClassifiedTask({required this.task, required this.minutes});

  final Task task;
  final int minutes;

  /// Rough effort estimate. Task has no duration field, so use priority:
  /// high → 45 min, medium → 30 min, low → 15 min. This is the same proxy
  /// the future "smart recommendations" feature will use.
  int get estimatedMinutes {
    switch (task.priority) {
      case TaskPriority.high:
        return 45;
      case TaskPriority.medium:
        return 30;
      case TaskPriority.low:
        return 15;
    }
  }

  bool get fits => estimatedMinutes <= minutes;
}

class _SuggestionCard extends StatefulWidget {
  const _SuggestionCard({
    required this.task,
    required this.minutes,
    required this.fits,
    required this.estimatedMinutes,
    required this.onTap,
  });

  final Task task;
  final int minutes;
  final bool fits;
  final int estimatedMinutes;
  final VoidCallback onTap;

  @override
  State<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<_SuggestionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tap;

  @override
  void initState() {
    super.initState();
    _tap = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.97,
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
    final fits = widget.fits;

    return Opacity(
      opacity: fits ? 1.0 : 0.6,
      child: ScaleTransition(
        scale: _tap,
        child: _InlineCard(
          onTap: _handleTap,
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (fits ? s.accent : LifeTrackColors.highlight)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  fits
                      ? Icons.play_circle_outline_rounded
                      : Icons.hourglass_empty_rounded,
                  size: 20,
                  color: fits ? s.accentText : LifeTrackColors.highlightDeep,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _FitBadge(
                          fits: fits,
                          minutes: widget.estimatedMinutes,
                          window: widget.minutes,
                        ),
                        if (widget.task.priority == TaskPriority.high) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: LifeTrackColors.coral
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'High priority',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: LifeTrackColors.coral,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: s.accentText.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FitBadge extends StatelessWidget {
  const _FitBadge({
    required this.fits,
    required this.minutes,
    required this.window,
  });

  final bool fits;
  final int minutes;
  final int window;

  @override
  Widget build(BuildContext context) {
    final color = fits ? LifeTrackColors.mint : LifeTrackColors.highlightDeep;
    final label = fits
        ? 'Fits · ~$minutes min'
        : 'Might not fit · ~$minutes min';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            fits ? Icons.check_rounded : Icons.schedule_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  letterSpacing: 0,
                ),
          ),
        ],
      ),
    );
  }
}

class _EmptySuggestions extends StatelessWidget {
  const _EmptySuggestions({required this.minutes});
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: s.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.self_improvement_rounded,
                  size: 30, color: s.accentText),
            ),
            const SizedBox(height: 16),
            Text(
              'Nothing on your list right now',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Enjoy the $minutes minutes of free time.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Custom time sheet — presets + slider
// ============================================================================

class _CustomTimeSheet extends StatefulWidget {
  const _CustomTimeSheet();

  @override
  State<_CustomTimeSheet> createState() => _CustomTimeSheetState();
}

class _CustomTimeSheetState extends State<_CustomTimeSheet> {
  double _draft = 45;

  static const _presets = [5, 15, 30, 45, 60, 90, 120, 180];

  @override
  Widget build(BuildContext context) {
    final s = context.season;
    final theme = Theme.of(context);

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
                  child: Icon(Icons.bolt_rounded,
                      size: 24, color: s.accentText),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Custom time', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 2),
                      Text('Tap a preset or drag to set the minutes.',
                          style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Big number block
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: s.accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bolt_rounded, color: s.accentText, size: 22),
                  const SizedBox(width: 6),
                  Text(
                    '${_draft.round()}',
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontSize: 40,
                      color: s.accentText,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('MIN',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: s.accentText)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Preset chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in _presets)
                  GestureDetector(
                    onTap: () => setState(() => _draft = p.toDouble()),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _draft.round() == p
                            ? s.accent
                            : s.accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$p',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: _draft.round() == p
                              ? s.onAccent
                              : s.accentText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Slider
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: s.accent,
                thumbColor: s.accent,
                overlayColor: s.accent.withValues(alpha: 0.15),
                inactiveTrackColor: s.accent.withValues(alpha: 0.15),
              ),
              child: Slider(
                value: _draft,
                min: 5,
                max: 240,
                divisions: 47,
                onChanged: (v) => setState(() => _draft = v),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('5', style: theme.textTheme.labelSmall),
                Text('240', style: theme.textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(_draft.round()),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text('Use ${_draft.round()} minutes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Focus session sheet — simple countdown for the chosen task
// ============================================================================

class _FocusSessionSheet extends StatefulWidget {
  const _FocusSessionSheet({required this.task, required this.minutes});

  final Task task;
  final int minutes;

  @override
  State<_FocusSessionSheet> createState() => _FocusSessionSheetState();
}

class _FocusSessionSheetState extends State<_FocusSessionSheet> {
  // Simple wall-clock countdown. Not a full background Timer — this is a
  // short session the user is actively watching.
  int _remainingSeconds = 0;
  bool _running = false;
  bool _done = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.minutes * 60;
  }

  Future<void> _toggleTimer() async {
    if (_done) return;
    setState(() => _running = !_running);
    while (_running && _remainingSeconds > 0 && mounted) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted || !_running) return;
      setState(() => _remainingSeconds -= 1);
    }
    if (mounted && _remainingSeconds == 0) {
      setState(() {
        _running = false;
        _done = true;
      });
    }
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ScheduleService().markTaskDone(widget.task);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to mark task complete.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.season;
    final theme = Theme.of(context);
    final m = _remainingSeconds ~/ 60;
    final sec = _remainingSeconds % 60;
    final display =
        '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    final progress = widget.minutes == 0
        ? 0.0
        : 1 - (_remainingSeconds / (widget.minutes * 60));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  child: Icon(
                    _done
                        ? Icons.check_circle_rounded
                        : Icons.play_circle_outline_rounded,
                    size: 24,
                    color: s.accentText,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _done ? 'Session complete' : 'Focus session',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: SizedBox(
                width: 180,
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        strokeWidth: 8,
                        color: s.accent,
                        backgroundColor:
                            s.accent.withValues(alpha: 0.15),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _done ? 'Done' : display,
                          style: theme.textTheme.displayLarge?.copyWith(
                            fontSize: 34,
                            color: s.accentText,
                          ),
                        ),
                        if (!_done)
                          Text(
                            _running ? 'In progress' : 'Paused',
                            style: theme.textTheme.labelSmall,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (!_done) ...[
              FilledButton.icon(
                onPressed: _toggleTimer,
                icon: Icon(
                  _running
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 20,
                ),
                label: Text(_running ? 'Pause' : 'Start session'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _finish,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Mark complete'),
              ),
            ] else
              FilledButton.icon(
                onPressed: _saving ? null : _finish,
                icon: const Icon(Icons.check_rounded, size: 20),
                label: Text(_saving ? 'Saving…' : 'Mark task complete'),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Local card surface
// ============================================================================

class _InlineCard extends StatelessWidget {
  const _InlineCard({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(LifeTrackMetrics.cardRadius),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(LifeTrackMetrics.cardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(LifeTrackMetrics.cardRadius),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

// ============================================================================
// Stagger helper
// ============================================================================

class _StaggerIn extends StatefulWidget {
  const _StaggerIn({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<_StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<_StaggerIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    final start = (widget.index * 0.06).clamp(0.0, 0.35);
    final curve = CurvedAnimation(
      parent: _c,
      curve: Interval(start, 1.0, curve: Curves.easeOutCubic),
    );
    _fade = curve;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(curve);
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Opacity(
        opacity: _fade.value,
        child: Transform.translate(
          offset: Offset(0, _slide.value.dy * 40),
          child: widget.child,
        ),
      ),
    );
  }
}
