import 'package:flutter/material.dart';

import '../data/api_service.dart';
import '../data/models.dart';
import 'package:dalalak_company_website/widgets/common_widgets.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    required this.api,
  });

  final ApiService api;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<List<NotificationItem>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _notificationsFuture = widget.api.getNotifications();
  }

  void _reload() {
    setState(() {
      _notificationsFuture = widget.api.getNotifications();
    });
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'success':
        return Colors.green;
      case 'danger':
        return Colors.redAccent;
      case 'warning':
        return Colors.amber;
      default:
        return Colors.deepOrange;
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'success':
        return Icons.event_available;
      case 'danger':
        return Icons.cancel_outlined;
      case 'warning':
        return Icons.reviews_outlined;
      default:
        return Icons.wb_sunny_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SectionPanel(
      title: 'Notifications',
      subtitle: 'Bookings, cancellation, reviews, and weather alerts',
      action: OutlinedButton.icon(
        onPressed: _reload,
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh'),
      ),
      child: FutureBuilder<List<NotificationItem>>(
        future: _notificationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return Text(
              'Failed to load notifications: ${snapshot.error}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.redAccent),
            );
          }

          final items = snapshot.data ?? const <NotificationItem>[];
          if (items.isEmpty) {
            return Text('No notifications found.', style: Theme.of(context).textTheme.bodyMedium);
          }

          return Column(
            children: items.map((item) {
              final color = _colorForType(item.type);
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: color.withValues(alpha: 0.08),
                ),
                child: Row(
                  children: [
                    Icon(_iconForType(item.type), color: color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title, style: Theme.of(context).textTheme.titleSmall),
                          Text(item.message, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    TextButton(onPressed: () {}, child: const Text('View')),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
