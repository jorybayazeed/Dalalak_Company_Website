import 'package:flutter/material.dart';

import '../data/api_service.dart';
import '../theme/app_theme.dart';

class CompanyRequestsPage extends StatefulWidget {
  const CompanyRequestsPage({super.key, required this.api});

  final ApiService api;

  @override
  State<CompanyRequestsPage> createState() => _CompanyRequestsPageState();
}

class _CompanyRequestsPageState extends State<CompanyRequestsPage> {
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  String? _error;
  String _filterStatus = 'pending';

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
      final rows = await widget.api.getCompanyRequests(status: _filterStatus);
      if (!mounted) return;
      setState(() {
        _requests = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _review(String id, String action) async {
    String reason = '';

    if (action == 'reject') {
      final reasonInput = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final ctrl = TextEditingController();
          return AlertDialog(
            title: const Text('Reject Reason'),
            content: TextField(
              controller: ctrl,
              decoration: const InputDecoration(hintText: 'Optional reason...'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: const Text('Confirm Reject'),
              ),
            ],
          );
        },
      );
      if (reasonInput == null) return;
      reason = reasonInput;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Approve Company'),
          content: const Text('Are you sure you want to approve this company? A login account will be created immediately.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Approve'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      await widget.api.reviewCompanyRequest(id, action, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(action == 'approve' ? 'Company approved successfully!' : 'Request rejected.'),
          backgroundColor: action == 'approve' ? Colors.green : Colors.redAccent,
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Company Registration Requests', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'pending', label: Text('Pending')),
                ButtonSegment(value: 'approved', label: Text('Approved')),
                ButtonSegment(value: 'rejected', label: Text('Rejected')),
                ButtonSegment(value: '', label: Text('All')),
              ],
              selected: {_filterStatus},
              onSelectionChanged: (val) {
                setState(() => _filterStatus = val.first);
                _load();
              },
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null)
          Center(
            child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          )
        else if (_requests.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('No ${_filterStatus.isEmpty ? "" : "$_filterStatus "}requests found.',
                  style: Theme.of(context).textTheme.bodyLarge),
            ),
          )
        else
          ...(_requests.map((req) => _RequestCard(
                request: req,
                onApprove: req['status'] == 'pending' ? () => _review(req['id'] as String, 'approve') : null,
                onReject: req['status'] == 'pending' ? () => _review(req['id'] as String, 'reject') : null,
              ))),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    this.onApprove,
    this.onReject,
  });

  final Map<String, dynamic> request;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.redAccent;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = request['status'] as String? ?? 'pending';
    final companyName = request['companyName'] as String? ?? '';
    final contactName = request['contactName'] as String? ?? '';
    final email = request['email'] as String? ?? '';
    final phone = request['phone'] as String? ?? '';
    final city = request['city'] as String? ?? '';
    final commercialId = request['commercialId'] as String? ?? '';
    final reviewReason = request['reviewReason'] as String? ?? '';
    final reviewedBy = request['reviewedBy'] as String? ?? '';
    final createdAt = request['createdAt'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(companyName, style: Theme.of(context).textTheme.titleMedium),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _statusColor(status).withOpacity(0.4)),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: _statusColor(status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _InfoItem(icon: Icons.person_outline, label: 'Contact', value: contactName),
                _InfoItem(icon: Icons.email_outlined, label: 'Email', value: email),
                if (phone.isNotEmpty) _InfoItem(icon: Icons.phone_outlined, label: 'Phone', value: phone),
                if (city.isNotEmpty) _InfoItem(icon: Icons.location_on_outlined, label: 'City', value: city),
                if (commercialId.isNotEmpty)
                  _InfoItem(icon: Icons.badge_outlined, label: 'Commercial ID', value: commercialId),
                if (createdAt.isNotEmpty)
                  _InfoItem(icon: Icons.calendar_today_outlined, label: 'Submitted', value: createdAt),
              ],
            ),
            if (reviewReason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 15, color: AppColors.mutedText),
                  const SizedBox(width: 6),
                  Text('Review note: ', style: Theme.of(context).textTheme.bodySmall),
                  Text(reviewReason, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
            if (reviewedBy.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Reviewed by: $reviewedBy',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedText)),
            ],
            if (onApprove != null || onReject != null) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onReject != null)
                    OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close, color: Colors.redAccent),
                      label: const Text('Reject', style: TextStyle(color: Colors.redAccent)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                    ),
                  const SizedBox(width: 10),
                  if (onApprove != null)
                    FilledButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                      style: FilledButton.styleFrom(backgroundColor: Colors.green),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.mutedText),
        const SizedBox(width: 4),
        Text('$label: ', style: Theme.of(context).textTheme.bodySmall),
        Text(value, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
