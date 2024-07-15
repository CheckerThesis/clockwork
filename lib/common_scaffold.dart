import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:clockwork/app_state.dart';
import 'package:clockwork/routes/routes.dart';
import 'package:clockwork/pages/login_page.dart';

class CommonScaffold extends StatelessWidget {
  final Widget body;
  final int currentIndex;
  final bool isLoggedIn;

  const CommonScaffold({
    Key? key,
    required this.body,
    required this.currentIndex,
    this.isLoggedIn = true,
  }) : super(key: key);

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
          icon: Icon(Icons.person),
          label: "Employee list",
        ),
      );
    }

    return Scaffold(
      appBar: isLoggedIn
          ? AppBar(
              title: const Text("ClockWork"),
              automaticallyImplyLeading: false,
              actions: <Widget>[
                PopupMenuButton(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (String value) {
                    if (value == 'share_csv') {
                      appState.shareCsvFile();
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem<String>(
                      value: 'share_csv',
                      child: ListTile(
                        leading: Icon(Icons.share),
                        title: Text("Share"),
                      ),
                    ),
                  ],
                )
              ],
            )
          : null,
      body: body,
      floatingActionButton: isLoggedIn
          ? FloatingActionButton(
              backgroundColor: appState.stopwatchManager.isRunning
                  ? const Color.fromARGB(255, 238, 47, 47)
                  : Theme.of(context).floatingActionButtonTheme.focusColor,
              onPressed: appState.stopwatchManager.toggleStopwatch,
              tooltip: appState.stopwatchManager.isRunning ? "Stop" : "Start",
              child: Icon(appState.stopwatchManager.isRunning
                  ? Icons.stop
                  : Icons.play_arrow),
            )
          : null,
      bottomNavigationBar: isLoggedIn
          ? BottomNavigationBar(
              elevation: 20,
              currentIndex: currentIndex,
              onTap: (index) {
                if (index != currentIndex) {
                  switch (index) {
                    case 0:
                      Navigator.of(context)
                          .pushReplacementNamed(RouteManager.homePage);
                      break;
                    case 1:
                      Navigator.of(context)
                          .pushReplacementNamed(RouteManager.workLogPage);
                      break;
                    case 2:
                      if (isSupervisor) {
                        Navigator.of(context).pushReplacementNamed(
                            RouteManager.viewEmployeesPage);
                      }
                      break;
                  }
                }
              },
              items: bottomNavItems,
            )
          : null,
    );
  }
}
