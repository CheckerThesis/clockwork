import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:clockwork/utils/app_state.dart';
import 'package:clockwork/pages/login_page.dart';
import 'package:clockwork/database/time_entry.dart';
import 'package:clockwork/pages/common_scaffold.dart';

class WorkLogPage extends StatefulWidget {
  const WorkLogPage({super.key});

  @override
  State<WorkLogPage> createState() => _WorkLogPageState();
}

class _WorkLogPageState extends State<WorkLogPage> {
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    List<BottomNavigationBarItem> bottomNavItems = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.home),
        label: "Home",
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

    @override
    void initState() {
      super.initState();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Provider.of<AppState>(context, listen: false).syncDatabases();
      });
    }

    return CommonScaffold(
      currentIndex: 1,
      body: FutureBuilder<List<TimeEntry>>(
        future: appState.dbHelper.retrieveLocal(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No entries found'));
          }

          List<TimeEntry> timeEntries =
              snapshot.data!.where((entry) => !entry.isDeleted).toList();
          return ListView.builder(
            itemCount: timeEntries.length,
            itemBuilder: (context, index) {
              TimeEntry timeEntry = timeEntries[index];
              return Column(children: [
                ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: () {
                    if (DateFormat('yyyyMMdd').format(timeEntry.start) !=
                        DateFormat('yyyyMMdd').format(timeEntry.end)) {
                      return Text(
                        "${DateFormat('MMMMd').format(timeEntry.start)} - ${DateFormat('MMMMd').format(timeEntry.end)}",
                        style: const TextStyle(
                            fontSize: 15,
                            color: Color.fromARGB(255, 103, 63, 110),
                            fontWeight: FontWeight.bold),
                      );
                    } else {
                      return Text(
                        DateFormat('MMMMd').format(timeEntry.start),
                        style: const TextStyle(
                            fontSize: 15,
                            color: Color.fromARGB(255, 103, 63, 110),
                            fontWeight: FontWeight.bold),
                      );
                    }
                  }(),
                  trailing: Tooltip(
                    message: "Remove entry",
                    preferBelow: true,
                    child: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        // appState.dbHelper.markForDeletion(timeEntry.id ?? -1);
                      },
                    ),
                  ),
                ),
                Tooltip(
                  message: "Change job",
                  preferBelow: true,
                  child: ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    title: Text(
                      timeEntry.job,
                      style: const TextStyle(fontSize: 15),
                    ),
                    onTap: () {
                      appState.showJobDropdown(context, timeEntry);
                    },
                  ),
                ),
                Tooltip(
                  message: "Change start time",
                  preferBelow: true,
                  child: ListTile(
                    leading: const Icon(Icons.play_arrow,
                        color: Color.fromARGB(255, 45, 178, 49)),
                    title: Text(
                      "Start Time: ${DateFormat('hh:mma').format(timeEntry.start)}",
                      style: const TextStyle(fontSize: 18),
                    ),
                    onTap: () {
                      appState.updateTimeEntryTime(context, timeEntry, true);
                    },
                  ),
                ),
                Tooltip(
                  message: "Change end time",
                  preferBelow: true,
                  child: ListTile(
                    leading: const Icon(Icons.stop,
                        color: Color.fromARGB(255, 202, 26, 26)),
                    title: Text(
                      "End Time:  ${DateFormat('hh:mma').format(timeEntry.end)}",
                      style: const TextStyle(fontSize: 18),
                    ),
                    onTap: () {
                      appState.updateTimeEntryTime(context, timeEntry, false);
                    },
                  ),
                ),
                const Divider(
                  height: 10,
                  thickness: 1,
                  color: Color.fromARGB(125, 153, 153, 153),
                  indent: 7,
                  endIndent: 7,
                ),
              ]);
            },
          );
        },
      ),
    );
  }
}
