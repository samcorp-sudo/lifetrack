import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../core/utilities/date_formatter.dart';
import '../../services/schedule_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/lifetrack_card.dart';
import '../../widgets/task_card.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

enum _TaskFilter { all, active, done }

class _TasksScreenState extends State<TasksScreen> {
  final _service = ScheduleService();
  late Future<List<Task>> _future;
  _TaskFilter _filter = _TaskFilter.all;

  @override
  void initState() {
    super.initState();
    _future = _service.getAllTasks();
  }

  List<Task> _visible(List<Task> tasks) {
    return switch (_filter) {
      _TaskFilter.all => tasks,
      _TaskFilter.active =>
        tasks.where((task) => task.status != TaskStatus.done).toList(),
      _TaskFilter.done =>
        tasks.where((task) => task.status == TaskStatus.done).toList(),
    };
  }

  Future<void> _toggle(Task task, bool? value) async {
    if (value != true) return;
    await _service.markTaskDone(task);
    if (mounted) setState(() => _future = _service.getAllTasks());
  }

  Future<void> _openAddTaskDialog() async {
    final controller = TextEditingController();
    var dueDate = DateTime.now();
    final task = await showDialog<Task>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add task'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Task title'),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    final selected = await showDatePicker(
                      context: dialogContext,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      initialDate: dueDate,
                    );
                    if (selected != null) {
                      setDialogState(() => dueDate = selected);
                    }
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text('Due ${DateFormatter.toDisplayDate(dueDate)}'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final title = controller.text.trim();
              if (title.isNotEmpty) {
                Navigator.pop(
                    dialogContext,
                    Task(
                        title: title,
                        dueDate: DateFormatter.toDbDate(dueDate)));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (task != null) {
      try {
        await _service.addTask(task);
        if (mounted) _reload();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Unable to save task.')));
        }
      }
    }
  }

  void _reload() {
    setState(() => _future = _service.getAllTasks());
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<List<Task>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _TaskMessage(
              icon: Icons.error_outline_rounded,
              title: 'Could not load tasks',
              message: 'Something went wrong while reading your task list.',
              actionLabel: 'Try again',
              onAction: _reload,
            );
          }

          final allTasks = snapshot.data ?? const <Task>[];
          final visibleTasks = _visible(allTasks);
          final activeCount =
              allTasks.where((task) => task.status != TaskStatus.done).length;
          final doneCount = allTasks.length - activeCount;

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                LifeTrackMetrics.screenPadding,
                12,
                LifeTrackMetrics.screenPadding,
                28,
              ),
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Tasks',
                          style: Theme.of(context).textTheme.headlineMedium),
                    ),
                    IconButton(
                      tooltip: 'Add task',
                      onPressed: _openAddTaskDialog,
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Keep today moving',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                        child: _TaskStat(
                            label: 'Active',
                            value: activeCount.toString(),
                            color: LifeTrackColors.highlight)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _TaskStat(
                            label: 'Completed',
                            value: doneCount.toString(),
                            color: LifeTrackColors.mint)),
                  ],
                ),
                const SizedBox(height: 24),
                _TaskFilterBar(
                  filter: _filter,
                  onChanged: (filter) => setState(() => _filter = filter),
                ),
                const SizedBox(height: 18),
                if (visibleTasks.isEmpty)
                  _TaskMessage(
                    icon: _filter == _TaskFilter.done
                        ? Icons.check_circle_outline_rounded
                        : Icons.inbox_rounded,
                    title: _filter == _TaskFilter.done
                        ? 'Nothing completed yet'
                        : 'No tasks here',
                    message: _filter == _TaskFilter.active
                        ? 'You are all caught up.'
                        : 'Tasks will appear here when they are added.',
                  )
                else
                  ...visibleTasks.map(
                    (task) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TaskCard(
                          task: task,
                          onToggle: (value) => _toggle(task, value)),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TaskStat extends StatelessWidget {
  const _TaskStat(
      {required this.label, required this.value, required this.color});

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

class _TaskFilterBar extends StatelessWidget {
  const _TaskFilterBar({required this.filter, required this.onChanged});

  final _TaskFilter filter;
  final ValueChanged<_TaskFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(LifeTrackMetrics.chipRadius),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? LifeTrackColors.strokeDark
              : LifeTrackColors.strokeLight,
        ),
      ),
      child: Row(
        children: [
          _TaskFilterButton(
              label: 'All',
              selected: filter == _TaskFilter.all,
              onTap: () => onChanged(_TaskFilter.all)),
          _TaskFilterButton(
              label: 'Active',
              selected: filter == _TaskFilter.active,
              onTap: () => onChanged(_TaskFilter.active)),
          _TaskFilterButton(
              label: 'Done',
              selected: filter == _TaskFilter.done,
              onTap: () => onChanged(_TaskFilter.done)),
        ],
      ),
    );
  }
}

class _TaskFilterButton extends StatelessWidget {
  const _TaskFilterButton(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? LifeTrackColors.highlight : Colors.transparent,
            borderRadius:
                BorderRadius.circular(LifeTrackMetrics.chipRadius - 4),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? LifeTrackColors.ink : null,
                ),
          ),
        ),
      ),
    );
  }
}

class _TaskMessage extends StatelessWidget {
  const _TaskMessage(
      {required this.icon,
      required this.title,
      required this.message,
      this.actionLabel,
      this.onAction});

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
        child: Column(
          children: [
            Icon(icon,
                size: 42, color: Theme.of(context).textTheme.bodyMedium?.color),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
