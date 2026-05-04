import 'package:flutter/material.dart';

import '../data/api_service.dart';
import '../data/models.dart';
import 'package:dalalak_company_website/widgets/common_widgets.dart';

class GuidesPage extends StatefulWidget {
  const GuidesPage({
    super.key,
    required this.api,
  });

  final ApiService api;

  @override
  State<GuidesPage> createState() => _GuidesPageState();
}

class _GuidesPageState extends State<GuidesPage> {
  late Future<List<Guide>> _guidesFuture;

  @override
  void initState() {
    super.initState();
    _guidesFuture = widget.api.getGuides();
  }

  void _reload() {
    setState(() {
      _guidesFuture = widget.api.getGuides();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SectionPanel(
      title: 'All Guides',
      subtitle: 'Read-only list from app Firebase guides',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
      child: FutureBuilder<List<Guide>>(
        future: _guidesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return Text(
              'Failed to load guides: ${snapshot.error}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.redAccent),
            );
          }

          final rows = snapshot.data ?? const <Guide>[];
          if (rows.isEmpty) {
            return Text('No guides found.', style: Theme.of(context).textTheme.bodyMedium);
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Guide Name')),
                DataColumn(label: Text('Languages')),
                DataColumn(label: Text('City')),
                DataColumn(label: Text('Rating')),
                DataColumn(label: Text('Total Tours')),
                DataColumn(label: Text('Status')),
              ],
              rows: rows.map((guide) {
                final available = guide.status == 'Available';
                return DataRow(cells: [
                  DataCell(Text(guide.name)),
                  DataCell(Text(guide.languagesText)),
                  DataCell(Text(guide.city)),
                  DataCell(Row(
                    children: [
                      const Icon(Icons.star, size: 14, color: Colors.orange),
                      Text(' ${guide.rating.toStringAsFixed(1)}'),
                    ],
                  )),
                  DataCell(Text('${guide.totalTours}')),
                  DataCell(InfoBadge(text: guide.status, color: available ? Colors.green : Colors.redAccent)),
                ]);
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}
