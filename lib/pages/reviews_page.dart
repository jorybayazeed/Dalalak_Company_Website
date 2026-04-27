import 'package:flutter/material.dart';

import '../data/api_service.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import 'package:dalalak_company_website/widgets/common_widgets.dart';

class ReviewsPage extends StatefulWidget {
  const ReviewsPage({
    super.key,
    required this.api,
  });

  final ApiService api;

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  late Future<List<ReviewItem>> _reviewsFuture;

  @override
  void initState() {
    super.initState();
    _reviewsFuture = widget.api.getReviews();
  }

  void _reload() {
    setState(() {
      _reviewsFuture = widget.api.getReviews();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SectionPanel(
      title: 'All Reviews',
      subtitle: 'Manage customer feedback and moderation',
      action: OutlinedButton.icon(
        onPressed: _reload,
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh'),
      ),
      child: FutureBuilder<List<ReviewItem>>(
        future: _reviewsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return Text(
              'Failed to load reviews: ${snapshot.error}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.redAccent),
            );
          }

          final reviews = snapshot.data ?? const <ReviewItem>[];
          if (reviews.isEmpty) {
            return Text('No reviews found.', style: Theme.of(context).textTheme.bodyMedium);
          }

          return Column(
            children: reviews.map((review) {
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
                      child: Text(review.touristName[0], style: const TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(review.touristName, style: Theme.of(context).textTheme.titleSmall),
                          Text('Guide: ${review.guideName}', style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 4),
                          Row(
                            children: List.generate(
                              5,
                              (i) => Icon(
                                Icons.star,
                                size: 16,
                                color: i < review.rating ? Colors.orange : Colors.grey.shade300,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(review.comment, style: Theme.of(context).textTheme.bodyMedium),
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
          );
        },
      ),
    );
  }
}
