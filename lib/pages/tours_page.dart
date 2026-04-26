import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class ToursPage extends StatelessWidget {
  const ToursPage({super.key, required this.onCreateTour});

  final VoidCallback onCreateTour;

  @override
  Widget build(BuildContext context) {
    final tours = [
      {
        'name': 'Riyadh Heritage Tour',
        'city': 'Riyadh',
        'price': '450 SAR',
        'date': '2026-05-15',
        'guide': 'Ahmed Al-Mansour',
        'participants': '12/20',
        'status': 'Active',
      },
      {
        'name': 'AlUla Desert Adventure',
        'city': 'AlUla',
        'price': '850 SAR',
        'date': '2026-05-20',
        'guide': 'Fatima Al-Zahrani',
        'participants': '8/15',
        'status': 'Completed',
      },
      {
        'name': 'Jeddah Coast Discovery',
        'city': 'Jeddah',
        'price': '510 SAR',
        'date': '2026-05-27',
        'guide': 'Khalid Al-Shamri',
        'participants': '0/18',
        'status': 'Cancelled',
      },
    ];

    return SectionPanel(
      title: 'All Tours',
      subtitle: 'Manage all tour packages',
      action: FilledButton.icon(
        onPressed: onCreateTour,
        icon: const Icon(Icons.add),
        label: const Text('Create New Tour'),
      ),
      child: Column(
        children: tours.map((tour) {
          final status = tour['status']!;
          final color = status == 'Active'
              ? Colors.green
              : status == 'Completed'
                  ? Colors.blue
                  : Colors.redAccent;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
              color: Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(tour['name']!, style: Theme.of(context).textTheme.titleMedium),
                          InfoBadge(text: status, color: color),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () {}, icon: const Icon(Icons.visibility_outlined), tooltip: 'Details'),
                    IconButton(onPressed: () {}, icon: const Icon(Icons.edit_outlined), tooltip: 'Edit'),
                    IconButton(onPressed: () {}, icon: const Icon(Icons.delete_outline, color: Colors.redAccent), tooltip: 'Delete'),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 20,
                  runSpacing: 8,
                  children: [
                    _Meta(label: 'City', value: tour['city']!),
                    _Meta(label: 'Price', value: tour['price']!),
                    _Meta(label: 'Date', value: tour['date']!),
                    _Meta(label: 'Guide', value: tour['guide']!),
                    _Meta(label: 'Participants', value: tour['participants']!),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}
