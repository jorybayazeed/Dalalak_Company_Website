import 'package:flutter/material.dart';

import '../data/api_service.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import 'package:dalalak_company_website/widgets/common_widgets.dart';

class ToursPage extends StatefulWidget {
  const ToursPage({
    super.key,
    required this.api,
    required this.onCreateTour,
  });

  final ApiService api;
  final VoidCallback onCreateTour;

  @override
  State<ToursPage> createState() => _ToursPageState();
}

class _ToursPageState extends State<ToursPage> {
  late Future<List<Tour>> _toursFuture;

  @override
  void initState() {
    super.initState();
    _toursFuture = widget.api.getTours();
  }

  void _reload() {
    setState(() {
      _toursFuture = widget.api.getTours();
    });
  }

  Future<void> _deleteTour(Tour tour) async {
    try {
      await widget.api.deleteTour(tour.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tour.name} deleted.')),
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

  Future<void> _showParticipants(Tour tour) async {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Participants - ${tour.name}'),
          content: SizedBox(
            width: 560,
            child: FutureBuilder<List<TourParticipant>>(
              future: widget.api.getTourParticipants(tour.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Text('Failed to load participants: ${snapshot.error}');
                }

                final rows = snapshot.data ?? const <TourParticipant>[];
                if (rows.isEmpty) {
                  return const Text('No real bookings yet for this tour.');
                }

                return SingleChildScrollView(
                  child: Column(
                    children: rows
                        .map(
                          (item) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.person_outline),
                            title: Text(item.touristName),
                            subtitle: Text('Participants: ${item.participants} | Status: ${item.status}'),
                            trailing: Text(item.totalPriceText),
                          ),
                        )
                        .toList(),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditDialog(Tour tour) async {
    final nameController = TextEditingController(text: tour.name);
    final cityController = TextEditingController(text: tour.city);
    final priceController = TextEditingController(text: '${tour.price}');
    final dateController = TextEditingController(text: tour.date);
    final capacityController = TextEditingController(text: '${tour.capacity}');
    final durationController = TextEditingController(text: tour.duration);
    final descriptionController = TextEditingController(text: tour.description);
    final mapLocationController = TextEditingController(text: tour.mapLocation);

    try {
      final guides = await widget.api.getGuides();
      if (!mounted) {
        return;
      }

      String? selectedGuideId;
      final matched = guides.where((g) => g.name == tour.guide).toList();
      if (matched.isNotEmpty) {
        selectedGuideId = matched.first.id;
      } else if (guides.isNotEmpty) {
        selectedGuideId = guides.first.id;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setInnerState) {
              return AlertDialog(
                title: const Text('Edit Tour'),
                content: SizedBox(
                  width: 620,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _EditField(label: 'Tour Name', controller: nameController),
                        const SizedBox(height: 10),
                        _EditField(label: 'City', controller: cityController),
                        const SizedBox(height: 10),
                        _EditField(label: 'Price', controller: priceController),
                        const SizedBox(height: 10),
                        _EditField(label: 'Date (YYYY-MM-DD)', controller: dateController),
                        const SizedBox(height: 10),
                        _EditField(label: 'Capacity', controller: capacityController),
                        const SizedBox(height: 10),
                        _EditField(label: 'Duration', controller: durationController),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: selectedGuideId,
                          items: guides
                              .map(
                                (g) => DropdownMenuItem<String>(
                                  value: g.id,
                                  child: Text(g.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setInnerState(() => selectedGuideId = value),
                          decoration: const InputDecoration(labelText: 'Guide'),
                        ),
                        const SizedBox(height: 10),
                        _EditField(label: 'Map Location', controller: mapLocationController),
                        const SizedBox(height: 10),
                        _EditField(label: 'Description', controller: descriptionController, lines: 3),
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
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (confirmed != true || !mounted) {
        return;
      }

      final selectedGuide = guides.where((g) => g.id == selectedGuideId).toList();
      final guide = selectedGuide.isNotEmpty ? selectedGuide.first : null;
      if (guide == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a guide.')),
        );
        return;
      }

      final input = CreateTourInput(
        name: nameController.text.trim(),
        city: cityController.text.trim(),
        price: int.tryParse(priceController.text.trim()) ?? 0,
        date: dateController.text.trim(),
        guide: guide.name,
        guideId: guide.id,
        capacity: int.tryParse(capacityController.text.trim()) ?? 0,
        duration: durationController.text.trim(),
        description: descriptionController.text.trim(),
        mapLocation: mapLocationController.text.trim(),
        images: tour.images,
      );

      await widget.api.updateTour(tour.id, input);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tour updated successfully.')),
      );
      _reload();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to edit tour: $error')),
      );
    } finally {
      nameController.dispose();
      cityController.dispose();
      priceController.dispose();
      dateController.dispose();
      capacityController.dispose();
      durationController.dispose();
      descriptionController.dispose();
      mapLocationController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SectionPanel(
      title: 'All Tours',
      subtitle: 'Manage all tour packages',
      action: Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
          FilledButton.icon(
            onPressed: widget.onCreateTour,
            icon: const Icon(Icons.add),
            label: const Text('Create New Tour'),
          ),
        ],
      ),
      child: FutureBuilder<List<Tour>>(
        future: _toursFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return Text(
              'Failed to load tours: ${snapshot.error}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.redAccent),
            );
          }

          final tours = snapshot.data ?? const <Tour>[];
          if (tours.isEmpty) {
            return Text('No tours found. Create your first tour.', style: Theme.of(context).textTheme.bodyMedium);
          }

          return Column(
            children: tours.map((tour) {
              final status = tour.status;
              final color = status == 'Active'
                  ? Colors.green
                  : status == 'Completed'
                      ? Colors.blue
                      : Colors.redAccent;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                  color: Colors.white,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(tour.name, style: Theme.of(context).textTheme.titleMedium),
                              InfoBadge(text: status, color: color),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            showDialog<void>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(tour.name),
                                content: SizedBox(
                                  width: 520,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Company: ${tour.companyName.isEmpty ? 'Your Company' : tour.companyName}'),
                                      const SizedBox(height: 6),
                                      Text('Guide: ${tour.guide}'),
                                      const SizedBox(height: 6),
                                      Text('City: ${tour.city}'),
                                      const SizedBox(height: 6),
                                      Text('Date: ${tour.date}'),
                                      const SizedBox(height: 6),
                                      Text('Duration: ${tour.duration}'),
                                      const SizedBox(height: 6),
                                      Text('Price: ${tour.priceText}'),
                                      const SizedBox(height: 6),
                                      Text('Participants: ${tour.participantsText}'),
                                      const SizedBox(height: 10),
                                      Text(tour.description.isEmpty ? 'No description.' : tour.description),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: const Icon(Icons.visibility_outlined),
                          tooltip: 'Details',
                        ),
                        IconButton(
                          onPressed: () => _showParticipants(tour),
                          icon: const Icon(Icons.groups_2_outlined),
                          tooltip: 'Participants',
                        ),
                        IconButton(
                          onPressed: () => _showEditDialog(tour),
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          onPressed: () => _deleteTour(tour),
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 20,
                      runSpacing: 8,
                      children: [
                        _Meta(label: 'City', value: tour.city),
                        _Meta(label: 'Price', value: tour.priceText),
                        _Meta(label: 'Date', value: tour.date),
                        _Meta(label: 'Guide', value: tour.guide),
                        _Meta(label: 'Participants', value: tour.participantsText),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  const _EditField({
    required this.label,
    required this.controller,
    this.lines = 1,
  });

  final String label;
  final TextEditingController controller;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: lines,
      decoration: InputDecoration(labelText: label),
    );
  }
}
