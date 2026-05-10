import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/api_service.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../utils/file_download.dart';
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
  late Future<PerformanceMetrics> _performanceFuture;
  ReportSummary? _latestSummary;
  PerformanceMetrics? _latestPerformance;
  bool _isGenerating = false;
  bool _isBackingUp = false;

  @override
  void initState() {
    super.initState();
    _summaryFuture = widget.api.getReportSummary().then((value) {
      _latestSummary = value;
      return value;
    });
    _performanceFuture = widget.api.getPerformanceMetrics().then((value) {
      _latestPerformance = value;
      return value;
    });
  }

  void _reload() {
    setState(() {
      _summaryFuture = widget.api.getReportSummary().then((value) {
        _latestSummary = value;
        return value;
      });
      _performanceFuture = widget.api.getPerformanceMetrics().then((value) {
        _latestPerformance = value;
        return value;
      });
    });
  }

  Future<void> _generateReport() async {
    setState(() {
      _isGenerating = true;
    });
    try {
      final summary = _latestSummary ?? await widget.api.getReportSummary();
      final performance = _latestPerformance ?? await widget.api.getPerformanceMetrics();

      final report = {
        'type': 'company-report',
        'generatedAt': DateTime.now().toIso8601String(),
        'summary': {
          'revenueGrowth': summary.revenueGrowth,
          'customerSatisfaction': summary.customerSatisfaction,
          'cancellationRate': summary.cancellationRate,
          'monthlyRevenue': summary.monthlyRevenue,
          'totalCustomers': summary.totalCustomers,
          'bestCity': summary.bestCity,
          'topLanguages': summary.topLanguages,
        },
        'performance': {
          'totalBookings': performance.totalBookings,
          'confirmedBookings': performance.confirmedBookings,
          'completedBookings': performance.completedBookings,
          'cancelledBookings': performance.cancelledBookings,
          'totalParticipants': performance.totalParticipants,
          'totalCapacity': performance.totalCapacity,
          'fillRate': performance.fillRate,
          'completionRate': performance.completionRate,
          'overallSatisfaction': performance.overallSatisfaction,
          'reviewsCount': performance.reviewsCount,
          'ratingDistribution': {
            '5': performance.ratingDistribution.five,
            '4': performance.ratingDistribution.four,
            '3': performance.ratingDistribution.three,
            '2': performance.ratingDistribution.two,
            '1': performance.ratingDistribution.one,
          },
          'guidePerformance': performance.guidePerformance
              .map((g) => {
                    'guideId': g.guideId,
                    'name': g.name,
                    'averageRating': g.averageRating,
                    'reviewsCount': g.reviewsCount,
                    'toursCount': g.toursCount,
                  })
              .toList(),
          'tourParticipation': performance.tourParticipation
              .map((t) => {
                    'tourId': t.tourId,
                    'name': t.name,
                    'capacity': t.capacity,
                    'bookings': t.bookings,
                    'participants': t.participants,
                    'fillRate': t.fillRate,
                  })
              .toList(),
        },
      };

      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final filename = 'dalalak-report-$stamp.json';
      final downloaded = downloadJsonFile(filename, const JsonEncoder.withIndent('  ').convert(report));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            downloaded
                ? 'Report downloaded as $filename.'
                : 'Report generated (download is only available on web).',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generate report failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _downloadBackup() async {
    setState(() {
      _isBackingUp = true;
    });
    try {
      final json = await widget.api.downloadCompanyBackup();
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final filename = 'dalalak-company-backup-$stamp.json';
      final downloaded = downloadJsonFile(filename, json);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            downloaded
                ? 'Backup downloaded as $filename. A copy is also stored on the server and logged to Firebase.'
                : 'Backup created on the server (download is only available on web).',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Spacer(),
            OutlinedButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _isGenerating ? null : _generateReport,
              icon: _isGenerating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.description_outlined),
              label: Text(_isGenerating ? 'Generating...' : 'Generate Report'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.amber),
              onPressed: _isBackingUp ? null : _downloadBackup,
              icon: _isBackingUp
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.cloud_download_outlined),
              label: Text(_isBackingUp ? 'Backing up...' : 'Download Backup'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FutureBuilder<ReportSummary>(
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
                        value: summary.topLanguages.isEmpty ? 'N/A' : summary.topLanguages.join(', '),
                        tone: const Color(0xFFF7F2FF),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        FutureBuilder<PerformanceMetrics>(
          future: _performanceFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return SectionPanel(
                title: 'Performance & Satisfaction',
                subtitle: 'Failed to load performance metrics',
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

            final perf = snapshot.data;
            if (perf == null) {
              return const SizedBox.shrink();
            }

            return _PerformanceSection(metrics: perf);
          },
        ),
      ],
    );
  }
}

