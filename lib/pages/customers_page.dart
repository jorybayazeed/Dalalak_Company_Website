import 'package:flutter/material.dart';

import 'package:dalelak_company/widgets/common_widgets.dart';

class CustomersPage extends StatelessWidget {
  const CustomersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['John Smith', 'USA', '12', 'English', '2026-04-15'],
      ['Sarah Johnson', 'UK', '8', 'English', '2026-04-22'],
      ['Luca Bianchi', 'Italy', '6', 'Italian', '2026-04-18'],
      ['Hana Kim', 'South Korea', '9', 'Korean, English', '2026-04-25'],
    ];

    return SectionPanel(
      title: 'All Customers',
      subtitle: 'Customer history, preferences and communication',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Tourist Name')),
            DataColumn(label: Text('Nationality')),
            DataColumn(label: Text('Bookings')),
            DataColumn(label: Text('Language')),
            DataColumn(label: Text('Last Visit')),
            DataColumn(label: Text('Actions')),
          ],
          rows: rows.map((r) {
            return DataRow(cells: [
              DataCell(Text(r[0])),
              DataCell(Text(r[1])),
              DataCell(Text(r[2])),
              DataCell(Text(r[3])),
              DataCell(Text(r[4])),
              DataCell(Row(
                children: [
                  IconButton(onPressed: () {}, icon: const Icon(Icons.history), tooltip: 'Booking History'),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.tune), tooltip: 'Preferences'),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.chat_outlined), tooltip: 'Contact'),
                ],
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}