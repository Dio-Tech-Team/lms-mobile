import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_providers.dart';
import '../variables.dart';

class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  static const Color _navy = Color(0xFF1E3A5F);
  static const Color _muted = Color(0xFF8A97A8);

  static const Duration _networkTimeout = Duration(seconds: 20);

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateNewPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'New password is required.';
    if (v.length < 8) return 'Must be at least 8 characters.';
    if (!RegExp(r'[a-z]').hasMatch(v) || !RegExp(r'[A-Z]').hasMatch(v)) {
      return 'Must include both upper and lower case letters.';
    }
    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Must include at least one number.';
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-\[\]\\/+=~`;]').hasMatch(v)) {
      return 'Must include at least one symbol.';
    }
    return null;
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;

    if (token == null) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Your session expired. Please log in again.';
      });
      return;
    }

    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/change-password'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'current_password': _currentPasswordController.text,
              'password': _newPasswordController.text,
              'password_confirmation': _confirmPasswordController.text,
            }),
          )
          .timeout(_networkTimeout);

      if (!mounted) return;

      if (res.statusCode == 200) {
        await auth.clearMustChangePassword();
        if (!mounted) return;
        Navigator.pop(context, true);
        return;
      }

      if (res.statusCode == 422) {
        final decoded = jsonDecode(res.body);
        final errors = decoded['errors'] as Map<String, dynamic>?;
        final firstError = errors?.values.first?[0]?.toString();
        setState(() {
          _isSubmitting = false;
          _errorMessage = firstError ?? decoded['message'] ?? 'Please check your input.';
        });
        return;
      }

      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Failed to change password (${res.statusCode}). Please try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = "Couldn't reach the server. Please try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _navy.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock_reset_rounded, color: _navy, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          "Set a New Password",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _navy,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "For your security, you need to set a new password before continuing.",
                    style: TextStyle(color: _muted, fontSize: 12.5),
                  ),
                  const SizedBox(height: 20),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withOpacity(0.25)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12.5),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  _fieldLabel("Current Password"),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _currentPasswordController,
                    obscureText: _obscureCurrent,
                    decoration: _fieldDecoration(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureCurrent
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: Colors.grey.shade500,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                      ),
                    ),
                    validator: (value) =>
                        (value == null || value.isEmpty) ? "Current password is required." : null,
                  ),
                  const SizedBox(height: 16),

                  _fieldLabel("New Password"),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: _obscureNew,
                    decoration: _fieldDecoration(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: Colors.grey.shade500,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscureNew = !_obscureNew),
                      ),
                    ),
                    validator: _validateNewPassword,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "At least 8 characters, upper & lower case, a number, and a symbol.",
                    style: TextStyle(color: _muted.withOpacity(0.9), fontSize: 10.5),
                  ),
                  const SizedBox(height: 16),

                  _fieldLabel("Confirm New Password"),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirm,
                    decoration: _fieldDecoration(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: Colors.grey.shade500,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Please confirm your new password.";
                      }
                      if (value != _newPasswordController.text) {
                        return "Passwords do not match.";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                            )
                          : const Text(
                              "Update Password",
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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

  Widget _fieldLabel(String text) => Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _muted),
      );

  InputDecoration _fieldDecoration({Widget? suffixIcon}) {
    return InputDecoration(
      hintText: "••••••••",
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF4F6F9),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.deepPurple, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade300),
      ),
    );
  }
}