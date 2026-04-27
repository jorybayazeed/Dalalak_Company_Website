import 'package:flutter/material.dart';

import '../data/api_service.dart';
import '../data/models.dart';
import 'package:dalalak_company_website/widgets/common_widgets.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({
    super.key,
    required this.api,
  });

  final ApiService api;

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  late Future<List<Customer>> _customersFuture;

  @override
  void initState() {
    super.initState();
    _customersFuture = widget.api.getCustomers();
  }

  void _reload() {
    setState(() {
      _customersFuture = widget.api.getCustomers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SectionPanel(
      title: 'All Customers',
      subtitle: 'Customer history, preferences and communication',
      action: OutlinedButton.icon(
        onPressed: _reload,
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh'),
      ),
      child: FutureBuilder<List<Customer>>(
        future: _customersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return Text(
              'Failed to load customers: ${snapshot.error}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.redAccent),
            );
          }

          final rows = snapshot.data ?? const <Customer>[];
          if (rows.isEmpty) {
            return Text('No customers found.', style: Theme.of(context).textTheme.bodyMedium);
          }

          return SingleChildScrollView(
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
              rows: rows.map((customer) {
                return DataRow(cells: [
                  DataCell(Text(customer.name)),
                  DataCell(Text(customer.nationality)),
                  DataCell(Text('${customer.bookings}')),
                  DataCell(Text(customer.language)),
                  DataCell(Text(customer.lastVisit)),
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
          );
        },
      ),
    );
  }
}
