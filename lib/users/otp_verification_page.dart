import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_providers.dart';
import '../services/api_service.dart';

class OtpVerificationPage extends StatefulWidget {
  final int userId;

  const OtpVerificationPage({super.key, required this.userId});

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();

  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;
  String? _infoMessage;

  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  static const Color _navy = Color(0xFF1B3B63);
  static const Color _navyDark = Color(0xFF0D1B3A);
  static const Color _amber = Color(0xFFD98F32);

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 30);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  Future<void> _handleVerify() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    final result = await ApiService.verifyOtp(
      userId: widget.userId,
      otp: _otpController.text.trim(),
    );

    if (!mounted) return;

    if (result["success"] == true) {
      Provider.of<AuthProvider>(
        context,
        listen: false,
      ).login(result["token"], result["user"]);

      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } else {
      setState(() {
        _errorMessage = result["message"] ?? "Verification failed.";
        _isVerifying = false;
      });
    }
  }

  Future<void> _handleResend() async {
    if (_resendCooldown > 0) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    final result = await ApiService.resendOtp(userId: widget.userId);

    if (!mounted) return;

    setState(() {
      _isResending = false;
      if (result["success"] == true) {
        _infoMessage = result["message"] ?? "A new code has been sent.";
        _startCooldown();
      } else {
        _errorMessage = result["message"] ?? "Unable to resend code.";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navyDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Blurred municipal hall photo — same treatment as login ──
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
                      padding: const EdgeInsets.fromLTRB(26, 0, 26, 28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Back button, top-left
                          Align(
                            alignment: Alignment.topLeft,
                            child: IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Seal — same shape/treatment as login's logo mark
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
                                Icons.mark_email_read_outlined,
                                color: Colors.white,
                                size: 44,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          Text(
                            "Verify Your Email",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.fraunces(
                              color: Colors.white,
                              fontSize: 30,
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
                            "Enter the 6-digit code sent to your email.\nIt expires in 10 minutes.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                            ),
                          ),

                          const SizedBox(height: 34),

                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_errorMessage != null) ...[
                                  _StatusBanner(
                                    message: _errorMessage!,
                                    icon: Icons.error_outline_rounded,
                                    color: Colors.red.shade700,
                                    background: const Color(0xFFFDECEC),
                                    borderColor: Colors.red.withOpacity(0.35),
                                  ),
                                  const SizedBox(height: 18),
                                ],

                                if (_infoMessage != null) ...[
                                  _StatusBanner(
                                    message: _infoMessage!,
                                    icon: Icons.check_circle_outline_rounded,
                                    color: _navy,
                                    background: Colors.white,
                                    borderColor: _navy.withOpacity(0.25),
                                  ),
                                  const SizedBox(height: 18),
                                ],

                                _OtpCodeField(
                                  controller: _otpController,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return "Enter the code sent to your email.";
                                    }
                                    if (value.trim().length != 6) {
                                      return "Code must be 6 digits.";
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 28),

                                SizedBox(
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed: _isVerifying
                                        ? null
                                        : _handleVerify,
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
                                    child: _isVerifying
                                        ? const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              color: _navyDark,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : Text(
                                            "Verify",
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

                          const SizedBox(height: 22),

                          Center(
                            child: TextButton(
                              onPressed: (_resendCooldown > 0 || _isResending)
                                  ? null
                                  : _handleResend,
                              child: _isResending
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      _resendCooldown > 0
                                          ? "Resend code in ${_resendCooldown}s"
                                          : "Didn't get a code? Resend",
                                      style: GoogleFonts.nunito(
                                        color: _resendCooldown > 0
                                            ? Colors.white.withOpacity(0.55)
                                            : _amber,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
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

/// White banner matching login page's inline error-message treatment.
class _StatusBanner extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color color;
  final Color background;
  final Color borderColor;

  const _StatusBanner({
    required this.message,
    required this.icon,
    required this.color,
    required this.background,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.nunito(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// White code field styled like login's _LabeledField — label above,
/// amber focus border — sized for a centered, spaced-out 6-digit code.
class _OtpCodeField extends StatefulWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;

  const _OtpCodeField({required this.controller, this.validator});

  @override
  State<_OtpCodeField> createState() => _OtpCodeFieldState();
}

class _OtpCodeFieldState extends State<_OtpCodeField> {
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
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.pin_outlined, size: 15, color: _navy),
              const SizedBox(width: 6),
              Text(
                "Verification Code",
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
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            validator: widget.validator,
            style: GoogleFonts.nunito(
              color: _navyDark,
              fontSize: 20,
              letterSpacing: 8,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              isDense: true,
              counterText: "",
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: const EdgeInsets.only(top: 2, bottom: 8),
              hintText: "······",
              hintStyle: GoogleFonts.nunito(
                color: Colors.grey.shade400,
                fontSize: 20,
                letterSpacing: 8,
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