class _PerformanceSection extends StatelessWidget {
  const _PerformanceSection({required this.metrics});

  final PerformanceMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionPanel(
          title: 'Performance & Satisfaction',
          subtitle: 'Tourist ratings & participation analytics (FR-8.2)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 220,
                    child: StatCard(
                      title: 'Overall Satisfaction',
                      value: '${metrics.overallSatisfaction.toStringAsFixed(2)}/5',
                      note: '${metrics.reviewsCount} reviews',
                      icon: Icons.sentiment_satisfied_alt,
                      tint: const Color(0xFFFFF5E9),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: StatCard(
                      title: 'Fill Rate',
                      value: '${metrics.fillRate.toStringAsFixed(1)}%',
                      note: '${metrics.totalParticipants}/${metrics.totalCapacity} seats',
                      icon: Icons.event_seat,
                      tint: const Color(0xFFEEF3FF),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: StatCard(
                      title: 'Completion Rate',
                      value: '${metrics.completionRate.toStringAsFixed(1)}%',
                      note: '${metrics.completedBookings}/${metrics.totalBookings} bookings',
                      icon: Icons.task_alt,
                      tint: const Color(0xFFE8F8F0),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: StatCard(
                      title: 'Cancelled Bookings',
                      value: '${metrics.cancelledBookings}',
                      note: 'Total to date',
                      icon: Icons.cancel_outlined,
                      tint: const Color(0xFFFCEFF0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _RatingDistributionCard(distribution: metrics.ratingDistribution, total: metrics.reviewsCount),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 460,
              child: SectionPanel(
                title: 'Guide Performance',
                subtitle: 'Average rating per guide',
                child: _GuidePerformanceList(items: metrics.guidePerformance),
              ),
            ),
            SizedBox(
              width: 460,
              child: SectionPanel(
                title: 'Tour Participation',
                subtitle: 'Bookings & fill rate per tour',
                child: _TourParticipationList(items: metrics.tourParticipation),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Generated: ${metrics.generatedAt}',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _RatingDistributionCard extends StatelessWidget {
  const _RatingDistributionCard({required this.distribution, required this.total});

  final RatingDistribution distribution;
  final int total;

  @override
  Widget build(BuildContext context) {
    final rows = <(int, int)>[
      (5, distribution.five),
      (4, distribution.four),
      (3, distribution.three),
      (2, distribution.two),
      (1, distribution.one),
    ];
    final maxValue = rows.map((r) => r.$2).fold<int>(0, (p, v) => v > p ? v : p);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFFFFAF2),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rating Distribution', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          if (total == 0)
            Text('No reviews yet.', style: Theme.of(context).textTheme.bodySmall)
          else
            ...rows.map((row) {
              final stars = row.$1;
              final count = row.$2;
              final ratio = maxValue == 0 ? 0.0 : count / maxValue;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Row(
                        children: [
                          Text('$stars', style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(width: 4),
                          const Icon(Icons.star, color: AppColors.amber, size: 14),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 10,
                          backgroundColor: Colors.white,
                          color: AppColors.amber,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(width: 36, child: Text('$count', textAlign: TextAlign.right)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _GuidePerformanceList extends StatelessWidget {
  const _GuidePerformanceList({required this.items});

  final List<GuidePerformance> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text('No guides found.', style: Theme.of(context).textTheme.bodySmall);
    }
    return Column(
      children: items.take(10).map((g) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primary,
                child: Icon(Icons.person, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.name, style: Theme.of(context).textTheme.bodyMedium),
                    Text(
                      '${g.toursCount} tours · ${g.reviewsCount} reviews',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.star, color: AppColors.amber, size: 16),
              const SizedBox(width: 4),
              Text(
                g.averageRating.toStringAsFixed(2),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _TourParticipationList extends StatelessWidget {
  const _TourParticipationList({required this.items});

  final List<TourParticipation> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text('No tours found.', style: Theme.of(context).textTheme.bodySmall);
    }
    return Column(
      children: items.map((t) {
        final ratio = (t.fillRate / 100).clamp(0.0, 1.0);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(t.name, style: Theme.of(context).textTheme.bodyMedium),
                  ),
                  Text(
                    '${t.fillRate.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  backgroundColor: Colors.white,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${t.bookings} bookings · ${t.participants}/${t.capacity} participants',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      }).toList(),
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
