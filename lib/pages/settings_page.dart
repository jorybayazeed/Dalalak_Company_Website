import 'package:flutter/material.dart';

import 'package:dalelak_company/widgets/common_widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionPanel(
          title: 'Company Information',
          subtitle: 'Update company profile and contact details',
          action: FilledButton(onPressed: () {}, child: const Text('Save Changes')),
          child: const Column(
            children: [
              Row(children: [Expanded(child: _Field(label: 'Company Name', hint: 'Saudi Heritage Tours')), SizedBox(width: 12), Expanded(child: _Field(label: 'Email', hint: 'info@saudiheritage.com'))]),
              SizedBox(height: 12),
              Row(children: [Expanded(child: _Field(label: 'Phone', hint: '+966501234567')), SizedBox(width: 12), Expanded(child: _Field(label: 'City', hint: 'Riyadh'))]),
              SizedBox(height: 12),
              _Field(label: 'Description', hint: 'Leading tourism company in Saudi Arabia', lines: 3),
              SizedBox(height: 12),
              _Field(label: 'Logo URL', hint: 'https://...'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionPanel(
          title: 'Working Hours',
          subtitle: 'Set your business schedule',
          action: FilledButton(onPressed: () {}, child: const Text('Save Changes')),
          child: const Row(
            children: [
              Expanded(child: _Field(label: 'Opening Time', hint: '08:00 AM')),
              SizedBox(width: 12),
              Expanded(child: _Field(label: 'Closing Time', hint: '06:00 PM')),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionPanel(
          title: 'Payment Methods',
          subtitle: 'Manage enabled payment options',
          child: const Column(
            children: [
              _PaymentItem(title: 'Mada', sub: 'Local debit cards', active: true),
              SizedBox(height: 10),
              _PaymentItem(title: 'STC Pay', sub: 'Digital wallet', active: true),
              SizedBox(height: 10),
              _PaymentItem(title: 'Apple Pay', sub: 'Apple wallet', active: true),
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
        TextField(maxLines: lines, decoration: InputDecoration(hintText: hint)),      ],
    );
  }
}

class _PaymentItem extends StatelessWidget {
  const _PaymentItem({required this.title, required this.sub, required this.active});

  final String title;
  final String sub;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFF8FAFC),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFF2E6EF7),
            ),
            child: const Icon(Icons.attach_money, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                Text(sub, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Switch(value: active, onChanged: (_) {}),
        ],
      ),
    );
  }
}