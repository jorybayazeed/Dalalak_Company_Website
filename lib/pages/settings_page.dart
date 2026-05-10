import 'package:flutter/material.dart';

import '../app.dart';
import '../data/api_service.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../utils/file_download.dart';
import 'package:dalalak_company_website/widgets/common_widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.api,
    required this.role,
  });

  final ApiService api;
  final UserRole role;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _logoController = TextEditingController();
  final _openingController = TextEditingController();
  final _closingController = TextEditingController();
  final _timezoneController = TextEditingController();
  final _currencyController = TextEditingController();

  bool _madaEnabled = true;
  bool _stcPayEnabled = true;
  bool _applePayEnabled = true;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isBackingUp = false;
  bool _isCleaning = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final settings = await widget.api.getCompanySettings();
      if (!mounted) {
        return;
      }

      setState(() {
        _emailController.text = settings.supportEmail;
        _phoneController.text = settings.supportPhone;
        _cityController.text = settings.city;
        _descriptionController.text = settings.description;
        _logoController.text = settings.logoUrl;
        _openingController.text = settings.openingTime;
        _closingController.text = settings.closingTime;
        _timezoneController.text = settings.timezone;
        _currencyController.text = settings.currency;
        _madaEnabled = settings.madaEnabled;
        _stcPayEnabled = settings.stcPayEnabled;
        _applePayEnabled = settings.applePayEnabled;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load settings: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final payload = CompanySettings(
        supportEmail: _emailController.text.trim(),
        supportPhone: _phoneController.text.trim(),
        city: _cityController.text.trim(),
        description: _descriptionController.text.trim(),
        logoUrl: _logoController.text.trim(),
        openingTime: _openingController.text.trim(),
        closingTime: _closingController.text.trim(),
        timezone: _timezoneController.text.trim().isEmpty ? 'Asia/Riyadh' : _timezoneController.text.trim(),
        currency: _currencyController.text.trim().isEmpty ? 'SAR' : _currencyController.text.trim(),
        madaEnabled: _madaEnabled,
        stcPayEnabled: _stcPayEnabled,
        applePayEnabled: _applePayEnabled,
      );

      await widget.api.updateCompanySettings(payload);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save settings: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _runBackup() async {
    setState(() {
      _isBackingUp = true;
    });
    try {
      final json = await widget.api.downloadBackup();
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final filename = 'dalalak-backup-$stamp.json';
      final downloaded = downloadJsonFile(filename, json);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            downloaded
                ? 'Backup downloaded as $filename. A copy was also saved on the server.'
                : 'Backup created on the server (download is only available on web).',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
        });
      }
    }
  }

  Future<void> _runCleanup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cleanup incomplete tours'),
          content: const Text(
            'This will permanently delete tour packages that are missing required fields '
            '(title, destination, price, capacity, dates, or duration). '
            'It cannot be undone. We recommend running a backup first.\n\n'
            'Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isCleaning = true;
    });
    try {
      final result = await widget.api.cleanupIncompleteTours();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cleanup done. Scanned ${result.scanned}, found ${result.incompleteCount}, '
            'deleted ${result.deleted}, failed ${result.failed.length}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cleanup failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCleaning = false;
        });
      }
    }
  }

  Future<void> _previewIncomplete() async {
    setState(() {
      _isCleaning = true;
    });
    try {
      final result = await widget.api.cleanupIncompleteTours(dryRun: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Scan: ${result.scanned} tours, ${result.incompleteCount} incomplete (no deletions).',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCleaning = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _descriptionController.dispose();
    _logoController.dispose();
    _openingController.dispose();
    _closingController.dispose();
    _timezoneController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      children: [
        SectionPanel(
          title: 'Company Information',
          subtitle: 'Update company profile and contact details',
          action: FilledButton(
            onPressed: _isSaving ? null : _save,
            child: Text(_isSaving ? 'Saving...' : 'Save Changes'),
          ),
          child: Column(
            children: [
              Row(children: [Expanded(child: _Field(label: 'Email', controller: _emailController, hint: 'info@company.com')), const SizedBox(width: 12), Expanded(child: _Field(label: 'Phone', controller: _phoneController, hint: '+966501234567'))]),
              const SizedBox(height: 12),
              Row(children: [Expanded(child: _Field(label: 'City', controller: _cityController, hint: 'Riyadh')), const SizedBox(width: 12), Expanded(child: _Field(label: 'Logo URL', controller: _logoController, hint: 'https://...'))]),
              const SizedBox(height: 12),
              _Field(label: 'Description', controller: _descriptionController, hint: 'Company description', lines: 3),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionPanel(
          title: 'Working Hours',
          subtitle: 'Set your business schedule',
          action: FilledButton(
            onPressed: _isSaving ? null : _save,
            child: Text(_isSaving ? 'Saving...' : 'Save Changes'),
          ),
          child: Row(
            children: [
              Expanded(child: _Field(label: 'Opening Time', controller: _openingController, hint: '08:00')),
              const SizedBox(width: 12),
              Expanded(child: _Field(label: 'Closing Time', controller: _closingController, hint: '18:00')),
              const SizedBox(width: 12),
              Expanded(child: _Field(label: 'Timezone', controller: _timezoneController, hint: 'Asia/Riyadh')),
              const SizedBox(width: 12),
              Expanded(child: _Field(label: 'Currency', controller: _currencyController, hint: 'SAR')),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionPanel(
          title: 'Payment Methods',
          subtitle: 'Manage enabled payment options',
          action: FilledButton(
            onPressed: _isSaving ? null : _save,
            child: Text(_isSaving ? 'Saving...' : 'Save Changes'),
          ),
          child: Column(
            children: [
              _PaymentItem(title: 'Mada', sub: 'Local debit cards', active: _madaEnabled, onChanged: (v) => setState(() => _madaEnabled = v)),
              const SizedBox(height: 10),
              _PaymentItem(title: 'STC Pay', sub: 'Digital wallet', active: _stcPayEnabled, onChanged: (v) => setState(() => _stcPayEnabled = v)),
              const SizedBox(height: 10),
              _PaymentItem(title: 'Apple Pay', sub: 'Apple wallet', active: _applePayEnabled, onChanged: (v) => setState(() => _applePayEnabled = v)),
            ],
          ),
        ),
        if (widget.role == UserRole.admin) ...[
          const SizedBox(height: 14),
          SectionPanel(
            title: 'Data & Backup',
            subtitle: 'Reliable cloud storage with manual backup (NFR-5)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AdminActionTile(
                  icon: Icons.cloud_download_outlined,
                  title: 'Backup database',
                  description:
                      'Export all collections (users, tour packages, companies, rewards, ratings, bookings) '
                      'as a single JSON file. A copy is also stored in backend/data/backups/.',
                  buttonLabel: _isBackingUp ? 'Backing up...' : 'Run Backup',
                  buttonColor: AppColors.primary,
                  onPressed: _isBackingUp ? null : _runBackup,
                ),
                const SizedBox(height: 10),
                _AdminActionTile(
                  icon: Icons.cleaning_services_outlined,
                  title: 'Cleanup incomplete tours',
                  description:
                      'Permanently delete tour packages missing required fields '
                      '(title, destination, price, capacity, dates, duration).',
                  buttonLabel: _isCleaning ? 'Working...' : 'Delete Incomplete',
                  buttonColor: Colors.redAccent,
                  onPressed: _isCleaning ? null : _runCleanup,
                  secondaryLabel: 'Preview only',
                  onSecondaryPressed: _isCleaning ? null : _previewIncomplete,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _AdminActionTile extends StatelessWidget {
  const _AdminActionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.buttonColor,
    required this.onPressed,
    this.secondaryLabel,
    this.onSecondaryPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final Color buttonColor;
  final VoidCallback? onPressed;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFF8FAFC),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: buttonColor.withValues(alpha: 0.12),
            ),
            child: Icon(icon, color: buttonColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(description, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: buttonColor),
                onPressed: onPressed,
                child: Text(buttonLabel),
              ),
              if (secondaryLabel != null) ...[
                const SizedBox(height: 6),
                OutlinedButton(
                  onPressed: onSecondaryPressed,
                  child: Text(secondaryLabel!),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.controller, required this.hint, this.lines = 1});

  final String label;
  final TextEditingController controller;
  final String hint;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        TextField(controller: controller, maxLines: lines, decoration: InputDecoration(hintText: hint)),
      ],
    );
  }
}

class _PaymentItem extends StatelessWidget {
  const _PaymentItem({required this.title, required this.sub, required this.active, required this.onChanged});

  final String title;
  final String sub;
  final bool active;
  final ValueChanged<bool> onChanged;

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
          Switch(value: active, onChanged: onChanged),
        ],
      ),
    );
  }
}