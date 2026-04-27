import 'package:flutter/material.dart';

import '../data/api_service.dart';
import '../data/models.dart';
import 'package:dalalak_company_website/widgets/common_widgets.dart';

class BookingsPage extends StatefulWidget {
  const BookingsPage({
    super.key,
    required this.api,
  });

  final ApiService api;

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  late Future<List<Booking>> _bookingsFuture;

  @override
  void initState() {
    super.initState();
    _bookingsFuture = widget.api.getBookings();
  }

  void _reload() {
    setState(() {
      _bookingsFuture = widget.api.getBookings();
    });
  }

  Future<void> _updateStatus(Booking booking, String status) async {
    try {
      await widget.api.updateBookingStatus(bookingId: booking.id, status: status);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking updated to $status.')),
      );
      _reload();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $error')),
      );
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return SectionPanel(
      title: 'All Bookings',
      subtitle: 'Review, confirm, or cancel bookings',
      action: OutlinedButton.icon(
        onPressed: _reload,
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh'),
      ),
      child: FutureBuilder<List<Booking>>(
        future: _bookingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return Text(
              'Failed to load bookings: ${snapshot.error}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.redAccent),
            );
          }

          final bookings = snapshot.data ?? const <Booking>[];
          if (bookings.isEmpty) {
            return Text('No bookings found.', style: Theme.of(context).textTheme.bodyMedium);
          }

          return SingleChildScrollView(
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
              rows: bookings.map((booking) {
                return DataRow(cells: [
                  DataCell(Text(booking.touristName)),
                  DataCell(Text(booking.tourName)),
                  DataCell(Text('${booking.participants}')),
                  DataCell(Text(booking.totalPriceText)),
                  DataCell(InfoBadge(text: booking.status, color: statusColor(booking.status))),
                  DataCell(Row(
                    children: [
                      IconButton(
                        onPressed: booking.status == 'Confirmed'
                            ? null
                            : () => _updateStatus(booking, 'Confirmed'),
                        icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                        tooltip: 'Confirm',
                      ),
                      IconButton(
                        onPressed: booking.status == 'Cancelled'
                            ? null
                            : () => _updateStatus(booking, 'Cancelled'),
                        icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                        tooltip: 'Cancel',
                      ),
                      IconButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Booking #${booking.id}\nTour: ${booking.tourName}\nParticipants: ${booking.participants}',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.visibility_outlined),
                        tooltip: 'View',
                      ),
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
