import 'package:flutter/material.dart';
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

  static const Color _navyLight = Color(0xFF2D5491);
  static const Color _navy = Color(0xFF1B3B63);
  static const Color _navyDark = Color(0xFF0D1B3A);

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Mirrors the backend rule: Password::min(8)->mixedCase()->numbers()->symbols()
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
      body: SizedBox.expand(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_navyLight, _navy, _navyDark],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.lock_reset_rounded,
                        color: Colors.tealAccent,
                        size: 40,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Change Your Password",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "For your security, you must set a new password "
                        "before continuing. This won't be asked again.",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 28),

                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.4),
                            ),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      _label("CURRENT PASSWORD"),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _currentPasswordController,
                        obscureText: _obscureCurrent,
                        style: const TextStyle(color: _navy),
                        decoration: _fieldDecoration(
                          hint: "Your current/default password",
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
                            ? "Current password is required."
                            : null,
                      ),
                      const SizedBox(height: 18),

                      _label("NEW PASSWORD"),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: _obscureNew,
                        style: const TextStyle(color: _navy),
                        decoration: _fieldDecoration(
                          hint: "8+ chars, upper & lower case, number, symbol",
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNew
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: Colors.grey.shade500,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _obscureNew = !_obscureNew),
                          ),
                        ),
                        validator: _validateNewPassword,
                      ),
                      const SizedBox(height: 18),

                      _label("CONFIRM NEW PASSWORD"),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirm,
                        style: const TextStyle(color: _navy),
                        decoration: _fieldDecoration(
                          hint: "Re-enter new password",
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
                            ? "Please confirm your new password."
                            : null,
                      ),
                      const SizedBox(height: 32),

                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _navy,
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
                                    color: _navy,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  "Change Password",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
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
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      color: Colors.white60,
      letterSpacing: 0.9,
    ),
  );

  InputDecoration _fieldDecoration({required String hint, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Colors.tealAccent, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide(color: Colors.red.shade300),
      ),
    );
  }
}
