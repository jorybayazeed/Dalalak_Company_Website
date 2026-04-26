import 'package:flutter/material.dart';

import '../app.dart';
import '../pages/bookings_page.dart';
import '../pages/create_tour_page.dart';
import '../pages/customers_page.dart';
import '../pages/dashboard_page.dart';
import '../pages/guides_page.dart';
import '../pages/live_translation_page.dart';
import '../pages/notifications_page.dart';
import '../pages/reports_page.dart';
import '../pages/reviews_page.dart';
import '../pages/settings_page.dart';
import '../pages/tours_page.dart';
import '../theme/app_theme.dart';
import 'sidebar.dart';
import 'topbar.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({
    super.key,
    required this.role,
    required this.onLogout,
  });

  final UserRole role;
  final VoidCallback onLogout;

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  AppSection _activeSection = AppSection.dashboard;

  String get _pageTitle {
    switch (_activeSection) {
      case AppSection.dashboard:
        return 'Dashboard';
      case AppSection.tours:
        return 'Tours';
      case AppSection.createTour:
        return 'Create Tour';
      case AppSection.guides:
        return 'Guides';
      case AppSection.bookings:
        return 'Bookings';
      case AppSection.customers:
        return 'Customers';
      case AppSection.translation:
        return 'Live Translation';
      case AppSection.reports:
        return 'Reports';
      case AppSection.reviews:
        return 'Reviews';
      case AppSection.settings:
        return 'Settings';
      case AppSection.notifications:
        return 'Notifications';
    }
  }

  Widget _buildPage() {
    switch (_activeSection) {
      case AppSection.dashboard:
        return DashboardPage(onGoToCreateTour: () => _selectSection(AppSection.createTour));
      case AppSection.tours:
        return ToursPage(onCreateTour: () => _selectSection(AppSection.createTour));
      case AppSection.createTour:
        return const CreateTourPage();
      case AppSection.guides:
        return const GuidesPage();
      case AppSection.bookings:
        return const BookingsPage();
      case AppSection.customers:
        return const CustomersPage();
      case AppSection.translation:
        return const LiveTranslationPage();
      case AppSection.reports:
        return const ReportsPage();
      case AppSection.reviews:
        return const ReviewsPage();
      case AppSection.settings:
        return const SettingsPage();
      case AppSection.notifications:
        return const NotificationsPage();
    }
  }

  void _selectSection(AppSection section) {
    setState(() {
      _activeSection = section;
    });
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 980;
    final content = Column(
      children: [
        TopBar(
          title: _pageTitle,
          subtitle: 'Welcome back, Saudi Heritage Tours',
          onOpenNotifications: () => _selectSection(AppSection.notifications),
        ),
        Expanded(
          child: Container(
            color: AppColors.bg,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _buildPage(),
            ),
          ),
        ),
      ],
    );

    if (compact) {
      return Scaffold(
        drawer: Drawer(
          child: Sidebar(
            activeSection: _activeSection,
            onSelect: (section) {
              Navigator.of(context).pop();
              _selectSection(section);
            },
            onLogout: widget.onLogout,
          ),
        ),
        appBar: AppBar(
          title: const Text('Dalelak Company Portal'),
          leading: Builder(
            builder: (context) {
              return IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              );
            },
          ),
        ),
        body: content,
      );
    }

    return Scaffold(
      body: Row(
        children: [
          Sidebar(
            activeSection: _activeSection,
            onSelect: _selectSection,
            onLogout: widget.onLogout,
          ),
          Expanded(child: content),
        ],
      ),
    );
  }
}
