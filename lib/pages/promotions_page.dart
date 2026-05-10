import 'package:flutter/material.dart';

import '../data/api_service.dart';
import '../data/models.dart';

const List<String> _levelNames = [
  'Starter',
  'Explorer',
  'Traveler',
  'Adventurer',
  'Guide',
  'Expert',
  'Master',
];

String _levelLabel(int level) {
  final i = level - 1;
  if (i < 0 || i >= _levelNames.length) return 'Level $level';
  return 'Level $level - ${_levelNames[i]}';
}

class PromotionsPage extends StatefulWidget {
  const PromotionsPage({super.key, required this.api});

  final ApiService api;

  @override
  State<PromotionsPage> createState() => _PromotionsPageState();
}

class _PromotionsPageState extends State<PromotionsPage> {
  List<Reward> _rewards = [];
  List<Tour> _tours = [];
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
      final results = await Future.wait([
        widget.api.getRewards(),
        widget.api.getTours(),
      ]);
      setState(() {
        _rewards = results[0] as List<Reward>;
        _tours = results[1] as List<Tour>;
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
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
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _openRewardDialog(Reward? existing) {
    showDialog(
      context: context,
      builder: (ctx) => _RewardFormDialog(
        existing: existing,
        tours: _tours,
        onSubmit: (data) async {
          if (existing == null) {
            final created = await widget.api.createReward(data);
            setState(() => _rewards.insert(0, created));
          } else {
            final updated = await widget.api.updateReward(existing.id, data);
            setState(() {
              final idx = _rewards.indexWhere((r) => r.id == existing.id);
              if (idx != -1) _rewards[idx] = updated;
            });
          }
        },
      ),
    );
  }

  String _tourTitle(String id) {
    final t = _tours.firstWhere(
      (t) => t.id == id,
      orElse: () => const Tour(
        id: '',
        name: '',
        companyName: '',
        city: '',
        price: 0,
        date: '',
        guide: '',
        capacity: 0,
        participants: 0,
        status: '',
        duration: '',
        description: '',
        mapLocation: '',
        images: [],
      ),
    );
    return t.name.isEmpty ? 'Unknown tour' : t.name;
  }

  @override
  Widget build(BuildContext context) {
    final total = _rewards.length;
    final active = _rewards.where((r) => r.isActive).length;
    final inactive = total - active;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'All Rewards',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              onPressed: () => _openRewardDialog(null),
              icon: const Icon(Icons.add, color: Colors.white, size: 18),
              label: const Text('Create Reward',
                  style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE07B00),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Manage rewards and partner coupons for your tourists',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            _StatCard(
                label: 'Total Rewards',
                value: total,
                icon: Icons.card_giftcard,
                iconColor: const Color(0xFFE07B00)),
            const SizedBox(width: 16),
            _StatCard(
                label: 'Active Rewards',
                value: active,
                icon: Icons.check_circle_outline,
                iconColor: const Color(0xFF1DB954),
                highlighted: true),
            const SizedBox(width: 16),
            _StatCard(
                label: 'Inactive Rewards',
                value: inactive,
                icon: Icons.cancel_outlined,
                iconColor: Colors.red),
          ],
        ),
        const SizedBox(height: 24),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                      onPressed: _load, child: const Text('Retry')),
                ],
              ),
            ),
          )
        else if (_rewards.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: Text('No rewards yet. Create one!')),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 540,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.05,
            ),
            itemCount: _rewards.length,
            itemBuilder: (_, i) => _RewardCard(
              reward: _rewards[i],
              tourTitleResolver: _tourTitle,
              onToggleStatus: () => _toggleStatus(_rewards[i]),
              onEdit: () => _openRewardDialog(_rewards[i]),
              onDelete: () => _delete(_rewards[i]),
            ),
          ),
      ],
    );
  }
}

class _RewardFormDialog extends StatefulWidget {
  const _RewardFormDialog({
    required this.existing,
    required this.tours,
    required this.onSubmit,
  });

  final Reward? existing;
  final List<Tour> tours;
  final Future<void> Function(Map<String, dynamic> data) onSubmit;

  @override
  State<_RewardFormDialog> createState() => _RewardFormDialogState();
}

