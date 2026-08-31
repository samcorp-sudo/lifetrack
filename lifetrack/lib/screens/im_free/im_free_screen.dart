import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../services/schedule_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/lifetrack_card.dart';
import '../../widgets/lifetrack_button.dart';

class ImFreeScreen extends StatefulWidget {
  const ImFreeScreen({super.key});
  @override
  State<ImFreeScreen> createState() => _ImFreeScreenState();
}

class _ImFreeScreenState extends State<ImFreeScreen> {
  int? _minutes;

  void _pick(int value) => setState(() => _minutes = value);
  void _reset() => setState(() => _minutes = null);

  Future<void> _pickCustom() async {
    double draft = 45;
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
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
                Text('Custom time',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('Drag to set how many minutes you have',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bolt_rounded,
                        color: LifeTrackColors.highlight, size: 20),
                    const SizedBox(width: 6),
                    Text('${draft.round()} MIN',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: LifeTrackColors.highlight,
                    thumbColor: LifeTrackColors.highlight,
                    overlayColor:
                        LifeTrackColors.highlight.withValues(alpha: 0.15),
                    inactiveTrackColor:
                        LifeTrackColors.highlight.withValues(alpha: 0.15),
                  ),
                  child: Slider(
                    value: draft,
                    min: 5,
                    max: 240,
                    divisions: 47,
                    onChanged: (v) => setSheetState(() => draft = v),
                  ),
                ),
                const SizedBox(height: 8),
                LifeTrackButton(
                  label: 'USE ${draft.round()} MINUTES',
                  fullWidth: true,
                  onPressed: () => Navigator.of(context).pop(draft.round()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null) _pick(result);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
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
                  Text("I'm Free",
                      style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.03),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
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
                        ),
                ),
              ),
            ],
          ),
        ),
      );
}

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
  Widget build(BuildContext context) => ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          const Icon(Icons.bolt_rounded,
              size: 34, color: LifeTrackColors.highlight),
          const SizedBox(height: 10),
          Text('How much time do you have?',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text("I'll match tasks that fit your window",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.15,
            children: [
              for (final (minutes, icon, label) in _options)
                LifeTrackCard(
                  onTap: () => onPicked(minutes),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 26, color: LifeTrackColors.highlight),
                      const SizedBox(height: 10),
                      Text('$minutes',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text('minutes',
                          style: Theme.of(context).textTheme.labelSmall),
                      const SizedBox(height: 4),
                      Text(label,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          LifeTrackButton(
            label: 'CUSTOM TIME',
            fullWidth: true,
            style: LifeTrackButtonStyle.secondary,
            onPressed: onCustom,
          ),
        ],
      );
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({super.key, required this.minutes, required this.onReset});
  final int minutes;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Task>>(
        future: ScheduleService().getAllTasks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final tasks = (snapshot.data ?? const <Task>[])
              .where((task) => task.status != TaskStatus.done)
              .toList();

          return ListView(
            physics: const BouncingScrollPhysics(),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt_rounded,
                          size: 16, color: LifeTrackColors.highlight),
                      const SizedBox(width: 6),
                      Text('$minutes MIN · ${tasks.length} OPTIONS',
                          style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: const Text('Change time'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Your best options',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              if (tasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.self_improvement_rounded,
                          size: 40,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      Text('Nothing on your list right now',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text('Enjoy the free time.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                    ],
                  ),
                )
              else
                ...tasks.map((task) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: LifeTrackCard(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: LifeTrackColors.highlight
                                    .withValues(alpha: 0.12),
                              ),
                              child: const Icon(Icons.task_alt_rounded,
                                  size: 18, color: LifeTrackColors.highlight),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(task.title,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withValues(alpha: .08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.schedule_rounded, size: 12),
                                  const SizedBox(width: 4),
                                  Text('$minutes min',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
            ],
          );
        },
      );
}
