import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  Future<void> _openCreateGuideDialog() => _openGuideDialog();

  Future<void> _openEditGuideDialog(Guide guide) => _openGuideDialog(guide);

  String _generatePassword() {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
    final rand = Random.secure();
    return List.generate(12, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<void> _showCredentialsDialog({
    required String email,
    required String password,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Guide Login Created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Save these credentials and share them with the guide. The password will not be shown again.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            _CredRow(label: 'Email', value: email),
            const SizedBox(height: 8),
            _CredRow(label: 'Password', value: password),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Clipboard.setData(
                ClipboardData(text: 'Email: $email\nPassword: $password'),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Credentials copied to clipboard')),
              );
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetGuidePassword(Guide guide) async {
    final newPassword = _generatePassword();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password?'),
        content: Text(
          'A new password will be generated for ${guide.name}. Their old password will stop working.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Reset')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.api.resetGuidePassword(guide.id, newPassword);
      if (!mounted) return;
      await _showCredentialsDialog(
        email: guide.email,
        password: newPassword,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reset password: $e')),
      );
    }
  }

  Future<void> _openGuideDialog([Guide? existing]) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final cityController = TextEditingController(text: existing?.city ?? '');
    final languagesController = TextEditingController(
        text: existing?.languages.join(', ') ?? '');
    final emailController =
        TextEditingController(text: existing?.email ?? '');
    final phoneController =
        TextEditingController(text: existing?.phone ?? '');
    final specializationController =
        TextEditingController(text: existing?.specialization ?? '');
    final yearsController = TextEditingController(
        text: existing == null ? '' : existing.yearsOfExperience.toString());
    final imageController =
        TextEditingController(text: existing?.image ?? '');
    final passwordController = TextEditingController();

    final isEdit = existing != null;

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            scrollable: true,
            title: Text(isEdit ? 'Edit Guide' : 'Create Guide'),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: nameController,
                      decoration:
                          const InputDecoration(labelText: 'Guide Name')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: cityController,
                      decoration:
                          const InputDecoration(labelText: 'City')),
                  const SizedBox(height: 10),
                  TextField(
                    controller: languagesController,
                    decoration: const InputDecoration(
                        labelText: 'Languages (comma separated)'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: yearsController,
                          decoration: const InputDecoration(
                              labelText: 'Years of Experience'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: specializationController,
                          decoration: const InputDecoration(
                              labelText: 'Specialization'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: imageController,
                    decoration: const InputDecoration(
                        labelText: 'Image URL (optional)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                        labelText: 'Phone (e.g. 0566713589)'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailController,
                    enabled: !isEdit,
                    decoration: InputDecoration(
                      labelText: isEdit
                          ? 'Email (login — cannot be changed)'
                          : 'Email (login)',
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  if (!isEdit) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: passwordController,
                            decoration: const InputDecoration(
                              labelText: 'Password (min 6 chars)',
                              helperText:
                                  'Will be shown once after creation',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            passwordController.text = _generatePassword();
                          },
                          icon: const Icon(Icons.casino, size: 16),
                          label: const Text('Generate'),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop(false);
                        await _resetGuidePassword(existing);
                      },
                      icon: const Icon(Icons.lock_reset, size: 16),
                      label: const Text('Reset Password'),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(isEdit ? 'Save' : 'Create'),
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

      final emailText = emailController.text.trim();
      final passwordText = passwordController.text.trim();

      if (!isEdit) {
        if (emailText.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Email is required.')),
          );
          return;
        }
        if (passwordText.length < 6) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Password must be at least 6 characters.')),
          );
          return;
        }
      }

      final input = CreateGuideInput(
        name: name,
        city: city,
        languages: languages,
        email: emailText.isEmpty ? null : emailText,
        phone: phoneController.text.trim().isEmpty
            ? null
            : phoneController.text.trim(),
        specialization: specializationController.text.trim().isEmpty
            ? null
            : specializationController.text.trim(),
        yearsOfExperience: int.tryParse(yearsController.text.trim()),
        image: imageController.text.trim().isEmpty
            ? null
            : imageController.text.trim(),
        password: isEdit ? null : passwordText,
      );

      if (isEdit) {
        await widget.api.updateGuide(existing.id, input);
      } else {
        await widget.api.createGuide(input);
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(isEdit
                ? 'Guide updated successfully.'
                : 'Guide created successfully.')),
      );
      _reload();

      if (!isEdit) {
        await _showCredentialsDialog(
          email: emailText,
          password: passwordText,
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingGuide = false;
        });
      }
      nameController.dispose();
      cityController.dispose();
      languagesController.dispose();
      specializationController.dispose();
      yearsController.dispose();
      imageController.dispose();
      emailController.dispose();
      passwordController.dispose();
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
                DataColumn(label: Text('Specialization')),
                DataColumn(label: Text('Languages')),
                DataColumn(label: Text('City')),
                DataColumn(label: Text('Years Exp.')),
                DataColumn(label: Text('Rating')),
                DataColumn(label: Text('Total Tours')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: rows.map((guide) {
                final available = guide.status == 'Available';
                return DataRow(cells: [
                  DataCell(Text(guide.name)),
                  DataCell(Text(guide.specialization.isEmpty ? '—' : guide.specialization)),
                  DataCell(Text(guide.languagesText)),
                  DataCell(Text(guide.city)),
                  DataCell(Text('${guide.yearsOfExperience}')),
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
                      IconButton(
                        onPressed: () => _openEditGuideDialog(guide),
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit',
                      ),
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


class _CredRow extends StatelessWidget {
  const _CredRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(
              fontFamily: "monospace",
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 16),
          tooltip: "Copy",
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
          },
        ),
      ],
    );
  }
}
