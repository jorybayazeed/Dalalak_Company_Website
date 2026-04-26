import 'package:flutter/material.dart';

import '../widgets/common_widgets.dart';

class CreateTourPage extends StatelessWidget {
  const CreateTourPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionPanel(
          title: 'Create New Tour',
          subtitle: 'Set package details, guide, and smart recommendations',
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final twoCols = constraints.maxWidth > 980;
                  if (!twoCols) {
                    return const Column(
                      children: [
                        _Field(label: 'Tour Name', hint: 'Riyadh Heritage Tour'),
                        SizedBox(height: 12),
                        _Field(label: 'City', hint: 'Riyadh'),
                        SizedBox(height: 12),
                        _Field(label: 'Price (SAR)', hint: '450'),
                        SizedBox(height: 12),
                        _Field(label: 'Date', hint: '2026-06-15'),
                        SizedBox(height: 12),
                        _Field(label: 'Participants Capacity', hint: '20'),
                        SizedBox(height: 12),
                        _Field(label: 'Duration', hint: '6 hours'),
                        SizedBox(height: 12),
                        _Field(label: 'Guide', hint: 'Ahmed Al-Mansour'),
                        SizedBox(height: 12),
                        _Field(label: 'Map Location', hint: '24.7136, 46.6753'),
                      ],
                    );
                  }

                  return const Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _Field(label: 'Tour Name', hint: 'Riyadh Heritage Tour')),
                          SizedBox(width: 12),
                          Expanded(child: _Field(label: 'City', hint: 'Riyadh')),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _Field(label: 'Price (SAR)', hint: '450')),
                          SizedBox(width: 12),
                          Expanded(child: _Field(label: 'Date', hint: '2026-06-15')),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _Field(label: 'Participants Capacity', hint: '20')),
                          SizedBox(width: 12),
                          Expanded(child: _Field(label: 'Duration', hint: '6 hours')),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _Field(label: 'Guide', hint: 'Ahmed Al-Mansour')),
                          SizedBox(width: 12),
                          Expanded(child: _Field(label: 'Map Location', hint: '24.7136, 46.6753')),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              const _Field(label: 'Tour Description', hint: 'Describe route, attractions, and included services', lines: 4),
              const SizedBox(height: 12),
              const _Field(label: 'Tour Images', hint: 'Paste image URLs or upload files placeholder'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Create Tour'),
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
  const _Field({required this.label, required this.hint, this.lines = 1});

  final String label;
  final String hint;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        TextField(
          maxLines: lines,
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
        color: color.withOpacity(0.08),
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
