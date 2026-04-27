import 'package:flutter/material.dart';

import 'package:dalelak_company/widgets/common_widgets.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: const [
            SizedBox(width: 290, child: StatCard(title: 'Revenue Growth', value: '+28%', note: 'vs last month', icon: Icons.trending_up, tint: Color(0xFFE8F8F0))),
            SizedBox(width: 290, child: StatCard(title: 'Customer Satisfaction', value: '5.0/5', note: '212 reviews', icon: Icons.star, tint: Color(0xFFFFF5E9))),
            SizedBox(width: 290, child: StatCard(title: 'Cancellation Rate', value: '4.2%', note: 'improved by 1.1%', icon: Icons.cancel_outlined, tint: Color(0xFFFCEFF0))),
          ],
        ),
        const SizedBox(height: 14),
        SectionPanel(
          title: 'Performance Summary',
          subtitle: 'Monthly business analytics',
          child: Column(
            children: const [
              _MetricRow(title: 'Monthly Revenue', value: '140,900 SAR', tone: Color(0xFFE8F8F0)),
              SizedBox(height: 10),
              _MetricRow(title: 'Total Customers', value: '1,420', tone: Color(0xFFEEF3FF)),
              SizedBox(height: 10),
              _MetricRow(title: 'Best City', value: 'Riyadh', tone: Color(0xFFFFF5E9)),
              SizedBox(height: 10),
              _MetricRow(title: 'Most Requested Languages', value: 'English, French, Spanish', tone: Color(0xFFF7F2FF)),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.title, required this.value, required this.tone});

  final String title;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(color: tone, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}