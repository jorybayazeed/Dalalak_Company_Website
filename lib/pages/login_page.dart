import 'package:flutter/material.dart';

import '../app.dart';
import '../theme/app_theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.onLogin,
    required this.isLoading,
    this.errorText,
  });

  final Future<void> Function(LoginFormData formData) onLogin;
  final bool isLoading;
  final String? errorText;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController(text: 'company@example.com');
  final _passwordController = TextEditingController(text: '12345678');
  UserRole _selectedRole = UserRole.company;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email and password are required.')),
      );
      return;
    }

    await widget.onLogin(
      LoginFormData(
        email: email,
        password: password,
        role: _selectedRole,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FAFC), Color(0xFFF4F3EA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Tourism Company Portal', style: Theme.of(context).textTheme.headlineMedium),
                            const SizedBox(height: 10),
                            Text(
                              'Manage tours, guides, bookings, analytics and business growth in one place.',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.mutedText),
                            ),
                            const SizedBox(height: 22),
                            Wrap(
                              spacing: 14,
                              runSpacing: 14,
                              children: const [
                                _FeatureCard(icon: Icons.map_outlined, title: 'Create and manage tour packages'),
                                _FeatureCard(icon: Icons.workspace_premium_outlined, title: 'Manage rewards and incentives'),
                                _FeatureCard(icon: Icons.trending_up_rounded, title: 'Track performance and analytics'),
                                _FeatureCard(icon: Icons.group_outlined, title: 'Manage tour guides and staff'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    flex: 5,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Login to Dashboard', style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 4),
                            Text('Company, Admin, or Staff access', style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 20),
                            const Text('Company Email'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                hintText: 'company@example.com',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text('Password'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                hintText: '••••••••',
                                prefixIcon: Icon(Icons.lock_outline_rounded),
                              ),
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<UserRole>(
                              initialValue: _selectedRole,
                              decoration: const InputDecoration(labelText: 'Login Role'),
                              items: const [
                                DropdownMenuItem(value: UserRole.company, child: Text('Tourism Company')),
                                DropdownMenuItem(value: UserRole.admin, child: Text('Admin')),
                                DropdownMenuItem(value: UserRole.staff, child: Text('Staff')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedRole = value;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            if (widget.errorText != null) ...[
                              Text(
                                widget.errorText!,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.redAccent),
                              ),
                              const SizedBox(height: 10),
                            ],
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: widget.isLoading ? null : _submit,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  backgroundColor: AppColors.primary,
                                ),
                                child: widget.isLoading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text('Login to Dashboard'),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(onPressed: () {}, child: const Text('Forgot password?')),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginFormData {
  const LoginFormData({
    required this.email,
    required this.password,
    required this.role,
  });

  final String email;
  final String password;
  final UserRole role;
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}