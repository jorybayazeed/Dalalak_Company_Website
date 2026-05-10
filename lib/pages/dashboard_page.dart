import 'package:flutter/material.dart';

import '../data/api_service.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import 'package:dalalak_company_website/widgets/common_widgets.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.api,
    required this.onGoToCreateTour,
  });

  final ApiService api;
  final VoidCallback onGoToCreateTour;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<DashboardOverview> _overviewFuture;
  late Future<PerformanceMetrics> _performanceFuture;

  @override
  void initState() {
    super.initState();
    _overviewFuture = widget.api.getDashboardOverview();
    _performanceFuture = widget.api.getPerformanceMetrics();
  }

  void _reload() {
    setState(() {
      _overviewFuture = widget.api.getDashboardOverview();
      _performanceFuture = widget.api.getPerformanceMetrics();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardOverview>(
      future: _overviewFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return _LoadError(onRetry: _reload, message: snapshot.error.toString());
        }

        final overview = snapshot.data;
        if (overview == null) {
          return _LoadError(onRetry: _reload, message: 'No dashboard data available.');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Live Overview', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 220,
                  child: StatCard(
                    title: 'Today Bookings',
                    value: '${overview.todayBookings}',
                    note: 'Live from Firebase',
                    icon: Icons.calendar_month,
                    tint: const Color(0xFFE8F8F0),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: StatCard(
                    title: 'Active Tours',
                    value: '${overview.activeTours}',
                    note: 'Current active packages',
                    icon: Icons.location_on_outlined,
                    tint: const Color(0xFFEEF3FF),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: StatCard(
                    title: 'Current Tourists',
                    value: '${overview.currentTourists}',
                    note: 'Confirmed + pending',
                    icon: Icons.groups_2_outlined,
                    tint: const Color(0xFFF5EEFF),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: StatCard(
                    title: 'Monthly Revenue',
                    value: '${overview.monthlyRevenue} SAR',
                    note: 'Confirmed and completed',
                    icon: Icons.attach_money,
                    tint: const Color(0xFFFFF5E9),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: StatCard(
                    title: 'Guides Count',
                    value: '${overview.guidesCount}',
                    note: 'Active guide pool',
                    icon: Icons.badge_outlined,
                    tint: const Color(0xFFEAF7FF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _ActionCard(
                  title: 'Create New Tour',
                  subtitle: 'Add a new tour package',
                  color: AppColors.primary,
                  onTap: widget.onGoToCreateTour,
                ),
                _ActionCard(
                  title: 'Reload Metrics',
                  subtitle: 'Fetch the latest analytics',
                  color: AppColors.amber,
                  onTap: _reload,
                ),
              ],
            ),
            const SizedBox(height: 14),
            FutureBuilder<PerformanceMetrics>(
              future: _performanceFuture,
              builder: (context, perfSnap) {
                if (perfSnap.connectionState == ConnectionState.waiting) {
                  return const SectionPanel(
                    title: 'Performance & Satisfaction',
                    subtitle: 'Loading from Firebase...',
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                if (perfSnap.hasError) {
                  return SectionPanel(
                    title: 'Performance & Satisfaction',
                    subtitle: 'Failed to load',
                    child: Text(
                      '${perfSnap.error}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.redAccent),
                    ),
                  );
                }
                final perf = perfSnap.data;
                if (perf == null) return const SizedBox.shrink();
                return _PerformanceCharts(metrics: perf);
              },
            ),
            const SizedBox(height: 14),
            SectionPanel(
              title: 'Analytics Overview',
              subtitle: 'Monthly bookings, most requested cities, and top-rated guides',
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 980;
                  if (compact) {
                    return Column(
                      children: [
                        _MiniChartCard(
                          title: 'Monthly Bookings',
                          points: overview.monthlyBookings,
                          labels: overview.monthlyLabels,
                        ),
                        const SizedBox(height: 12),
                        _CityDemandCard(data: overview.topCities),
                        const SizedBox(height: 12),
                        _TopGuidesCard(guides: overview.topGuides),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _MiniChartCard(
                          title: 'Monthly Bookings',
                          points: overview.monthlyBookings,
                          labels: overview.monthlyLabels,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _CityDemandCard(data: overview.topCities)),
                      const SizedBox(width: 12),
                      Expanded(child: _TopGuidesCard(guides: overview.topGuides)),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PerformanceCharts extends StatelessWidget {
  const _PerformanceCharts({required this.metrics});

  final PerformanceMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return SectionPanel(
      title: 'Performance & Satisfaction',
      subtitle: 'Tourist ratings & participation (FR-8.2)',
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
                  note: '${metrics.reviewsCount} tourist reviews',
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
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 880;
              if (compact) {
                return Column(
                  children: [
                    _SatisfactionChart(distribution: metrics.ratingDistribution, total: metrics.reviewsCount),
                    const SizedBox(height: 12),
                    _BookingStatusChart(metrics: metrics),
                    const SizedBox(height: 12),
                    _TopToursChart(items: metrics.tourParticipation),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _SatisfactionChart(distribution: metrics.ratingDistribution, total: metrics.reviewsCount),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _BookingStatusChart(metrics: metrics)),
                  const SizedBox(width: 12),
                  Expanded(child: _TopToursChart(items: metrics.tourParticipation)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SatisfactionChart extends StatelessWidget {
  const _SatisfactionChart({required this.distribution, required this.total});

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

    return _ChartCard(
      title: 'Satisfaction Distribution',
      subtitle: 'Tourist ratings (1–5 stars)',
      child: total == 0
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'No tourist reviews yet.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            )
          : Column(
              children: rows.map((row) {
                final stars = row.$1;
                final count = row.$2;
                final ratio = maxValue == 0 ? 0.0 : count / maxValue;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 50,
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
                            minHeight: 12,
                            backgroundColor: Colors.white,
                            color: AppColors.amber,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(width: 36, child: Text('$count', textAlign: TextAlign.right)),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _BookingStatusChart extends StatelessWidget {
  const _BookingStatusChart({required this.metrics});

  final PerformanceMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final pending = (metrics.totalBookings -
            metrics.confirmedBookings -
            metrics.completedBookings -
            metrics.cancelledBookings)
        .clamp(0, 1 << 30);

    final items = <_StatusBar>[
      _StatusBar('Confirmed', metrics.confirmedBookings, const Color(0xFF22C55E)),
      _StatusBar('Completed', metrics.completedBookings, const Color(0xFF3B82F6)),
      _StatusBar('Pending', pending, const Color(0xFFF59E0B)),
      _StatusBar('Cancelled', metrics.cancelledBookings, const Color(0xFFEF4444)),
    ];
    final maxValue = items.map((b) => b.value).fold<int>(0, (p, v) => v > p ? v : p);

    return _ChartCard(
      title: 'Bookings Performance',
      subtitle: 'Total: ${metrics.totalBookings}',
      child: metrics.totalBookings == 0
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'No bookings yet.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            )
          : SizedBox(
              height: 180,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: items.map((item) {
                  final ratio = maxValue == 0 ? 0.0 : item.value / maxValue;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('${item.value}', style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            height: 12 + ratio * 110,
                            decoration: BoxDecoration(
                              color: item.color,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.label,
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }
}

class _StatusBar {
  const _StatusBar(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
}

class _TopToursChart extends StatelessWidget {
  const _TopToursChart({required this.items});

  final List<TourParticipation> items;

  @override
  Widget build(BuildContext context) {
    final top = items.take(5).toList();
    final maxParticipants = top.map((t) => t.participants).fold<int>(0, (p, v) => v > p ? v : p);

    return _ChartCard(
      title: 'Top Tours by Participation',
      subtitle: 'Bookings vs capacity',
      child: top.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text('No tour data yet.', style: Theme.of(context).textTheme.bodySmall),
              ),
            )
          : Column(
              children: top.map((t) {
                final ratio = maxParticipants == 0 ? 0.0 : t.participants / maxParticipants;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.name,
                              style: Theme.of(context).textTheme.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${t.participants}/${t.capacity}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 8,
                          backgroundColor: Colors.white,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFFF8FBFF),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry, required this.message});

  final VoidCallback onRetry;
  final String message;

  @override
  Widget build(BuildContext context) {
    return SectionPanel(
      title: 'Dashboard Error',
      subtitle: 'Failed to load live data',
      action: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Retry'),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.redAccent),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 460,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniChartCard extends StatelessWidget {
  const _MiniChartCard({
    required this.title,
    required this.points,
    required this.labels,
  });

  final String title;
  final List<int> points;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final rawMax = points.isEmpty
        ? 0
        : points.reduce((a, b) => a > b ? a : b);
    final max = rawMax > 0 ? rawMax.toDouble() : 1.0;
    final allZero = rawMax == 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFFF8FBFF),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          if (points.isEmpty || allZero)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No booking trend data yet.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            )
          else
            SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(points.length, (i) {
                  final value = points[i].toDouble();
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            height: 12 + (value / max * 120),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            i < labels.length ? labels[i] : '',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _CityDemandCard extends StatelessWidget {
  const _CityDemandCard({required this.data});

  final List<CityDemand> data;

  @override
  Widget build(BuildContext context) {
    final maxDemand = data.isEmpty
        ? 1.0
        : data.map((city) => city.demand).reduce((a, b) => a > b ? a : b).toDouble();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFFFFFAF2),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top Requested Cities', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          if (data.isEmpty)
            Text('No city demand data yet.', style: Theme.of(context).textTheme.bodySmall)
          else
            ...data.map((city) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(city.city, style: Theme.of(context).textTheme.bodyMedium),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: city.demand / maxDemand,
                          minHeight: 10,
                          backgroundColor: Colors.white,
                          color: AppColors.amber,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${city.demand}', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _TopGuidesCard extends StatelessWidget {
  const _TopGuidesCard({required this.guides});

  final List<GuideRating> guides;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFFF7F2FF),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top Rated Guides', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          if (guides.isEmpty)
            Text('No guide ratings yet.', style: Theme.of(context).textTheme.bodySmall)
          else
            ...guides.map((guide) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.primary,
                      child: Icon(Icons.person, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(guide.name, style: Theme.of(context).textTheme.bodyMedium),
                    ),
                    const Icon(Icons.star, color: AppColors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      guide.rating.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
