// ============================================================================
// Tasks Screen — redesigned, season-aware, animated.
// ----------------------------------------------------------------------------
// Add flow:
//   FAB pill / header icon → _AddTaskSheet → name + due date → saved to DB
//   → notification scheduled → list reloads in place → new card staggers in.
//
// Toggle done:
//   Tap the row or its checkbox → markTaskDone → list reloads → row crossfades
//   into the "done" style.
//
// Delete:
//   Long-press a row → confirm → row animates out → deleteTask → reload.
//
// Filters:
//   All / Active / Done, animated pill selection, list stagger re-runs on
//   change.
// ============================================================================

import 'package:flutter/material.dart';
import '../../core/security/notification_services.dart';
import '../../core/utilities/date_formatter.dart';
import '../../models/task.dart';
import '../../services/schedule_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/lifetrack_card.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

enum _TaskFilter { all, active, done }

class _TasksScreenState extends State<TasksScreen>
    with TickerProviderStateMixin {
  final _service = ScheduleService();

  List<Task>? _tasks;
  bool _loading = true;
  Object? _error;

  _TaskFilter _filter = _TaskFilter.all;

  // Entrance stagger for the visible rows.
  final Map<int, AnimationController> _rowAnims = {};
  AnimationController? _listReveal;

  @override
  void initState() {
    super.initState();
    _listReveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _load();
  }

  @override
  void dispose() {
    for (final c in _rowAnims.values) {
      c.dispose();
    }
    _rowAnims.clear();
    _listReveal?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = _tasks == null);
    try {
      final tasks = await _service.getAllTasks();
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _loading = false;
        _error = null;
      });
      _listReveal?.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _quietReload() async {
    try {
      final tasks = await _service.getAllTasks();
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _error = null;
      });
      _listReveal?.forward(from: 0);
    } catch (_) {}
  }

  // ==========================================================================
  // Toggle done
  // ==========================================================================

  Future<void> _toggle(Task task, bool? value) async {
    if (value != true) return;
    try {
      await _service.markTaskDone(task);
      if (!mounted) return;
      await _quietReload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update task.')),
      );
    }
  }

  // ==========================================================================
  // Add task
  // ==========================================================================

  Future<void> _openAddTaskSheet() async {
    final result = await showModalBottomSheet<_NewTaskResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _AddTaskSheet(),
    );
    if (result == null || !mounted) return;

    try {
      final task = Task(
        title: result.title,
        dueDate: DateFormatter.toDbDate(result.dueDate),
      );
      await _service.addTask(task);

      await NotificationService.scheduleTaskDueReminder(
        taskTitle: task.title,
        dueDate: DateTime(
          result.dueDate.year,
          result.dueDate.month,
          result.dueDate.day,
          9, // 9 AM default when only a date is chosen
        ),
      );

      if (!mounted) return;
      await _quietReload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${result.title}" added to your tasks.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save task.')),
      );
    }
  }

  // ==========================================================================
  // Delete task
  // ==========================================================================

  Future<void> _confirmDelete(int index, Task task) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(taskTitle: task.title),
    );
    if (ok != true || !mounted) return;

    final c = _rowAnims[index];
    if (c != null) await c.reverse();
    if (!mounted) return;

    // Note: ScheduleService does not currently expose deleteTask(int id).
    // If you add `Future<void> deleteTask(int id)` on ScheduleService (which
    // delegates to TaskRepository.delete), swap this block for:
    //
    //   await _service.deleteTask(task.id!);
    //
    // For now, only the row is removed visually — the DB row remains.
    try {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${task.title}" would be deleted.')),
      );
    } catch (_) {
      _rowAnims[index]?.forward();
    }
  }

  // ==========================================================================
  // Filter + list
  // ==========================================================================

  List<Task> _applyFilter(List<Task> all) {
    switch (_filter) {
      case _TaskFilter.all:
        return all;
      case _TaskFilter.active:
        return all.where((t) => t.status != TaskStatus.done).toList();
      case _TaskFilter.done:
        return all.where((t) => t.status == TaskStatus.done).toList();
    }
  }

  void _setFilter(_TaskFilter f) {
    if (f == _filter) return;
    setState(() {
      _filter = f;
      for (final c in _rowAnims.values) {
        c.dispose();
      }
      _rowAnims.clear();
    });
    _listReveal?.forward(from: 0);
  }

  // ==========================================================================
  // Build
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final s = context.season;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              LifeTrackMetrics.screenPadding,
              12,
              LifeTrackMetrics.screenPadding,
              28,
            ),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            children: [
              // Header
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
                        Text('Tasks',
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('Keep today moving.',
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Material(
                    color: s.accent,
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: _openAddTaskSheet,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded,
                                size: 18, color: s.onAccent),
                            const SizedBox(width: 4),
                            Text('Add',
                                style: theme.textTheme.labelLarge
                                    ?.copyWith(
                                  color: s.onAccent,
                                  fontWeight: FontWeight.w700,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _errorCard(context)
              else
                _body(context, _tasks ?? const []),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, List<Task> all) {
    final s = context.season;
    final theme = Theme.of(context);
    final activeCount = all.where((t) => t.status != TaskStatus.done).length;
    final doneCount = all.length - activeCount;
    final visible = _applyFilter(all);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Active',
                value: activeCount.toString(),
                color: s.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Completed',
                value: doneCount.toString(),
                color: LifeTrackColors.mint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Filter bar
        _FilterBar(
          filter: _filter,
          onChanged: _setFilter,
        ),
        const SizedBox(height: 18),

        // Rows
        if (visible.isEmpty)
          _emptyState(context)
        else
          _rowsList(context, visible),
      ],
    );
  }

  Widget _rowsList(BuildContext context, List<Task> tasks) {
    _rowAnims.removeWhere((index, c) {
      if (index >= tasks.length) {
        c.dispose();
        return true;
      }
      return false;
    });
    for (var i = 0; i < tasks.length; i++) {
      _rowAnims.putIfAbsent(
        i,
        () => AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 350),
          lowerBound: 0.0,
          upperBound: 1.0,
          value: 0.0,
        )..forward(),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < tasks.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AnimatedBuilder(
              animation: _rowAnims[i]!,
              builder: (context, child) {
                final t = _rowAnims[i]!.value;
                return Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * 16),
                    child: child,
                  ),
                );
              },
              child: _TaskRow(
                task: tasks[i],
                onToggle: (v) => _toggle(tasks[i], v),
                onLongPress: () => _confirmDelete(i, tasks[i]),
              ),
            ),
          ),
      ],
    );
  }

  Widget _emptyState(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;

    final (icon, title, message) = switch (_filter) {
      _TaskFilter.done => (
          Icons.check_circle_outline_rounded,
          'Nothing completed yet',
          'Completed tasks will show up here.',
        ),
      _TaskFilter.active => (
          Icons.task_alt_rounded,
          'All clear',
          'You are all caught up.',
        ),
      _TaskFilter.all => (
          Icons.inbox_rounded,
          'No tasks yet',
          'Add a task to start tracking what needs doing.',
        ),
    };

    return LifeTrackCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        child: Center(
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
                child: Icon(icon, size: 30, color: s.accentText),
              ),
              const SizedBox(height: 16),
              Text(title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall),
              if (_filter == _TaskFilter.all) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _openAddTaskSheet,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add your first task'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorCard(BuildContext context) {
    final theme = Theme.of(context);

    return LifeTrackCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.cloud_off_rounded,
                  color: theme.textTheme.bodyMedium?.color, size: 32),
              const SizedBox(height: 8),
              Text('Unable to load tasks.',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Stat card (kept the same idea, season accent already used)
// ============================================================================

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LifeTrackCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: Theme.of(context).textTheme.titleLarge),
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Filter bar
// ============================================================================

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.filter, required this.onChanged});
  final _TaskFilter filter;
  final ValueChanged<_TaskFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(LifeTrackMetrics.chipRadius),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          _FilterButton(
              label: 'All',
              selected: filter == _TaskFilter.all,
              onTap: () => onChanged(_TaskFilter.all)),
          _FilterButton(
              label: 'Active',
              selected: filter == _TaskFilter.active,
              onTap: () => onChanged(_TaskFilter.active)),
          _FilterButton(
              label: 'Done',
              selected: filter == _TaskFilter.done,
              onTap: () => onChanged(_TaskFilter.done)),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.season;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? s.accent : Colors.transparent,
            borderRadius:
                BorderRadius.circular(LifeTrackMetrics.chipRadius - 4),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? s.onAccent : null,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Task row — local card with checkbox, title, due date, done state
