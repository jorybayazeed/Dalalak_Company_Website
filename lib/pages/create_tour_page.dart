import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

import '../data/api_service.dart';
import '../data/models.dart';
import 'package:dalalak_company_website/widgets/common_widgets.dart';

class CreateTourPage extends StatefulWidget {
  const CreateTourPage({
    super.key,
    required this.api,
    required this.onCreated,
  });

  final ApiService api;
  final VoidCallback onCreated;

  @override
  State<CreateTourPage> createState() => _CreateTourPageState();
}

class _CreateTourPageState extends State<CreateTourPage> {
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _priceController = TextEditingController();
  final _dateController = TextEditingController();
  final _capacityController = TextEditingController();
  final _durationController = TextEditingController();
  final _mapLocationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imagesController = TextEditingController();

  final List<String> _regions = const ['Riyadh', 'Jeddah', 'AlUla', 'Makkah', 'Madinah', 'Dammam'];
  final List<String> _categories = const ['Cultural', 'Adventure', 'Religious', 'Nature'];

  List<Guide> _guides = const [];
  String? _selectedGuideId;
  String? _selectedRegion;
  String? _selectedCategory;
  bool _isLoadingGuides = false;
  bool _isSaving = false;
  
  late MapController _mapController;
  LatLng? _selectedMapLocation;
  bool _showMapPicker = false;

  @override
  void initState() {
    super.initState();
    _dateController.text = '2026-06-15';
    _mapController = MapController();
    // Default to Riyadh coordinates
    _selectedMapLocation = LatLng(24.7136, 46.6753);
    _mapLocationController.text = '24.7136, 46.6753';
    _loadGuides();
  }

