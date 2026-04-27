import 'package:flutter/material.dart';

import '../data/api_service.dart';
import '../data/models.dart';
import 'package:dalalak_company_website/widgets/common_widgets.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({
    super.key,
    required this.api,
  });

  final ApiService api;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late Future<ReportSummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = widget.api.getReportSummary();
  }

  void _reload() {
    setState(() {
      _summaryFuture = widget.api.getReportSummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ReportSummary>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return SectionPanel(
            title: 'Reports Error',
            subtitle: 'Failed to load live report data',
            action: OutlinedButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
            child: Text(
              '${snapshot.error}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.redAccent),
            ),
          );
        }

        final summary = snapshot.data;
        if (summary == null) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            Row(
              children: [
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 290,
                  child: StatCard(
                    title: 'Revenue Growth',
                    value: '+${summary.revenueGrowth}%',
                    note: 'vs last month',
                    icon: Icons.trending_up,
                    tint: const Color(0xFFE8F8F0),
                  ),
                ),
                SizedBox(
                  width: 290,
                  child: StatCard(
                    title: 'Customer Satisfaction',
                    value: '${summary.customerSatisfaction.toStringAsFixed(1)}/5',
                    note: 'Live average rating',
                    icon: Icons.star,
                    tint: const Color(0xFFFFF5E9),
                  ),
                ),
                SizedBox(
                  width: 290,
                  child: StatCard(
                    title: 'Cancellation Rate',
                    value: '${summary.cancellationRate.toStringAsFixed(1)}%',
                    note: 'From current bookings',
                    icon: Icons.cancel_outlined,
                    tint: const Color(0xFFFCEFF0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SectionPanel(
              title: 'Performance Summary',
              subtitle: 'Monthly business analytics',
              child: Column(
                children: [
                  _MetricRow(title: 'Monthly Revenue', value: '${summary.monthlyRevenue} SAR', tone: const Color(0xFFE8F8F0)),
                  const SizedBox(height: 10),
                  _MetricRow(title: 'Total Customers', value: '${summary.totalCustomers}', tone: const Color(0xFFEEF3FF)),
                  const SizedBox(height: 10),
                  _MetricRow(title: 'Best City', value: summary.bestCity, tone: const Color(0xFFFFF5E9)),
                  const SizedBox(height: 10),
                  _MetricRow(
                    title: 'Most Requested Languages',
                    value: summary.topLanguages.join(', '),
                    tone: const Color(0xFFF7F2FF),
                  ),
                ],
              ),
            ),
          ],
        );
      },
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
