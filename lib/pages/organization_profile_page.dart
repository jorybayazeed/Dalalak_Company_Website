import 'package:flutter/material.dart';

import '../data/api_service.dart';
import '../data/models.dart';
import '../widgets/common_widgets.dart';

class OrganizationProfilePage extends StatefulWidget {
  const OrganizationProfilePage({
    super.key,
    required this.api,
  });

  final ApiService api;

  @override
  State<OrganizationProfilePage> createState() => _OrganizationProfilePageState();
}

class _OrganizationProfilePageState extends State<OrganizationProfilePage> {
  final _companyNameController = TextEditingController();
  final _brandingController = TextEditingController();
  final _logoController = TextEditingController();
  final _primaryColorController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _commercialIdController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _websiteController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

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
      final profile = await widget.api.getCompanyProfile();
      if (!mounted) {
        return;
      }

      setState(() {
        _companyNameController.text = profile.companyName;
        _brandingController.text = profile.branding;
        _logoController.text = profile.logoUrl;
        _primaryColorController.text = profile.primaryColor;
        _contactEmailController.text = profile.contactEmail;
        _contactPhoneController.text = profile.contactPhone;
        _cityController.text = profile.city;
        _addressController.text = profile.address;
        _commercialIdController.text = profile.commercialId;
        _descriptionController.text = profile.description;
        _websiteController.text = profile.website;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load organization profile: $error')),
      );
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final payload = CompanyProfile(
        companyName: _companyNameController.text.trim(),
        branding: _brandingController.text.trim(),
        logoUrl: _logoController.text.trim(),
        primaryColor: _primaryColorController.text.trim(),
        contactEmail: _contactEmailController.text.trim(),
        contactPhone: _contactPhoneController.text.trim(),
        city: _cityController.text.trim(),
        address: _addressController.text.trim(),
        commercialId: _commercialIdController.text.trim(),
        description: _descriptionController.text.trim(),
        website: _websiteController.text.trim(),
      );

      await widget.api.updateCompanyProfile(payload);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Organization profile saved successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save organization profile: $error')),
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
  void dispose() {
    _companyNameController.dispose();
    _brandingController.dispose();
    _logoController.dispose();
    _primaryColorController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _commercialIdController.dispose();
    _descriptionController.dispose();
    _websiteController.dispose();
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
          title: 'Organization Account',
          subtitle: 'Profile, branding, contact, and commercial ID',
          action: FilledButton(
            onPressed: _isSaving ? null : _save,
            child: Text(_isSaving ? 'Saving...' : 'Save Profile'),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _OrgField(label: 'Organization Name', controller: _companyNameController)),
                  const SizedBox(width: 12),
                  Expanded(child: _OrgField(label: 'Commercial ID', controller: _commercialIdController)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _OrgField(label: 'Branding Details', controller: _brandingController)),
                  const SizedBox(width: 12),
                  Expanded(child: _OrgField(label: 'Primary Color', controller: _primaryColorController, hint: '#1DB954')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _OrgField(label: 'Contact Email', controller: _contactEmailController)),
                  const SizedBox(width: 12),
                  Expanded(child: _OrgField(label: 'Contact Phone', controller: _contactPhoneController)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _OrgField(label: 'City', controller: _cityController)),
                  const SizedBox(width: 12),
                  Expanded(child: _OrgField(label: 'Website', controller: _websiteController, hint: 'https://...')),
                ],
              ),
              const SizedBox(height: 12),
              _OrgField(label: 'Address', controller: _addressController, lines: 2),
              const SizedBox(height: 12),
              _OrgField(label: 'Logo URL', controller: _logoController, hint: 'https://...'),
              const SizedBox(height: 12),
              _OrgField(label: 'Organization Description', controller: _descriptionController, lines: 3),
            ],
          ),
        ),
      ],
    );
  }
}

class _OrgField extends StatelessWidget {
  const _OrgField({
    required this.label,
    required this.controller,
    this.hint,
    this.lines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final int lines;

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
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}
