import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/api_service.dart';
import 'data/models.dart';
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
  organizationProfile,
  promotions,
}

class DalelakCompanyApp extends StatefulWidget {
  const DalelakCompanyApp({super.key});

  @override
  State<DalelakCompanyApp> createState() => _DalelakCompanyAppState();
}

class _DalelakCompanyAppState extends State<DalelakCompanyApp> {
  static String _resolveApiUrl() {
    const configured = String.fromEnvironment('DALALAK_API_URL', defaultValue: '');
    if (configured.isNotEmpty) {
      return configured;
    }

    if (kIsWeb) {
      final base = Uri.base;
      final host = base.host;

      if (host.endsWith('app.github.dev')) {
        final apiHost = host.replaceFirst(
          RegExp(r'-\d+\.app\.github\.dev$'),
          '-4000.app.github.dev',
        );
        return 'https://$apiHost';
      }

      if (host != 'localhost' && host != '127.0.0.1') {
        final scheme = base.scheme == 'https' ? 'https' : 'http';
        return '$scheme://$host:4000';
      }
    }

    return 'http://localhost:4000';
  }

  final ApiService _api = ApiService(baseUrl: _resolveApiUrl());
  bool _isLoggedIn = false;
  bool _isLoggingIn = false;
  String? _loginError;
  UserRole _role = UserRole.company;
  AppUser? _currentUser;
  Locale _locale = const Locale('en');

  String _roleToApiRole(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'admin';
      case UserRole.staff:
        return 'staff';
      case UserRole.company:
        return 'company';
    }
  }

  UserRole _apiRoleToRole(String role) {
    switch (role) {
      case 'admin':
        return UserRole.admin;
      case 'staff':
        return UserRole.staff;
      default:
        return UserRole.company;
    }
  }

  Future<void> _onLogin(LoginFormData formData) async {
    setState(() {
      _isLoggingIn = true;
      _loginError = null;
    });

    try {
      final response = await _api.login(
        email: formData.email,
        password: formData.password,
        role: _roleToApiRole(formData.role),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _role = _apiRoleToRole(response.user.role);
        _currentUser = response.user;
        _isLoggedIn = true;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loginError = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loginError = 'Failed to connect to backend server.';
      });
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoggingIn = false;
      });
    }
  }

  Future<void> _onLogout() async {
    try {
      await _api.logout();
    } catch (_) {}

    setState(() {
      _isLoggedIn = false;
      _currentUser = null;
      _loginError = null;
    });
  }

  void _onToggleLocale() {
    setState(() {
      _locale = _locale.languageCode == 'en' ? const Locale('ar') : const Locale('en');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dalelak Company Portal',
      theme: buildAppTheme(),
      locale: _locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: _isLoggedIn
          ? DashboardShell(
              api: _api,
              role: _role,
              currentUserName: _currentUser?.name ?? 'User',
              onLogout: () {
                _onLogout();
              },
              currentLocale: _locale,
              onToggleLocale: _onToggleLocale,
            )
          : LoginPage(
              onLogin: _onLogin,
              isLoading: _isLoggingIn,
              errorText: _loginError,
            ),
    );
  }
}