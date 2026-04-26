import 'package:flutter/material.dart';

import '../widgets/common_widgets.dart';

class BookingsPage extends StatelessWidget {
  const BookingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['John Smith', 'Riyadh Heritage Tour', '3', '1350 SAR', 'Confirmed'],
      ['Sarah Johnson', 'AlUla Desert Adventure', '2', '1700 SAR', 'Pending'],
      ['Mark Evan', 'Jeddah Coast Discovery', '1', '510 SAR', 'Cancelled'],
      ['Nora Ali', 'Taif Mountains Escape', '4', '2200 SAR', 'Completed'],
    ];

    Color statusColor(String status) {
      switch (status) {
        case 'Confirmed':
          return Colors.green;
        case 'Pending':
          return Colors.orange;
        case 'Cancelled':
          return Colors.redAccent;
        default:
          return Colors.blue;
      }
    }

    return SectionPanel(
      title: 'All Bookings',
      subtitle: 'Review, confirm, or cancel bookings',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Tourist Name')),
            DataColumn(label: Text('Tour')),
            DataColumn(label: Text('Participants')),
            DataColumn(label: Text('Total Price')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: rows.map((r) {
            return DataRow(cells: [
              DataCell(Text(r[0])),
              DataCell(Text(r[1])),
              DataCell(Text(r[2])),
              DataCell(Text(r[3])),
              DataCell(InfoBadge(text: r[4], color: statusColor(r[4]))),
              DataCell(Row(
                children: [
                  IconButton(onPressed: () {}, icon: const Icon(Icons.check_circle_outline, color: Colors.green), tooltip: 'Confirm'),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent), tooltip: 'Cancel'),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.visibility_outlined), tooltip: 'View'),
                ],
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}
