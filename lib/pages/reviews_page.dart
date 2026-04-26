import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class ReviewsPage extends StatelessWidget {
  const ReviewsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final reviews = [
      ('John Smith', 'Ahmed Al-Mansour', 5, 'Amazing experience! Ahmed was very knowledgeable.'),
      ('Sarah Johnson', 'Fatima Al-Zahrani', 5, 'Unforgettable desert adventure.'),
      ('Marco Polo', 'Mona Al-Harbi', 3, 'Good guide but transportation was late.'),
    ];

    return SectionPanel(
      title: 'All Reviews',
      subtitle: 'Manage customer feedback and moderation',
      child: Column(
        children: reviews.map((r) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF2E6EF7),
                  child: Text(r.$1.characters.first, style: const TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.$1, style: Theme.of(context).textTheme.titleSmall),
                      Text('Guide: ${r.$2}', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Row(children: List.generate(5, (i) => Icon(Icons.star, size: 16, color: i < r.$3 ? Colors.orange : Colors.grey.shade300))),
                      const SizedBox(height: 6),
                      Text(r.$4, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    OutlinedButton(onPressed: () {}, child: const Text('Reply')),
                    const SizedBox(height: 8),
                    OutlinedButton(onPressed: () {}, child: const Text('Delete Abuse')),
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
