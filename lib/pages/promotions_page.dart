import 'package:flutter/material.dart';

import '../data/api_service.dart';
import '../data/models.dart';

class PromotionsPage extends StatefulWidget {
  const PromotionsPage({super.key, required this.api});

  final ApiService api;

  @override
  State<PromotionsPage> createState() => _PromotionsPageState();
}

class _PromotionsPageState extends State<PromotionsPage> {
  List<Reward> _rewards = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rewards = await widget.api.getRewards();
      setState(() {
        _rewards = rewards;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleStatus(Reward reward) async {
    final newStatus = reward.isActive ? 'inactive' : 'active';
    try {
      final updated = await widget.api.setRewardStatus(reward.id, newStatus);
      setState(() {
        final idx = _rewards.indexWhere((r) => r.id == reward.id);
        if (idx != -1) _rewards[idx] = updated;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _delete(Reward reward) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Reward'),
        content: Text('Are you sure you want to delete "${reward.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.api.deleteReward(reward.id);
      setState(() => _rewards.removeWhere((r) => r.id == reward.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _openCreateDialog() {
    _openRewardDialog(null);
  }

  void _openEditDialog(Reward reward) {
    _openRewardDialog(reward);
  }

  void _openRewardDialog(Reward? existing) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final valueCtrl = TextEditingController(text: existing?.value ?? '');
    final minCtrl = TextEditingController(text: (existing?.minimumBookings ?? 0).toString());
    final validCtrl = TextEditingController(text: existing?.validUntil ?? '');
    String type = existing?.type ?? 'discount';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(existing == null ? 'Create Reward' : 'Edit Reward'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Reward Type'),
                  items: const [
                    DropdownMenuItem(value: 'discount', child: Text('Discount')),
                    DropdownMenuItem(value: 'points', child: Text('Points')),
                    DropdownMenuItem(value: 'gift', child: Text('Gift')),
                  ],
                  onChanged: (v) => setDlgState(() => type = v ?? type),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: valueCtrl,
                  decoration: const InputDecoration(labelText: 'Value (e.g. 15%, 100, Souvenir)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: minCtrl,
                  decoration: const InputDecoration(labelText: 'Minimum Bookings'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: validCtrl,
                  decoration: const InputDecoration(labelText: 'Valid Until (YYYY-MM-DD, optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1DB954)),
              onPressed: () async {
                final data = {
                  'title': titleCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'type': type,
                  'value': valueCtrl.text.trim(),
                  'minimumBookings': int.tryParse(minCtrl.text.trim()) ?? 0,
                  'validUntil': validCtrl.text.trim().isEmpty ? null : validCtrl.text.trim(),
                };
                Navigator.pop(ctx);
                try {
                  if (existing == null) {
                    final created = await widget.api.createReward(data);
                    setState(() => _rewards.add(created));
                  } else {
                    final updated = await widget.api.updateReward(existing.id, data);
                    setState(() {
                      final idx = _rewards.indexWhere((r) => r.id == existing.id);
                      if (idx != -1) _rewards[idx] = updated;
                    });
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: Text(existing == null ? 'Create' : 'Save',
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _rewards.length;
    final active = _rewards.where((r) => r.isActive).length;
    final inactive = total - active;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'All Rewards',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: _openCreateDialog,
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text('Create Reward', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE07B00),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Manage rewards and incentives',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Stats row
          Row(
            children: [
              _StatCard(label: 'Total Rewards', value: total, icon: Icons.card_giftcard, iconColor: const Color(0xFFE07B00)),
              const SizedBox(width: 16),
              _StatCard(label: 'Active Rewards', value: active, icon: Icons.check_circle_outline, iconColor: const Color(0xFF1DB954), highlighted: true),
              const SizedBox(width: 16),
              _StatCard(label: 'Inactive Rewards', value: inactive, icon: Icons.cancel_outlined, iconColor: Colors.red),
            ],
          ),
          const SizedBox(height: 24),

          // Grid
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: _rewards.isEmpty
                  ? const Center(child: Text('No rewards yet. Create one!'))
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 520,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.6,
                      ),
                      itemCount: _rewards.length,
                      itemBuilder: (_, i) => _RewardCard(
                        reward: _rewards[i],
                        onToggleStatus: () => _toggleStatus(_rewards[i]),
                        onEdit: () => _openEditDialog(_rewards[i]),
                        onDelete: () => _delete(_rewards[i]),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.highlighted = false,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color iconColor;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: highlighted ? const Color(0xFFE8F8EF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlighted ? const Color(0xFF1DB954) : Colors.grey.shade200,
            width: highlighted ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 8),
                Text('$value',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              ],
            ),
            Icon(icon, size: 36, color: iconColor),
          ],
        ),
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.reward,
    required this.onToggleStatus,
    required this.onEdit,
    required this.onDelete,
  });

  final Reward reward;
  final VoidCallback onToggleStatus;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  IconData get _typeIcon {
    switch (reward.type) {
      case 'points':
        return Icons.emoji_events_outlined;
      case 'gift':
        return Icons.card_giftcard_outlined;
      default:
        return Icons.attach_money;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = reward.isActive;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? const Color(0xFF1DB954) : Colors.grey.shade300,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + badge
          Row(
            children: [
              Expanded(
                child: Text(
                  reward.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFE8F8EF) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive ? const Color(0xFF1DB954) : Colors.grey.shade400,
                  ),
                ),
                child: Text(
                  isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 12,
                    color: isActive ? const Color(0xFF1DB954) : Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(reward.description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          // Type + Value row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reward Type',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(_typeIcon, size: 14, color: Colors.grey.shade700),
                        const SizedBox(width: 4),
                        Text(
                          reward.type[0].toUpperCase() + reward.type.substring(1),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Value',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    const SizedBox(height: 2),
                    Text(reward.value,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Min bookings + Valid until
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Minimum Bookings',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    const SizedBox(height: 2),
                    Text('${reward.minimumBookings}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ),
              if (reward.validUntil != null)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Valid Until',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      const SizedBox(height: 2),
                      Text(reward.validUntil!,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ),
            ],
          ),
          const Spacer(),
          // Actions
          Row(
            children: [
              TextButton.icon(
                onPressed: onToggleStatus,
                icon: Icon(
                  isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                  size: 16,
                  color: Colors.red,
                ),
                label: Text(
                  isActive ? 'Deactivate' : 'Activate',
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
              ),
              const Spacer(),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: Colors.grey.shade700,
                tooltip: 'Edit',
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
                color: Colors.red,
                tooltip: 'Delete',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
