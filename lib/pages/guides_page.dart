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
  bool _isCreatingGuide = false;

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

  Future<void> _deleteGuide(Guide guide) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Guide'),
        content: Text('Delete ${guide.name}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await widget.api.deleteGuide(guide.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${guide.name} deleted.')),
      );
      _reload();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $error')),
      );
    }
  }

  Future<void> _openCreateGuideDialog() async {
    final nameController = TextEditingController();
    final cityController = TextEditingController();
    final languagesController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Create Guide'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Guide Name')),
                    const SizedBox(height: 10),
                    TextField(controller: cityController, decoration: const InputDecoration(labelText: 'City')),
                    const SizedBox(height: 10),
                    TextField(
                      controller: languagesController,
                      decoration: const InputDecoration(labelText: 'Languages (comma separated)'),
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email (optional)')),
                    const SizedBox(height: 10),
                    TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone (optional)')),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Create'),
              ),
            ],
          );
        },
      );

      if (confirmed != true || !mounted) {
        return;
      }

      final name = nameController.text.trim();
      final city = cityController.text.trim();
      final languages = languagesController.text
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();

      if (name.isEmpty || city.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name and city are required.')),
        );
        return;
      }

      setState(() {
        _isCreatingGuide = true;
      });

      await widget.api.createGuide(
        CreateGuideInput(
          name: name,
          city: city,
          languages: languages,
          email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
          phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
        ),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guide created successfully.')),
      );
      _reload();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create guide: $error')),
      );
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isCreatingGuide = false;
      });
      nameController.dispose();
      cityController.dispose();
      languagesController.dispose();
      emailController.dispose();
      phoneController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SectionPanel(
      title: 'All Guides',
      subtitle: 'Manage tour guides and credentials',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            onPressed: _isCreatingGuide ? null : _openCreateGuideDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Guide'),
          ),
          const SizedBox(width: 8),
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
                DataColumn(label: Text('Actions')),
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
                  DataCell(Row(
                    children: [
                      IconButton(onPressed: () {}, icon: const Icon(Icons.visibility_outlined), tooltip: 'Reviews'),
                      IconButton(onPressed: () {}, icon: const Icon(Icons.file_upload_outlined), tooltip: 'Upload Docs'),
                      IconButton(onPressed: () {}, icon: const Icon(Icons.edit_outlined), tooltip: 'Edit'),
                      IconButton(
                        onPressed: () => _deleteGuide(guide),
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        tooltip: 'Delete',
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
