import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrack/models/task.dart';
import 'package:lifetrack/widgets/task_card.dart';

void main() {
  testWidgets('task card reports completion changes', (tester) async {
    bool? changed;
    const task = Task(title: 'Review budget');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskCard(
            task: task,
            onToggle: (value) => changed = value,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    expect(changed, isTrue);
  });
}
