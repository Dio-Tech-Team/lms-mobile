import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_providers.dart';
import '../services/leave_credit_service.dart';
import '../widgets/leave_balance_card.dart';
import '../utils/employee_app_utils.dart';

class ProfilePage extends StatefulWidget {
  final bool isActive;
  final VoidCallback? onViewLogs;

  const ProfilePage({super.key, this.isActive = true, this.onViewLogs});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _employee;
  Map<String, dynamic>? _creditData;
  bool _isLoading = true;
  String? _errorMessage;

  Timer? _refreshTimer;
  static const Duration _networkTimeout = Duration(seconds: 10);
  static const Duration _refreshInterval = Duration(seconds: 20);
  static TextStyle _serif({
    required double size,
    FontWeight weight = FontWeight.w600,
    Color color = _navy,
    double? letterSpacing,
  }) => GoogleFonts.playfairDisplay(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
  );

  static TextStyle _sans({
    required double size,
    FontWeight weight = FontWeight.w500,
    Color color = _navy,
    double? letterSpacing,
  }) => GoogleFonts.workSans(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
  );

  static const Color _navy = Color(0xFF13224A);
  static const Color _muted = Color(0xFF8A97A8);
  static const Color _bg = Color(0xFFF3F5F9);
  static const Color _hairline = Color(0xFFEDEFF4);
  static const Color _gold = Color(0xFFC9A24B);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.isActive) {
      _loadAll();
      _startTimer();
    }
  }

  void _startTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (mounted) _loadAll(silent: true);
    });
  }

  void _stopTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _loadAll(silent: true);
        _startTimer();
      } else {
        _stopTimer();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && widget.isActive) {
      _loadAll(silent: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;
    final employeeId = auth.employeeId;

    if (token == null || employeeId == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (!silent) {
          _errorMessage = 'No employee record linked to your account.';
        }
      });
      return;
    }

    try {
      await auth.fetchEmployeeDetails(silent: silent);

      final creditResult = await LeaveCreditService.getCredits(
        token,
      ).timeout(_networkTimeout);

      if (auth.employee == null) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          if (!silent) {
            _errorMessage = 'Failed to load profile.';
          }
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _employee = auth.employee;
        _creditData = creditResult['success'] == true
            ? creditResult['data']
            : null;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (!silent) {
          _errorMessage = 'Something went wrong loading your profile.';
        }
      });
    }
  }

  String _fullName() {
    if (_employee == null) return '';
    final first = _employee!['first_name'] ?? '';
    final middle = _employee!['middle_name'];
    final last = _employee!['surname'] ?? '';
    final middleInitial = (middle is String && middle.isNotEmpty)
        ? '${middle[0]}.'
        : '';
    return [
      first,
      middleInitial,
      last,
    ].where((s) => s.toString().trim().isNotEmpty).join(' ');
  }

  String _initials() {
    if (_employee == null) return '';
    final first = (_employee!['first_name'] ?? '').toString();
    final last = (_employee!['surname'] ?? '').toString();
    final a = first.isNotEmpty ? first[0] : '';
    final b = last.isNotEmpty ? last[0] : '';
    return (a + b).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final credits = extractCreditsList(_creditData);
    final vlEntry = credits.firstWhere(
      (c) =>
          (c["leave_type"] ?? c["name"] ?? "").toString() == 'Vacation Leave',
      orElse: () => null,
    );
    final slEntry = credits.firstWhere(
      (c) => (c["leave_type"] ?? c["name"] ?? "").toString() == 'Sick Leave',
      orElse: () => null,
    );

    double vlSlField(dynamic entry, String field) =>
        entry != null ? toDoubleOrZero(entry[field]) : 0.0;
    final vlTotal = vlSlField(vlEntry, "total_credits") > 0
        ? vlSlField(vlEntry, "total_credits")
        : vlSlField(vlEntry, "remaining_balance");
    final slTotal = vlSlField(slEntry, "total_credits") > 0
        ? vlSlField(slEntry, "total_credits")
        : vlSlField(slEntry, "remaining_balance");

    final totalDays = vlTotal + slTotal;
    final usedDays =
        vlSlField(vlEntry, "used_credits") + vlSlField(slEntry, "used_credits");
    final remaining = totalDays - usedDays;
    final overallProgress = totalDays > 0
        ? (usedDays / totalDays).clamp(0.0, 1.0)
        : 0.0;
    final vlMonetizable = vlSlField(vlEntry, "remaining_balance");

    return Container(
      color: _bg,
      child: RefreshIndicator(
        onRefresh: () => _loadAll(),
        color: _navy,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _buildHeader(),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(
                  child: CircularProgressIndicator(color: _navy),
                ),
              )
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    _errorMessage!,
                    style: _sans(size: 13, color: Colors.red.shade700),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionLabel('Work Information'),
                    const SizedBox(height: 10),
                    _buildInfoCard(),
                    const SizedBox(height: 26),
                    if (_creditData != null) ...[
                      _buildSectionLabel('Leave Balance'),
                      const SizedBox(height: 10),
                      LeaveBalanceCard(
                        totalDays: totalDays,
                        usedDays: usedDays,
                        remaining: remaining,
                        overallProgress: overallProgress,
                        vlMonetizable: vlMonetizable,
                        year: _creditData?["year"],
                        employeeName: _creditData?["employee"],
                      ),
                      const SizedBox(height: 26),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 15,
          decoration: BoxDecoration(
            color: _gold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: _sans(
            size: 11.5,
            weight: FontWeight.w700,
            color: _navy.withOpacity(0.55),
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F1B3D), Color(0xFF1B3B63)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 30),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Material(
                    color: Colors.white.withOpacity(0.08),
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => confirmAndLogout(context),
                    ),
                  ),
                ],
              ),
              if (_employee != null) ...[
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.10),
                    border: Border.all(
                      color: _gold.withOpacity(0.55),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _initials(),
                    style: _serif(
                      size: 26,
                      weight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _fullName(),
                  textAlign: TextAlign.center,
                  style: _serif(size: 21, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  (_employee?['position']?.toString().isNotEmpty ?? false)
                      ? _employee!['position'].toString()
                      : 'Employee',
                  style: _sans(
                    size: 13,
                    weight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.72),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _gold.withOpacity(0.45)),
                  ),
                  child: Text(
                    titleCaseOrPlaceholder(
                      _employee?['employment_status']?.toString(),
                      placeholder: '—',
                    ),
                    style: _sans(
                      size: 11,
                      weight: FontWeight.w700,
                      color: _gold.withOpacity(0.95),
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    final rows = [
      (Icons.badge_outlined, 'ID Number', _employee?['id_number']),
      (Icons.work_outline_rounded, 'Position', _employee?['position']),
      (
        Icons.event_outlined,
        'Date Hired',
        formatIsoDate(
          _employee?['date_hired']?.toString(),
          placeholder: '—',
        ),
      ),
      (Icons.apartment_rounded, 'Department', _employee?['department']),
      (Icons.mail_outline_rounded, 'Email', _employee?['email']),
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _hairline),
        boxShadow: [
          BoxShadow(
            color: _navy.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            _infoRow(rows[i].$1, rows[i].$2, rows[i].$3),
            if (i != rows.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(height: 1, color: _hairline),
              ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _navy.withOpacity(0.06),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: _navy.withOpacity(0.7)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: _sans(
                    size: 11.5,
                    weight: FontWeight.w600,
                    color: _muted,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  (value ?? '—').toString(),
                  style: _sans(
                    size: 14,
                    weight: FontWeight.w600,
                    color: _navy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}