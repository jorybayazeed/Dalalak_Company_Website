import 'package:flutter/material.dart';

import 'layout/dashboard_shell.dart';
import 'pages/login_page.dart';
import 'theme/app_theme.dart';

enum UserRole { company, admin, staff }

enum AppSection {
  dashboard,
  tours,
  createTour,
  guides,
  bookings,
  customers,
  translation,
  reports,
  reviews,
  settings,
  notifications,
}

class DalelakCompanyApp extends StatefulWidget {
  const DalelakCompanyApp({super.key});

  @override
  State<DalelakCompanyApp> createState() => _DalelakCompanyAppState();
}

class _DalelakCompanyAppState extends State<DalelakCompanyApp> {
  bool _isLoggedIn = false;
  UserRole _role = UserRole.company;

  void _onLogin(UserRole role) {
    setState(() {
      _role = role;
      _isLoggedIn = true;
    });
  }

  void _onLogout() {
    setState(() {
      _isLoggedIn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dalelak Company Portal',
      theme: buildAppTheme(),
      home: _isLoggedIn
          ? DashboardShell(role: _role, onLogout: _onLogout)
          : LoginPage(onLogin: _onLogin),
    );
  }
}