class _RewardFormDialogState extends State<_RewardFormDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _discountCtrl;
  late final TextEditingController _partnerNameCtrl;
  late final TextEditingController _partnerCategoryCtrl;
  late final TextEditingController _partnerLocationCtrl;
  late final TextEditingController _redemptionCtrl;

  String _type = 'tour_discount';
  int _requiredLevel = 1;
  bool _isActive = true;
  DateTime? _validUntil;
  final Set<String> _selectedTours = {};

  bool _saving = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    _titleCtrl = TextEditingController(text: r?.title ?? '');
    _descCtrl = TextEditingController(text: r?.description ?? '');
    _discountCtrl =
        TextEditingController(text: r == null ? '' : r.discountPercent.toString());
    _partnerNameCtrl = TextEditingController(text: r?.partnerName ?? '');
    _partnerCategoryCtrl =
        TextEditingController(text: r?.partnerCategory ?? '');
    _partnerLocationCtrl =
        TextEditingController(text: r?.partnerLocation ?? '');
    _redemptionCtrl = TextEditingController(text: r?.redemptionCode ?? '');
    if (r != null) {
      _type = r.type;
      _requiredLevel = r.requiredLevel.clamp(1, _levelNames.length);
      _isActive = r.isActive;
      _selectedTours.addAll(r.applicableTours);
      if (r.validUntil != null && r.validUntil!.isNotEmpty) {
        final parsed = DateTime.tryParse(r.validUntil!);
        if (parsed != null) _validUntil = parsed;
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _discountCtrl.dispose();
    _partnerNameCtrl.dispose();
    _partnerCategoryCtrl.dispose();
    _partnerLocationCtrl.dispose();
    _redemptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _validUntil ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null) {
      setState(() => _validUntil = picked);
    }
  }

  String? _validate() {
    if (_titleCtrl.text.trim().isEmpty) return 'Title is required';
    final disc = int.tryParse(_discountCtrl.text.trim()) ?? 0;
    if (disc < 1 || disc > 100) {
      return 'Discount must be between 1 and 100';
    }
    if (_selectedTours.isEmpty) return 'Select at least one tour';
    if (_type == 'partner_coupon') {
      if (_partnerNameCtrl.text.trim().isEmpty) {
        return 'Partner name is required for coupons';
      }
      if (_redemptionCtrl.text.trim().isEmpty) {
        return 'Redemption code is required for coupons';
      }
    }
    return null;
  }

  Future<void> _submit() async {
    final err = _validate();
    if (err != null) {
      setState(() => _formError = err);
      return;
    }
    setState(() {
      _saving = true;
      _formError = null;
    });

    final data = <String, dynamic>{
      'type': _type,
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'discountPercent': int.tryParse(_discountCtrl.text.trim()) ?? 0,
      'requiredLevel': _requiredLevel,
      'applicableTours': _selectedTours.toList(),
      'isActive': _isActive,
      'validUntil': _validUntil?.toIso8601String(),
    };
    if (_type == 'partner_coupon') {
      data['partnerName'] = _partnerNameCtrl.text.trim();
      data['partnerCategory'] = _partnerCategoryCtrl.text.trim();
      data['partnerLocation'] = _partnerLocationCtrl.text.trim();
      data['redemptionCode'] = _redemptionCtrl.text.trim();
    }

    try {
      await widget.onSubmit(data);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _formError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPartner = _type == 'partner_coupon';

    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      title: Text(widget.existing == null ? 'Create Reward' : 'Edit Reward'),
      content: SizedBox(
        width: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Reward Type',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'tour_discount', child: Text('Tour Discount')),
                  DropdownMenuItem(
                      value: 'partner_coupon',
                      child: Text('Partner Coupon')),
                ],
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _discountCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Discount % (1-100)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _requiredLevel,
                      decoration: const InputDecoration(
                          labelText: 'Required Level'),
                      items: [
                        for (int i = 1; i <= _levelNames.length; i++)
                          DropdownMenuItem(value: i, child: Text(_levelLabel(i))),
                      ],
                      onChanged: (v) =>
                          setState(() => _requiredLevel = v ?? _requiredLevel),
                    ),
                  ),
                ],
              ),
              if (isPartner) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 4),
                const Text('Partner Details',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _partnerNameCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Partner Name'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _partnerCategoryCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Category (e.g. Restaurant, Hotel)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _partnerLocationCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Location'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _redemptionCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Redemption Code (e.g. DALA20)'),
                ),
                const Divider(),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Valid Until: '),
                  TextButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(_validUntil == null
                        ? 'Pick date'
                        : _validUntil!.toIso8601String().slice(0, 10)),
                  ),
                  if (_validUntil != null)
                    IconButton(
                      onPressed: () => setState(() => _validUntil = null),
                      icon: const Icon(Icons.clear, size: 16),
                      tooltip: 'Clear',
                    ),
                ],
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isActive,
                title: const Text('Active'),
                subtitle: Text(_isActive
                    ? 'Visible to tourists in the app'
                    : 'Hidden — won\'t show in app'),
                onChanged: (v) => setState(() => _isActive = v),
                activeThumbColor: const Color(0xFF1DB954),
              ),
              const SizedBox(height: 8),
              const Text('Applicable Tours',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              if (widget.tours.isEmpty)
                const Text('No tours available. Create a tour first.',
                    style: TextStyle(color: Colors.red, fontSize: 12))
              else
                Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final t in widget.tours)
                          CheckboxListTile(
                            dense: true,
                            controlAffinity:
                                ListTileControlAffinity.leading,
                            value: _selectedTours.contains(t.id),
                            title: Text(t.name,
                                style: const TextStyle(fontSize: 13)),
                            subtitle: Text(
                              '${t.city} • ${t.price.toStringAsFixed(0)} SAR',
                              style: const TextStyle(fontSize: 11),
                            ),
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedTours.add(t.id);
                                } else {
                                  _selectedTours.remove(t.id);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              if (_formError != null) ...[
                const SizedBox(height: 12),
                Text(_formError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ],
          ),
        ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1DB954)),
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(widget.existing == null ? 'Create' : 'Save',
                  style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

extension _StringSlice on String {
  String slice(int start, int end) {
    if (length <= end) return this;
    return substring(start, end);
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
                Text(label,
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 8),
                Text('$value',
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.bold)),
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
    required this.tourTitleResolver,
    required this.onToggleStatus,
    required this.onEdit,
    required this.onDelete,
  });

  final Reward reward;
  final String Function(String tourId) tourTitleResolver;
  final VoidCallback onToggleStatus;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isActive = reward.isActive;
    final isPartner = reward.isPartnerCoupon;
    final accent = isPartner
        ? const Color(0xFF7B61FF)
        : const Color(0xFFE07B00);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? accent : Colors.grey.shade300,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isPartner ? 'Partner Coupon' : 'Tour Discount',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accent),
                ),
              ),
              const SizedBox(width: 8),
              Text('${reward.discountPercent}% OFF',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: accent)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFFE8F8EF)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFF1DB954)
                        : Colors.grey.shade400,
                  ),
                ),
                child: Text(
                  isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 11,
                    color: isActive
                        ? const Color(0xFF1DB954)
                        : Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            reward.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (reward.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(reward.description,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetaTile(
                    label: 'Required Level',
                    value: _levelLabel(reward.requiredLevel)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetaTile(
                    label: 'Applied',
                    value: '${reward.totalAppliedCount}'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MetaTile(
                  label: 'Valid Until',
                  value: reward.validUntil ?? '—',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetaTile(
                    label: 'Tours',
                    value: '${reward.applicableTours.length}'),
              ),
            ],
          ),
          if (isPartner && reward.partnerName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.storefront, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${reward.partnerName}'
                    '${reward.partnerCategory.isNotEmpty ? " • ${reward.partnerCategory}" : ""}',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (reward.redemptionCode.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.confirmation_number,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(reward.redemptionCode,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5)),
                ],
              ),
            ],
          ],
          const SizedBox(height: 8),
          const Divider(height: 1),
          Row(
            children: [
              TextButton.icon(
                onPressed: onToggleStatus,
                icon: Icon(
                  isActive
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                  size: 14,
                  color: isActive ? Colors.red : const Color(0xFF1DB954),
                ),
                label: Text(
                  isActive ? 'Deactivate' : 'Activate',
                  style: TextStyle(
                      color:
                          isActive ? Colors.red : const Color(0xFF1DB954),
                      fontSize: 11),
                ),
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 28)),
              ),
              const Spacer(),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                color: Colors.grey.shade700,
                tooltip: 'Edit',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                    minWidth: 28, minHeight: 28),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 16),
                color: Colors.red,
                tooltip: 'Delete',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                    minWidth: 28, minHeight: 28),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaTile extends StatelessWidget {
  const _MetaTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
