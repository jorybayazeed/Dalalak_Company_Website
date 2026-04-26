import 'package:flutter/material.dart';

import '../widgets/common_widgets.dart';

class GuidesPage extends StatelessWidget {
  const GuidesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['Ahmed Al-Mansour', 'Arabic, English', 'Riyadh', '4.8', '156', 'Available'],
      ['Fatima Al-Zahrani', 'Arabic, English, French', 'AlUla', '4.9', '203', 'Busy'],
      ['Mona Al-Harbi', 'Arabic, English', 'Jeddah', '4.6', '97', 'Available'],
    ];

    return SectionPanel(
      title: 'All Guides',
      subtitle: 'Manage tour guides and credentials',
      action: FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.add), label: const Text('Add Guide')),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Guide Name')),
            DataColumn(label: Text('Languages')),
            DataColumn(label: Text('City')),
            DataColumn(label: Text('Rating')),
            DataColumn(label: Text('Total Tours')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: rows.map((r) {
            final available = r[5] == 'Available';
            return DataRow(cells: [
              DataCell(Text(r[0])),
              DataCell(Text(r[1])),
              DataCell(Text(r[2])),
              DataCell(Row(children: [const Icon(Icons.star, size: 14, color: Colors.orange), Text(' ${r[3]}')])),
              DataCell(Text(r[4])),
              DataCell(InfoBadge(text: r[5], color: available ? Colors.green : Colors.redAccent)),
              DataCell(Row(
                children: [
                  IconButton(onPressed: () {}, icon: const Icon(Icons.visibility_outlined), tooltip: 'Reviews'),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.file_upload_outlined), tooltip: 'Upload Docs'),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.edit_outlined), tooltip: 'Edit'),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.delete_outline, color: Colors.redAccent), tooltip: 'Delete'),
                ],
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}
