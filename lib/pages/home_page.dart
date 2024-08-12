// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:clockwork/database/time_entry.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:clockwork/utils/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:clockwork/pages/login_page.dart';
import 'package:clockwork/pages/common_scaffold.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController jobController = TextEditingController();
  Timer? timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppState>(context, listen: false).syncDatabases();
    });
    final appState = Provider.of<AppState>(context, listen: false);
    loadRunningStatus();

    if (appState.stopwatchManager.isRunning) {
      startUITimer();
    }
  }

  void startUITimer() {
    timer = Timer.periodic(const Duration(milliseconds: 30), (Timer t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {});
    });
  }

  loadRunningStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final appState = Provider.of<AppState>(context, listen: false);
    bool isRunning = prefs.getBool('is_Running') ?? false;
    if (isRunning) {
      String? startTimeString = prefs.getString('start_time');
      if (startTimeString != null) {
        DateTime startTime = DateTime.parse(startTimeString);
        appState.stopwatchManager.resumeStopwatch(startTime);
        startUITimer();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    List<BottomNavigationBarItem> bottomNavItems = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.home),
        label: "HHome",
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.list),
        label: "Work log",
      ),
    ];

    if (isSupervisor) {
      bottomNavItems.add(
        const BottomNavigationBarItem(
            icon: Icon(Icons.person), label: "Employee list"),
      );
    }

    return CommonScaffold(
      currentIndex: 0,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              appState.stopwatchManager.getFormattedTime(),
              style: const TextStyle(fontSize: 58),
            ),
            DropdownMenu<String>(
              enabled: !appState.stopwatchManager.isRunning,
              controller: jobController,
              requestFocusOnTap: true,
              leadingIcon: const Icon(Icons.work),
              label: const Text('Job'),
              onSelected: (String? job) {
                appState.stopwatchManager.setSelectedJob(job ?? 'Unknown');
              },
              dropdownMenuEntries: appState.jobLabels
                  .map<DropdownMenuEntry<String>>((String job) {
                return DropdownMenuEntry<String>(
                  value: job,
                  label: job,
                );
              }).toList(),
            ),
            MaterialButton(
              onPressed: () {
                appState.dbHelper.printAzure();
                appState.dbHelper.printLocal();
              },
              child: Text("Print!"),
            ),
          ],
        ),
      ),
    );
  }
}
