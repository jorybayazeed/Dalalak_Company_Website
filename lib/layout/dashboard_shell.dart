import 'package:flutter/material.dart';

import '../app.dart';
import '../data/api_service.dart';
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
import '../pages/organization_profile_page.dart';
import '../pages/promotions_page.dart';
import '../theme/app_theme.dart';
import 'sidebar.dart';
import 'topbar.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({
    super.key,
    required this.api,
    required this.role,
    required this.currentUserName,
    required this.onLogout,
    required this.currentLocale,
    required this.onToggleLocale,
  });

  final ApiService api;
  final UserRole role;
  final String currentUserName;
  final VoidCallback onLogout;
  final Locale currentLocale;
  final VoidCallback onToggleLocale;

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
      case AppSection.organizationProfile:
        return 'Organization Profile';
      case AppSection.promotions:
        return 'Rewards';
    }
  }

  Widget _buildPage() {
    switch (_activeSection) {
      case AppSection.dashboard:
        return DashboardPage(
          api: widget.api,
          onGoToCreateTour: () => _selectSection(AppSection.createTour),
        );
      case AppSection.tours:
        return ToursPage(
          api: widget.api,
          onCreateTour: () => _selectSection(AppSection.createTour),
        );
      case AppSection.createTour:
        return CreateTourPage(
          api: widget.api,
          onCreated: () => _selectSection(AppSection.tours),
        );
      case AppSection.guides:
        return GuidesPage(api: widget.api);
      case AppSection.bookings:
        return BookingsPage(api: widget.api);
      case AppSection.customers:
        return CustomersPage(api: widget.api);
      case AppSection.translation:
        return const LiveTranslationPage();
      case AppSection.reports:
        return ReportsPage(api: widget.api);
      case AppSection.reviews:
        return ReviewsPage(api: widget.api);
      case AppSection.settings:
        return SettingsPage(api: widget.api);
      case AppSection.notifications:
        return NotificationsPage(api: widget.api);
      case AppSection.organizationProfile:
        return OrganizationProfilePage(api: widget.api);
      case AppSection.promotions:
        return PromotionsPage(api: widget.api);
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
          subtitle: 'Welcome back, ${widget.currentUserName}',
          onOpenTranslation: () => _selectSection(AppSection.translation),
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
            currentLocale: widget.currentLocale,
            onToggleLanguage: widget.onToggleLocale,
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
            currentLocale: widget.currentLocale,
            onToggleLanguage: widget.onToggleLocale,
            onLogout: widget.onLogout,
          ),
          Expanded(child: content),
        ],
      ),
    );
  }
}