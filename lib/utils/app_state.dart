// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:clockwork/database/time_entry.dart';
import 'package:clockwork/utils/stopwatch_manager.dart';
import 'package:clockwork/database/database_helper.dart';

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  late final StopwatchManager stopwatchManager;
  List<String> jobLabels = ["One", "Two", "Three"];

  final DatabaseHelper dbHelper = DatabaseHelper.instance;

  AppState() {
    WidgetsBinding.instance.addObserver(this);
    stopwatchManager = StopwatchManager(this);
    stopwatchManager.addListener(_onStopwatchManagerChanged);
  }

  Future<void> syncDatabases() async {
    await dbHelper.syncDatabases();
    notifyListeners();
  }

  Future<void> addNewTimeEntry(TimeEntry timeEntry) async {
    await dbHelper.writeLocal(timeEntry);
    syncDatabases(); // Trigger sync after adding new entry
    notifyListeners();
  }

  void removeTimeEntry(BuildContext context, int id) async {
    // await dbHelper.markForDeletion(id);
    syncDatabases(); // Trigger sync after marking for deletion
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Entry marked for deletion'),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.yellow,
          onPressed: () async {
            await dbHelper.updateLocal(TimeEntry(
              id: id,
              job:
                  "Restored", // You might want to store the original job somewhere
              start: DateTime
                  .now(), // You might want to store the original start time
              end: DateTime
                  .now(), // You might want to store the original end time
              needsSync: true,
              isDeleted: false,
            ));
            syncDatabases(); // Trigger sync after undoing delete
            notifyListeners();
          },
        ),
      ),
    );
    notifyListeners();
  }

  Future<void> updateTimeEntryTime(
      BuildContext context, TimeEntry timeEntry, bool isStart) async {
    DateTime initialDateTime = isStart ? timeEntry.start : (timeEntry.end);

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay(hour: initialDateTime.hour, minute: initialDateTime.minute),
    );

    if (pickedTime != null) {
      final DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: initialDateTime,
        firstDate: DateTime(2000),
        lastDate: DateTime(2101),
      );

      if (pickedDate != null) {
        DateTime pickedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        if (isStart) {
          timeEntry.start = pickedDateTime;
        } else {
          timeEntry.end = pickedDateTime;
        }

        timeEntry.needsSync = true;
        await dbHelper.updateLocal(timeEntry);
        await syncDatabases();
        notifyListeners();
      }
    }
  }

  void _onStopwatchManagerChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stopwatchManager.removeListener(_onStopwatchManagerChanged);
    super.dispose();
  }

  void showJobDropdown(BuildContext context, TimeEntry entry) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Select Job"),
          content: DropdownButton<String>(
            isExpanded: true,
            onChanged: (String? newValue) async {
              if (newValue != null) {
                entry.job = newValue;
                entry.needsSync = true;
                await dbHelper.updateLocal(entry);
                syncDatabases();
                Navigator.of(context).pop();
                notifyListeners();
              }
            },
            items: jobLabels.map<DropdownMenuItem<String>>((String job) {
              return DropdownMenuItem<String>(
                value: job,
                child: Text(job),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
