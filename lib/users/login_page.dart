import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_providers.dart';
import '../services/api_service.dart';
import 'otp_verification_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  static const Color _navy = Color(0xFF1B3B63);
  static const Color _navyDark = Color(0xFF0D1B3A);
  static const Color _amber = Color(0xFFD98F32);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiService.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (result["success"] == true) {
      if (result["otp_required"] == true) {
        setState(() => _isLoading = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationPage(userId: result["user_id"]),
          ),
        );
        return;
      }

      Provider.of<AuthProvider>(
        context,
        listen: false,
      ).login(result["token"], result["user"]);

      Navigator.pushReplacementNamed(context, '/home');
    } else {
      setState(() {
        _errorMessage = result["message"] ?? "Login failed. Please try again.";
        _isLoading = false;
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
          // ── Blurred municipal hall photo ───────────────────
          ImageFiltered(
            // imageFilter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            imageFilter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Image.asset(
              'assets/images/echague.png',
              fit: BoxFit.cover,
              // Falls back to plain navy if the photo can't be loaded.
              errorBuilder: (context, error, stack) => Container(color: _navy),
            ),
          ),

          // ── Navy scrim: keeps text readable over the photo ──
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

          // ── Content ────────────────────────────────────────
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(26, 0, 26, 28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 34),

                          // Seal
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.10),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.25),
                                  width: 1.5,
                                ),
                              ),
                              child: SizedBox(
                                height: 96,
                                width: 96,
                                child: Image.asset(
                                  'assets/images/leaevsync.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stack) =>
                                      const Icon(
                                        Icons.account_balance_rounded,
                                        color: Colors.white,
                                        size: 46,
                                      ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          Text(
                            "LeaveSync",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.fraunces(
                              color: Colors.white,
                              fontSize: 32,
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
                          const SizedBox(height: 4),
                          Text(
                            "LGU Echague, Isabela",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6,
                            ),
                          ),

                          const SizedBox(height: 38),

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

                                _LabeledField(
                                  label: "Username or Email",
                                  controller: _emailController,
                                  hint: "e.g. juandelacruz",
                                  icon: Icons.person_outline_rounded,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return "Username or email is required.";
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),

                                _LabeledField(
                                  label: "Password",
                                  controller: _passwordController,
                                  hint: "Enter your password",
                                  icon: Icons.lock_outline_rounded,
                                  obscureText: _obscurePassword,
                                  suffix: IconButton(
                                    splashRadius: 20,
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: Colors.grey.shade500,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      );
                                    },
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return "Password is required.";
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 28),

                                SizedBox(
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _handleLogin,
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
                                            "Log In",
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

                          const SizedBox(height: 26),

                          Text(
                            "Accounts are issued by the HR Office.\nContact HR if you can't sign in.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                              height: 1.5,
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

/// White field with the label laid out as a real widget above the input,
/// so it can't be clipped the way a floating label is.
class _LabeledField extends StatefulWidget {
  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final bool obscureText;
  final Widget? suffix;
  final String? Function(String?)? validator;

  const _LabeledField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.obscureText = false,
    this.suffix,
    this.validator,
  });

  @override
  State<_LabeledField> createState() => _LabeledFieldState();
}

class _LabeledFieldState extends State<_LabeledField> {
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
              suffixIcon: widget.suffix,
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
