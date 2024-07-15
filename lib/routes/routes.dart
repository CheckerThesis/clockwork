import 'package:flutter/material.dart';
import 'package:clockwork/pages/home_page.dart';
import 'package:clockwork/pages/work_log_page.dart';
import 'package:clockwork/pages/login_page.dart';

class RouteManager {
  static const String loginPage = '/';
  static const String homePage = '/homePage';
  static const String workLogPage = '/workLogPage';
  static const String viewEmployeesPage = '/viewEmployeesPage';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case loginPage:
        return PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LoginPage(),
          transitionDuration: const Duration(seconds: 0),
        );
      case homePage:
        return PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomePage(),
          transitionDuration: const Duration(seconds: 0),
        );
      case workLogPage:
        return PageRouteBuilder(
          pageBuilder: (_, __, ___) => const WorkLogPage(),
          transitionDuration: const Duration(seconds: 0),
        );

      default:
        throw const FormatException('Route not found');
    }
  }
}
