import 'dart:ui' as ui;

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

  static const Color _navy = Color(0xFF1B3B63);
  static const Color _navyDark = Color(0xFF0D1B3A);
  static const Color _amber = Color(0xFFD98F32);

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
      backgroundColor: _navyDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Blurred municipal hall photo — same treatment as login/OTP ──
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Image.asset(
              'assets/images/echague.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(color: _navy),
            ),
          ),

          // ── Navy scrim ──
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _navyDark.withOpacity(0.58),
                  _navy.withOpacity(0.45),
                  _navyDark.withOpacity(0.85),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),

          // ── Content ──
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(26, 20, 26, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Seal — same treatment as login/OTP
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.10),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.25),
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.lock_reset_rounded,
                                color: Colors.white,
                                size: 44,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          Text(
                            "Change Your Password",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.fraunces(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                              shadows: [
                                Shadow(
                                  color: _navyDark.withOpacity(0.6),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "For your security, you must set a new password\nbefore continuing. This won't be asked again.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                            ),
                          ),

                          const SizedBox(height: 32),

                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_errorMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFDECEC),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Colors.red.withOpacity(0.35),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.error_outline_rounded,
                                          color: Colors.red.shade700,
                                          size: 19,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!,
                                            style: GoogleFonts.nunito(
                                              color: Colors.red.shade700,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                ],

                                _PasswordField(
                                  label: "Current Password",
                                  hint: "Your current/default password",
                                  icon: Icons.lock_outline_rounded,
                                  controller: _currentPasswordController,
                                  obscureText: _obscureCurrent,
                                  onToggleObscure: () => setState(
                                    () => _obscureCurrent = !_obscureCurrent,
                                  ),
                                  validator: (v) => (v == null || v.isEmpty)
                                      ? 'Current password is required.'
                                      : null,
                                ),
                                const SizedBox(height: 14),

                                _PasswordField(
                                  label: "New Password",
                                  hint: "Enter a new password",
                                  icon: Icons.vpn_key_rounded,
                                  controller: _newPasswordController,
                                  obscureText: _obscureNew,
                                  onToggleObscure: () => setState(
                                    () => _obscureNew = !_obscureNew,
                                  ),
                                  validator: _validateNewPassword,
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Text(
                                    '8+ characters, upper & lower case, a number, and a symbol.',
                                    style: GoogleFonts.nunito(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                _PasswordField(
                                  label: "Confirm New Password",
                                  hint: "Re-enter new password",
                                  icon: Icons.check_circle_outline_rounded,
                                  controller: _confirmPasswordController,
                                  obscureText: _obscureConfirm,
                                  onToggleObscure: () => setState(
                                    () => _obscureConfirm = !_obscureConfirm,
                                  ),
                                  validator: (v) => (v == null || v.isEmpty)
                                      ? 'Please confirm your new password.'
                                      : null,
                                ),
                                const SizedBox(height: 28),

                                SizedBox(
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed: _isLoading
                                        ? null
                                        : _handleSubmit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _amber,
                                      disabledBackgroundColor: _amber
                                          .withOpacity(0.5),
                                      foregroundColor: _navyDark,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              color: _navyDark,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : Text(
                                            "Change Password",
                                            style: GoogleFonts.nunito(
                                              fontSize: 16.5,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// White field with label above the input, matching login page's
/// _LabeledField exactly, plus a show/hide password toggle.
class _PasswordField extends StatefulWidget {
  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final bool obscureText;
  final VoidCallback onToggleObscure;
  final String? Function(String?)? validator;

  const _PasswordField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    required this.obscureText,
    required this.onToggleObscure,
    this.validator,
  });

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  static const Color _navy = Color(0xFF1B3B63);
  static const Color _navyDark = Color(0xFF0D1B3A);
  static const Color _amber = Color(0xFFD98F32);

  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focused != _focusNode.hasFocus) {
        setState(() => _focused = _focusNode.hasFocus);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _focused ? _amber : Colors.transparent,
          width: 2,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(18, 10, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 15, color: _navy),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: GoogleFonts.nunito(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            obscureText: widget.obscureText,
            validator: widget.validator,
            style: GoogleFonts.nunito(
              color: _navyDark,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: const EdgeInsets.only(top: 2, bottom: 8),
              hintText: widget.hint,
              hintStyle: GoogleFonts.nunito(
                color: Colors.grey.shade400,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              suffixIcon: IconButton(
                splashRadius: 20,
                icon: Icon(
                  widget.obscureText
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Colors.grey.shade500,
                  size: 20,
                ),
                onPressed: widget.onToggleObscure,
              ),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 36,
              ),
              errorStyle: GoogleFonts.nunito(
                color: Colors.red.shade700,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