  Future<void> _loadGuides() async {
    setState(() {
      _isLoadingGuides = true;
    });

    try {
      final rows = await widget.api.getGuides();
      if (!mounted) {
        return;
      }

      setState(() {
        _guides = rows;
        if (rows.isNotEmpty) {
          final exists = rows.any((guide) => guide.id == _selectedGuideId);
          _selectedGuideId = exists ? _selectedGuideId : rows.first.id;
        } else {
          _selectedGuideId = null;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load guides from the system.')),
      );
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingGuides = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _priceController.dispose();
    _dateController.dispose();
    _capacityController.dispose();
    _durationController.dispose();
    _mapLocationController.dispose();
    _descriptionController.dispose();
    _imagesController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _createTour() async {
    final name = _nameController.text.trim();
    final city = _cityController.text.trim();
    final duration = _durationController.text.trim();
    final date = _dateController.text.trim();
    final mapLocation = _mapLocationController.text.trim();
    final description = _descriptionController.text.trim();
    final price = int.tryParse(_priceController.text.trim());
    final capacity = int.tryParse(_capacityController.text.trim());
    Guide? guide;
    for (final item in _guides) {
      if (item.id == _selectedGuideId) {
        guide = item;
        break;
      }
    }

    if (name.isEmpty || city.isEmpty || duration.isEmpty || date.isEmpty || guide == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields.')),
      );
      return;
    }

    if (price == null || capacity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Price and capacity must be numbers.')),
      );
      return;
    }

    final images = _imagesController.text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.api.createTour(
        CreateTourInput(
          name: name,
          city: city,
          price: price,
          date: date,
          guide: guide.name,
          guideId: guide.id,
          capacity: capacity,
          duration: duration,
          description: description,
          mapLocation: mapLocation,
          images: images,
        ),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tour created successfully.')),
      );
      widget.onCreated();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create tour: $error')),
      );
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionPanel(
          title: 'Create New Tour',
          subtitle: 'Set package details, guide, and smart recommendations',
          action: OutlinedButton.icon(
            onPressed: _isLoadingGuides ? null : _loadGuides,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh Guides'),
          ),
          child: Column(
            children: [
              if (_guides.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: const Text(
                    'No guides found. Please create a guide first from the Guides page.',
                  ),
                ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final twoCols = constraints.maxWidth > 980;
                  if (!twoCols) {
                    return Column(
                      children: [
                        _Field(label: 'Tour Name', controller: _nameController, hint: 'Riyadh Heritage Tour'),
                        const SizedBox(height: 12),
                        _DropdownField(
                          label: 'Region',
                          value: _selectedRegion,
                          items: _regions,
                          hint: 'Select region',
                          onChanged: (value) => setState(() => _selectedRegion = value),
                        ),
                        const SizedBox(height: 12),
                        _Field(label: 'City', controller: _cityController, hint: 'Riyadh'),
                        const SizedBox(height: 12),
                        _Field(label: 'Price (SAR)', controller: _priceController, hint: '450'),
                        const SizedBox(height: 12),
                        _DropdownField(
                          label: 'Category',
                          value: _selectedCategory,
                          items: _categories,
                          hint: 'Select category',
                          onChanged: (value) => setState(() => _selectedCategory = value),
                        ),
                        const SizedBox(height: 12),
                        _Field(label: 'Date (YYYY-MM-DD)', controller: _dateController, hint: '2026-06-15'),
                        const SizedBox(height: 12),
                        _Field(label: 'Participants Capacity', controller: _capacityController, hint: '20'),
                        const SizedBox(height: 12),
                        _Field(label: 'Duration', controller: _durationController, hint: '6 hours'),
                        const SizedBox(height: 12),
                        _DropdownField(
                          label: 'Guide',
                          value: _selectedGuideId,
                          items: _guides.map((guide) => guide.id).toList(),
                          hint: _isLoadingGuides ? 'Loading guides...' : 'Select guide',
                          itemLabelBuilder: (id) {
                            final guide = _guides.firstWhere((item) => item.id == id);
                            return guide.name;
                          },
                          onChanged: _guides.isEmpty
                              ? null
                              : (value) => setState(() => _selectedGuideId = value),
                        ),
                        const SizedBox(height: 12),
                        _Field(
                          label: 'Map Location',
                          controller: _mapLocationController,
                          hint: '24.7136, 46.6753',
                          readOnly: true,
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _Field(
                              label: 'Tour Name',
                              controller: _nameController,
                              hint: 'Riyadh Heritage Tour',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DropdownField(
                              label: 'Region',
                              value: _selectedRegion,
                              items: _regions,
                              hint: 'Select region',
                              onChanged: (value) => setState(() => _selectedRegion = value),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _Field(label: 'City', controller: _cityController, hint: 'Riyadh'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Field(label: 'Price (SAR)', controller: _priceController, hint: '450'),
                          ),
                          Expanded(
                            child: _DropdownField(
                              label: 'Category',
                              value: _selectedCategory,
                              items: _categories,
                              hint: 'Select category',
                              onChanged: (value) => setState(() => _selectedCategory = value),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _Field(label: 'Date (YYYY-MM-DD)', controller: _dateController, hint: '2026-06-15'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Field(label: 'Duration', controller: _durationController, hint: '6 hours'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _DropdownField(
                              label: 'Guide',
                              value: _selectedGuideId,
                              items: _guides.map((guide) => guide.id).toList(),
                              hint: _isLoadingGuides ? 'Loading guides...' : 'Select guide',
                              itemLabelBuilder: (id) {
                                final guide = _guides.firstWhere((item) => item.id == id);
                                return guide.name;
                              },
                              onChanged: _guides.isEmpty
                                  ? null
                                  : (value) => setState(() => _selectedGuideId = value),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Field(label: 'Participants Capacity', controller: _capacityController, hint: '20'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _Field(
                              label: 'Map Location',
                              controller: _mapLocationController,
                              hint: '24.7136, 46.6753',
                              readOnly: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(child: SizedBox()),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Icon(Icons.map_outlined),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Map Location Picker',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Click on the map to select tour location coordinates',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        height: 300,
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            center: _selectedMapLocation ?? LatLng(24.7136, 46.6753),
                            zoom: 13.0,
                            interactiveFlags: InteractiveFlag.all,
                            onTap: (tapPosition, point) {
                              setState(() {
                                _selectedMapLocation = point;
                                _mapLocationController.text = '${point.latitude}, ${point.longitude}';
                              });
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                              subdomains: const ['a', 'b', 'c'],
                            ),
                            MarkerLayer(
                              markers: _selectedMapLocation != null
                                  ? [
                                      Marker(
                                        point: _selectedMapLocation!,
                                        width: 40,
                                        height: 40,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(50),
                                            border: Border.all(color: Colors.white, width: 2),
                                          ),
                                          child: const Icon(Icons.location_on, color: Colors.white, size: 20),
                                        ),
                                      )
                                    ]
                                  : [],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Coordinates: $_selectedMapLocation → Saved as: ${_mapLocationController.text}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              _Field(
                label: 'Tour Description',
                controller: _descriptionController,
                hint: 'Describe route, attractions, and included services',
                lines: 4,
              ),
              const SizedBox(height: 12),
              _Field(
                label: 'Tour Images',
                controller: _imagesController,
                hint: 'Comma-separated image URLs',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (_isSaving || _guides.isEmpty) ? null : _createTour,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_isSaving ? 'Creating...' : 'Create Tour'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionPanel(
          title: 'Smart Features',
          subtitle: 'Weather insights and suitable time recommendations',
          child: const Column(
            children: [
              _SmartHint(
                icon: Icons.cloud_outlined,
                title: 'Expected Weather',
                desc: 'Sunny, 33°C, wind 12 km/h on selected date.',
              ),
              SizedBox(height: 10),
              _SmartHint(
                icon: Icons.schedule,
                title: 'Suggested Time',
                desc: 'Best start time is 4:30 PM for lower heat and better visibility.',
              ),
              SizedBox(height: 10),
              _SmartHint(
                icon: Icons.warning_amber_rounded,
                title: 'High Temperature Alert',
                desc: 'Temperature may exceed 40°C between 12 PM and 3 PM.',
                danger: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.lines = 1,
    this.readOnly = false,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final int lines;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: lines,
          readOnly: readOnly,
          decoration: InputDecoration(
            hintText: hint,
            filled: readOnly,
            fillColor: readOnly ? const Color(0xFFF5F5F5) : null,
          ),
        ),
      ],
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.hint,
    required this.onChanged,
    this.itemLabelBuilder,
  });

  final String label;
  final String? value;
  final List<String> items;
  final String hint;
  final ValueChanged<String?>? onChanged;
  final String Function(String)? itemLabelBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value != null && items.contains(value) ? value : null,
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(itemLabelBuilder?.call(item) ?? item),
                ),
              )
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}

class _SmartHint extends StatelessWidget {
  const _SmartHint({
    required this.icon,
    required this.title,
    required this.desc,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String desc;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.redAccent : Colors.green;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(desc, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
