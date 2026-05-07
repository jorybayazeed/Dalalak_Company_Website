import 'package:flutter/material.dart';

class AssignTourGuidePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Assign Tour Guides'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: <Widget>[
            Text('Assign tour guides to packages and define their roles/availability.'),
            // Add UI for assigning tour guides
          ],
        ),
      ),
    );
  }
}
