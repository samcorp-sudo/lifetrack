import 'package:flutter/material.dart';
import '../../core/utilities/date_formatter.dart';
import '../../models/schedule.dart';
import '../../services/schedule_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/schedule_card.dart';
import 'add_activity_sheet.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final _service = ScheduleService();
  DateTime _selectedDate = DateTime.now();
  late Future<List<Schedule>> _future;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future =
        _service.getScheduleForDate(DateFormatter.toDbDate(_selectedDate));
  }

  void _moveDay(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
      _reload();
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
      child: Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton(
              backgroundColor: LifeTrackColors.highlight,
              onPressed: () async {
                final saved = await AddActivitySheet.show(context);
                if (saved == true && mounted) setState(_reload);
              },
              child: const Icon(Icons.add, color: LifeTrackColors.ink)),
          body: FutureBuilder<List<Schedule>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                      child: Text('Unable to load schedule records.'));
                }
                final items = snapshot.data ?? const <Schedule>[];
                return ListView(
                    padding:
                        const EdgeInsets.all(LifeTrackMetrics.screenPadding),
                    children: [
                      Row(children: [
                        const Icon(Icons.arrow_back_rounded),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text('Schedule',
                                style: Theme.of(context).textTheme.titleLarge)),
                        const Icon(Icons.more_vert_rounded)
                      ]),
                      const SizedBox(height: 16),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                                onPressed: () => _moveDay(-1),
                                icon: const Icon(Icons.chevron_left_rounded)),
                            Text(DateFormatter.toDisplayDate(_selectedDate),
                                style: Theme.of(context).textTheme.titleMedium),
                            IconButton(
                                onPressed: () => _moveDay(1),
                                icon: const Icon(Icons.chevron_right_rounded))
                          ]),
                      const SizedBox(height: 20),
                      if (items.isEmpty)
                        const Text('No activities scheduled for this day.')
                      else
                        ...items.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ScheduleCard(activity: item))),
                      const SizedBox(height: 80)
                    ]);
              })));
}
