import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_providers.dart';
import '../services/api_service.dart';

class ForceChangePasswordPage extends StatefulWidget {
  const ForceChangePasswordPage({super.key});

  @override
  State<ForceChangePasswordPage> createState() =>
      _ForceChangePasswordPageState();
}

class _ForceChangePasswordPageState extends State<ForceChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  static const Color _navyDark = Color(0xFF13224A);
  static const Color _navy = Color(0xFF1B3B63);
  static const Color _text = Color(0xFF1E3A5F);
  static const Color _muted = Color(0xFF8A97A8);

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) return "New password is required.";
    if (value.length < 8) return "Password must be at least 8 characters.";
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return "Password must include a lowercase letter.";
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return "Password must include an uppercase letter.";
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return "Password must include a number.";
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-\[\]\\/`~;+=]').hasMatch(value)) {
      return "Password must include a symbol.";
    }
    return null;
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = "New passwords do not match.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;

    if (token == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = "You are not logged in.";
      });
      return;
    }

    final result = await ApiService.changePassword(
      token: token,
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
    );

    if (!mounted) return;

    if (result["success"] == true) {
      await auth.markPasswordChanged();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result["message"] ?? "Failed to change password.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF0F5),
      body: SizedBox.expand(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 28),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_navyDark, _navy],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Change Your Password',
                    style: GoogleFonts.fraunces(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "For your security, you must set a new password before "
                    "continuing. This won't be asked again.",
                    style: GoogleFonts.nunito(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),

            // Form
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_errorMessage != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red.shade400,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: GoogleFonts.nunito(
                                      color: Colors.red,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        _sectionCard(
                          icon: Icons.lock_outline_rounded,
                          label: 'Current Password',
                          child: TextFormField(
                            controller: _currentPasswordController,
                            obscureText: _obscureCurrent,
                            style: GoogleFonts.nunito(
                              fontSize: 13.5,
                              color: _text,
                            ),
                            decoration: _fieldDecoration(
                              hint: 'Your current/default password',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureCurrent
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: Colors.grey.shade500,
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                  () => _obscureCurrent = !_obscureCurrent,
                                ),
                              ),
                            ),
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Current password is required.'
                                : null,
                          ),
                        ),
                        const SizedBox(height: 16),

                        _sectionCard(
                          icon: Icons.vpn_key_rounded,
                          label: 'New Password',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _newPasswordController,
                                obscureText: _obscureNew,
                                style: GoogleFonts.nunito(
                                  fontSize: 13.5,
                                  color: _text,
                                ),
                                decoration: _fieldDecoration(
                                  hint: 'Enter a new password',
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureNew
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: Colors.grey.shade500,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscureNew = !_obscureNew,
                                    ),
                                  ),
                                ),
                                validator: _validateNewPassword,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '8+ characters, upper & lower case, a number, and a symbol.',
                                style: GoogleFonts.nunito(
                                  color: _muted,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        _sectionCard(
                          icon: Icons.check_circle_outline_rounded,
                          label: 'Confirm New Password',
                          child: TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirm,
                            style: GoogleFonts.nunito(
                              fontSize: 13.5,
                              color: _text,
                            ),
                            decoration: _fieldDecoration(
                              hint: 'Re-enter new password',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: Colors.grey.shade500,
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm,
                                ),
                              ),
                            ),
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Please confirm your new password.'
                                : null,
                          ),
                        ),
                        const SizedBox(height: 28),

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _navy,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    'Change Password',
                                    style: GoogleFonts.nunito(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _navy.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 15, color: _navy),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: _text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({required String hint, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.nunito(
        color: Colors.grey.shade400,
        fontSize: 13.5,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF5F6FA),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _navy, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.red.shade300),
      ),
    );
  }
}