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
  @override
  Widget build(BuildContext context) => SafeArea(
      child: Padding(
          padding: const EdgeInsets.all(LifeTrackMetrics.screenPadding),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: const Icon(Icons.arrow_back_rounded)),
              const SizedBox(width: 12),
              Text("I'm Free", style: Theme.of(context).textTheme.titleLarge)
            ]),
            const SizedBox(height: 24),
            Expanded(
                child: _minutes == null
                    ? _Picker(
                        onPicked: (value) => setState(() => _minutes = value))
                    : _Suggestions(
                        minutes: _minutes!,
                        onReset: () => setState(() => _minutes = null)))
          ])));
}

class _Picker extends StatelessWidget {
  const _Picker({required this.onPicked});
  final ValueChanged<int> onPicked;
  @override
  Widget build(BuildContext context) => ListView(children: [
        const Icon(Icons.bolt_rounded,
            size: 34, color: LifeTrackColors.highlight),
        const SizedBox(height: 10),
        Text('How much time do you have?',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 24),
        for (final option in [15, 30, 60, 120])
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LifeTrackCard(
                  onTap: () => onPicked(option),
                  child: Center(
                      child: Text('$option MINUTES',
                          style: Theme.of(context).textTheme.titleMedium)))),
        LifeTrackButton(
            label: 'CUSTOM TIME',
            fullWidth: true,
            style: LifeTrackButtonStyle.secondary,
            onPressed: () => onPicked(45))
      ]);
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.minutes, required this.onReset});
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
        return ListView(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('YOUR BEST OPTIONS',
                style: Theme.of(context).textTheme.labelSmall),
            TextButton(onPressed: onReset, child: const Text('Change time'))
          ]),
          const SizedBox(height: 12),
          if (tasks.isEmpty)
            const Text('No incomplete tasks available.')
          else
            ...tasks.map((task) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: LifeTrackCard(
                    child: Row(children: [
                  const Icon(Icons.task_alt_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(task.title,
                          style: Theme.of(context).textTheme.titleMedium)),
                  Text('$minutes min')
                ]))))
        ]);
      });
}
