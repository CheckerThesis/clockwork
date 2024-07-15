// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:clockwork/database/time_entry.dart';
import 'stopwatch_manager.dart';
import 'package:clockwork/database/database_helper.dart';

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  final StopwatchManager stopwatchManager = StopwatchManager();
  List<String> jobLabels = ["One", "Two", "Three"];

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  AppState() {
    WidgetsBinding.instance.addObserver(this);
    stopwatchManager.addListener(_onStopwatchManagerChanged);
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

  Future<void> shareCsvFile() async {
    List<TimeEntry> timeEntries = await stopwatchManager.getAllEntries();
    List<List<String>> csvData = [
      ['Job', 'Start timeDate', 'End timeDate', 'Duration'],
      ...timeEntries.map((entry) => [
            entry.job,
            entry.formattedStart,
            entry.formattedEnd,
            entry.formattedDuration
          ])
    ];

    String csv = const ListToCsvConverter().convert(csvData);
    Directory directory = await getTemporaryDirectory();
    String path = '${directory.path}/job.csv';
    File file = File(path);
    await file.writeAsString(csv);
    XFile xfile = XFile(path);
    await Share.shareXFiles([xfile], text: 'Check out this CSV file!');
  }

  void removeTimeEntry(BuildContext context, String id) async {
    await stopwatchManager.removeTimeEntry(id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Entry removed'),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.yellow,
          onPressed: () {
            _dbHelper.undoDelete();
          },
        ),
      ),
    );
  }

  Future<void> updateTimeEntryTime(
      BuildContext context, TimeEntry entry, bool isStart) async {
    DateTime initialDateTime =
        isStart ? entry.start : (entry.end ?? DateTime.now());

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
          entry.start = pickedDateTime;
        } else {
          entry.end = pickedDateTime;
        }

        await stopwatchManager.updateTimeEntry(entry);
      }
    }
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
                await stopwatchManager.updateTimeEntry(entry);
                Navigator.of(context).pop();
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
