// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:clockwork/database/time_entry.dart';
import 'package:clockwork/database/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

class StopwatchManager extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final Uuid _uuid = const Uuid();

  final Stopwatch _stopwatch = Stopwatch();
  bool _isRunning = false;
  DateTime? _startTime;
  String? _selectedJob;
  Timer? _timer;

  bool get isRunning => _isRunning;
  String? get selectedJob => _selectedJob;
  DateTime? get startTime => _startTime;

  Future<void> _saveRunningState() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_Running', _isRunning);
    if (_isRunning && _startTime != null) {
      await prefs.setString('start_time', _startTime!.toIso8601String());
    } else {
      await prefs.remove('start_time');
    }
  }

  void toggleStopwatch() {
    if (_isRunning) {
      stopStopwatch();
    } else {
      startStopwatch();
    }
    notifyListeners();
  }

  void startStopwatch() {
    _stopwatch.start();
    _isRunning = true;
    _startTime = DateTime.now();
    _startTimer();
    _saveRunningState();
    notifyListeners();
  }

  void stopStopwatch() async {
    _stopwatch.stop();
    _isRunning = false;
    DateTime endTime = DateTime.now();
    _timer?.cancel();

    if (_startTime != null) {
      String jobName = _selectedJob ?? "Unknown";
      TimeEntry entry = TimeEntry(_uuid.v4(), jobName, _startTime!, endTime);
      await _dbHelper.insert(entry);
      developer.log('Stopwatch stopped and entry saved with job: $jobName',
          name: 'StopwatchManager');
      await _dbHelper.printAllEntries(); // Print all entries after inserting
    }

    _stopwatch.reset();
    _startTime = null;
    _selectedJob = null; // Reset selected job after stopping
    _saveRunningState();
    notifyListeners();
  }

  Future<List<TimeEntry>> getAllEntries() async {
    List<TimeEntry> entries = await _dbHelper.queryAllEntries();
    developer.log('Retrieved ${entries.length} entries',
        name: 'StopwatchManager');
    return entries;
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 30), (Timer t) {
      if (!_isRunning) {
        t.cancel();
      }
      notifyListeners();
    });
  }

  void resumeStopwatch(DateTime startTime) {
    _isRunning = true;
    _startTime = startTime;
    _stopwatch.start();
    _startTimer();
    notifyListeners();
  }

  void setSelectedJob(String job) {
    _selectedJob = job;
    notifyListeners();
  }

  String getFormattedTime() {
    if (_startTime == null || !_isRunning) {
      return "00:00:00";
    }

    final elapsed = DateTime.now().difference(_startTime!);
    final hours = elapsed.inHours.toString().padLeft(2, '0');
    final minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');

    return "$hours:$minutes:$seconds";
  }

  Future<void> removeTimeEntry(String id) async {
    await _dbHelper.delete(id);
    notifyListeners();
  }

  Future<void> updateTimeEntry(TimeEntry entry) async {
    await _dbHelper.update(entry);
    notifyListeners();
  }
}
