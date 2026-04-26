import 'package:flutter/material.dart';

import '../widgets/common_widgets.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final data = [
      ('New Booking', 'John Smith booked Riyadh Heritage Tour', Icons.event_available, Colors.green),
      ('Cancellation', 'Sarah Johnson cancelled AlUla Desert Adventure', Icons.cancel_outlined, Colors.redAccent),
      ('New Review', 'A 5-star review was added for Ahmed Al-Mansour', Icons.reviews_outlined, Colors.amber),
      ('Weather Alert', 'High temperature expected tomorrow in Riyadh', Icons.wb_sunny_outlined, Colors.deepOrange),
    ];

    return SectionPanel(
      title: 'Notifications',
      subtitle: 'Bookings, cancellation, reviews, and weather alerts',
      child: Column(
        children: data.map((item) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: item.$4.withOpacity(0.08),
            ),
            child: Row(
              children: [
                Icon(item.$3, color: item.$4),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.$1, style: Theme.of(context).textTheme.titleSmall),
                      Text(item.$2, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                TextButton(onPressed: () {}, child: const Text('View')),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
