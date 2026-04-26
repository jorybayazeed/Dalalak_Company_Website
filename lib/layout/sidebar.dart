import 'package:flutter/material.dart';

import '../app.dart';
import '../theme/app_theme.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.activeSection,
    required this.onSelect,
    required this.onLogout,
  });

  final AppSection activeSection;
  final ValueChanged<AppSection> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final items = <({AppSection section, String title, IconData icon})>[
      (section: AppSection.dashboard, title: 'Dashboard', icon: Icons.grid_view_rounded),
      (section: AppSection.tours, title: 'Tours', icon: Icons.location_on_outlined),
      (section: AppSection.guides, title: 'Guides', icon: Icons.groups_2_outlined),
      (section: AppSection.bookings, title: 'Bookings', icon: Icons.calendar_month_outlined),
      (section: AppSection.customers, title: 'Customers', icon: Icons.person_outline_rounded),
      (section: AppSection.translation, title: 'Live Translation', icon: Icons.translate_rounded),
      (section: AppSection.reports, title: 'Reports', icon: Icons.show_chart_rounded),
      (section: AppSection.reviews, title: 'Reviews', icon: Icons.star_outline_rounded),
      (section: AppSection.settings, title: 'Settings', icon: Icons.settings_outlined),
      (section: AppSection.notifications, title: 'Notifications', icon: Icons.notifications_none_rounded),
    ];

    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: const Color(0xFFDAF5EA),
                  ),
                  child: const Icon(Icons.travel_explore, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dalelak', style: Theme.of(context).textTheme.titleMedium),
                    Text('Company Portal', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 20),
              itemBuilder: (_, index) {
                final item = items[index];
                final selected = activeSection == item.section;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      item.icon,
                      color: selected ? Colors.white : const Color(0xFF334155),
                    ),
                    title: Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: selected ? Colors.white : const Color(0xFF334155),
                          ),
                    ),
                    onTap: () => onSelect(item.section),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemCount: items.length,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              children: [
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.language),
                  label: const Text('العربية'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout, color: Colors.redAccent),
                  label: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