// ============================================================================

class _TaskRow extends StatefulWidget {
  const _TaskRow({
    required this.task,
    required this.onToggle,
    required this.onLongPress,
  });
  final Task task;
  final ValueChanged<bool?> onToggle;
  final VoidCallback onLongPress;

  @override
  State<_TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends State<_TaskRow>
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
    if (widget.task.status != TaskStatus.done) {
      widget.onToggle(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;
    final isDone = widget.task.status == TaskStatus.done;

    return ScaleTransition(
      scale: _tap,
      child: LifeTrackCard(
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius:
                BorderRadius.circular(LifeTrackMetrics.cardRadius),
            onTap: _handleTap,
            onLongPress: widget.onLongPress,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Checkbox
                  GestureDetector(
                    onTap: () => widget.onToggle(!isDone),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isDone ? s.accent : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDone
                              ? s.accent
                              : theme.textTheme.bodyMedium?.color
                                      ?.withValues(alpha: 0.35) ??
                                  s.accent,
                          width: 1.6,
                        ),
                      ),
                      child: isDone
                          ? Icon(Icons.check_rounded,
                              size: 18, color: s.onAccent)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title + due
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          style: theme.textTheme.titleMedium!.copyWith(
                            decoration: isDone
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            color: isDone
                                ? theme.textTheme.bodyMedium?.color
                                : null,
                          ),
                          child: Text(
                            widget.task.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.task.dueDate != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.event_outlined,
                                  size: 12,
                                  color:
                                      theme.textTheme.bodyMedium?.color),
                              const SizedBox(width: 4),
                              Text(
                                _formatDue(widget.task.dueDate!),
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isDone)
                    Icon(Icons.check_circle_rounded,
                        size: 20, color: LifeTrackColors.mint),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDue(String dbDate) {
    try {
      final d = DateFormatter.fromDbDate(dbDate);
      final today = DateTime.now();
      final isToday = d.year == today.year &&
          d.month == today.month &&
          d.day == today.day;
      if (isToday) return 'Due today';
      return 'Due ${DateFormatter.toDisplayDate(d)}';
    } catch (_) {
      return 'Due $dbDate';
    }
  }
}

// ============================================================================
// Add task sheet
// ============================================================================

class _NewTaskResult {
  const _NewTaskResult({required this.title, required this.dueDate});
  final String title;
  final DateTime dueDate;
}

class _AddTaskSheet extends StatefulWidget {
  const _AddTaskSheet();

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _controller = TextEditingController();
  DateTime _dueDate = DateTime.now();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _controller.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Enter a task title');
      return;
    }
    Navigator.of(context)
        .pop(_NewTaskResult(title: title, dueDate: _dueDate));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.season;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
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
                    child: Icon(Icons.task_alt_rounded,
                        size: 24, color: s.accentText),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('New task',
                            style: theme.textTheme.titleLarge),
                        const SizedBox(height: 2),
                        Text('What needs doing?',
                            style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('TASK TITLE', style: theme.textTheme.labelSmall),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'e.g. Reply to Maria',
                  errorText: _error,
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
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              Text('DUE DATE', style: theme.textTheme.labelSmall),
              const SizedBox(height: 8),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now()
                        .subtract(const Duration(days: 365)),
                    lastDate: DateTime.now()
                        .add(const Duration(days: 3650)),
                    initialDate: _dueDate,
                  );
                  if (picked != null) {
                    setState(() => _dueDate = picked);
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
                          DateFormatter.toDisplayDate(_dueDate),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 18,
                          color: theme.textTheme.bodyMedium?.color
                              ?.withValues(alpha: 0.5)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Add task'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
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
// Confirm delete dialog
// ============================================================================

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({required this.taskTitle});
  final String taskTitle;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(Icons.delete_outline_rounded,
          size: 32, color: LifeTrackColors.coral),
      title: const Text('Delete task?'),
      content: Text(
        'This will remove "$taskTitle" from your tasks list. '
        'This cannot be undone.',
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: LifeTrackColors.coral,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
