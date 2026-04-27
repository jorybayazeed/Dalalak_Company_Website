import 'package:flutter/material.dart';

class AgencyDashboardPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Agency Performance Dashboard'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: <Widget>[
            Text('Performance and satisfaction dashboard based on tourist ratings and participation.'),
            // Add charts and stats for dashboard
          ],
        ),
      ),
    );
  }
}
