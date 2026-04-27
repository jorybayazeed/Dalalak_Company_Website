import 'package:flutter/material.dart';

import 'package:dalalak_company_website/widgets/common_widgets.dart';

class LiveTranslationPage extends StatelessWidget {
  const LiveTranslationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionPanel(
      title: 'Live Translation',
      subtitle: 'Select guide and tourist language then start live translation',      child: Column(
        children: [
          const _Selector(label: 'Guide', options: ['Ahmed Al-Mansour', 'Fatima Al-Zahrani', 'Mona Al-Harbi']),
          const SizedBox(height: 12),
          const _Selector(label: 'Tourist Language', options: ['English', 'French', 'Spanish', 'German', 'Chinese']),
          const SizedBox(height: 12),
          const _Selector(label: 'Guide Language', options: ['Arabic', 'English', 'French']),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.mic),
              label: const Text('Start Live Translation Session'),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF3FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Realtime transcript preview appears here...'),
          ),
        ],
      ),
    );
  }
}

class _Selector extends StatelessWidget {
  const _Selector({required this.label, required this.options});

  final String label;
  final List<String> options;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: options.first,
      decoration: InputDecoration(labelText: label),
      items: options.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: (_) {},
    );
  }
}