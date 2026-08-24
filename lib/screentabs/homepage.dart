import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_providers.dart';
import '../services/leave_credit_service.dart';
import '../services/leave_application_service.dart';
import '../screentabs/apply_for_leave.dart';
import '../widgets/leave_type_card.dart';
import '../widgets/leave_overview_strips.dart';
import '../screentabs/profilepage.dart';
import '../screentabs/leave_monetization.dart';
import '../utils/employee_app_utils.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _creditData;
  int _selectedIndex = 0;

  String? _department;

  List<dynamic> _pendingApplications = [];
  List<dynamic> _approvedApplications = [];
  bool _isLoadingPending = true;

  Timer? _refreshTimer;
  static const Duration _networkTimeout = Duration(seconds: 10);
  static const Duration _pendingRefreshInterval = Duration(seconds: 15);
  static const Duration _refreshInterval = Duration(seconds: 30);

  static const double _leaveTypeCardWidth = 140;
  static const double _leaveTypeCardHeight = 150;

  static const Color _navy = Color(0xFF13224A);
  static const Color _muted = Color(0xFF8A97A8);
  static const Color _bg = Color(0xFFF3F5F9);

  static const List<Color> _accentColors = [
    Color(0xFF1E3A5F),
    Color(0xFF7B5EA7),
    Color(0xFFE07B39),
    Color(0xFF2AABB8),
    Color(0xFF3A8C5C),
    Color(0xFFD94F70),
  ];

  Timer? _pendingRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _loadCredits();
    _loadPendingApplications();
    _loadApprovedApplications();
    _loadEmploymentStatus();

    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (!mounted || _selectedIndex != 0) return;
      _loadCredits(silent: true);
      _loadEmploymentStatus();
    });

    _pendingRefreshTimer = Timer.periodic(_pendingRefreshInterval, (_) {
      if (!mounted || _selectedIndex != 0) return;
      _loadPendingApplications(silent: true);
      _loadApprovedApplications(silent: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _selectedIndex == 0) {
      _loadCredits(silent: true);
      _loadPendingApplications(silent: true);
      _loadApprovedApplications(silent: true);
      _loadEmploymentStatus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _pendingRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCredits({bool silent = false}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;

    if (token == null) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "You are not logged in.";
        _isLoading = false;
      });
      return;
    }

    if (!silent) {
      setState(() => _isLoading = true);
    }

    try {
      final result = await LeaveCreditService.getCredits(
        token,
      ).timeout(_networkTimeout);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (result["success"]) {
          _creditData = result["data"];
          _errorMessage = null;
        } else {
          if (!silent) _errorMessage = result["message"];
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (!silent) {
          _errorMessage = "Couldn't reach the server. Pull to refresh.";
        }
      });
    }
  }

  /// Employee/employment-status data now comes from AuthProvider, which
  /// caches results for ~30s and de-dupes concurrent requests. This is what
  /// stops HomePage and ProfilePage from both hitting /employees/{id} at
  /// the same time and tripping the API's rate limiter (429).
  Future<void> _loadEmploymentStatus() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token == null || auth.employeeId == null) return;

    await auth.fetchEmployeeDetails(silent: true);

    if (!mounted) return;
    setState(() {
      _department = _extractDepartment(auth.employee ?? {});
    });
  }

  String? _extractDepartment(Map<String, dynamic> data) {
    final direct = data['department_name'] ?? data['department'];
    if (direct is String && direct.isNotEmpty) return direct;
    if (direct is Map && direct['name'] != null) {
      return direct['name'].toString();
    }
    return null;
  }

  Future<void> _loadPendingApplications({bool silent = false}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;

    if (token == null) {
      if (!mounted) return;
      setState(() => _isLoadingPending = false);
      return;
    }

    if (!silent) {
      setState(() => _isLoadingPending = true);
    }

    try {
      final result = await LeaveApplicationService.getMyApplications(
        token: token,
        status: 'pending',
      ).timeout(_networkTimeout);

      if (!mounted) return;
      setState(() {
        _isLoadingPending = false;
        if (result['success'] == true) {
          _pendingApplications = result['data'] as List<dynamic>;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingPending = false);
    }
  }

  Future<void> _loadApprovedApplications({bool silent = false}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;
    if (token == null) return;

    try {
      final result = await LeaveApplicationService.getMyApplications(
        token: token,
        status: 'approved',
      ).timeout(_networkTimeout);

      if (!mounted) return;
      if (result['success'] == true) {
        setState(() {
          _approvedApplications = result['data'] as List<dynamic>;
        });
      }
    } catch (_) {}
  }

  Future<void> _viewPendingPdf(int applicationId) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;
    if (token == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: _navy),
      ),
    );

    try {
      final result = await LeaveApplicationService.getApplicationPdfBytes(
        applicationId: applicationId,
        token: token,
      ).timeout(_networkTimeout);

      if (!mounted) return;
      Navigator.pop(context);

      if (result['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Unable to load PDF.')),
        );
        return;
      }

      final bytes = result['bytes'];
      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
        name: 'leave-application-$applicationId.pdf',
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request timed out. Please try again.')),
      );
    }
  }

  String _hiredYearRange() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final dateHired = auth.dateHired;
    if (dateHired == null || dateHired.isEmpty) return '';
    final parsed = DateTime.tryParse(dateHired);
    if (parsed == null) return '';
    final currentYear =
        int.tryParse(_creditData?["year"]?.toString() ?? '') ??
        DateTime.now().year;
    return '${parsed.year}-$currentYear';
  }

  Future<void> _goToApplyLeave() async {
    final credits = extractCreditsList(_creditData);

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApplyForLeave(leaveTypes: credits),
      ),
    );

    if (result != null) {
      await _loadCredits();
      await _loadPendingApplications();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Leave application submitted! It is pending for approval.',
            ),
          ),
        );
      }
    }
  }

  Map<String, double> _approvedUsedByType() {
    final map = <String, double>{};
    for (final app in _approvedApplications) {
      final typeName = (app['leave_type_name'] ?? '').toString();
      final days = toDoubleOrZero(app['days_applied']);
      map[typeName] = (map[typeName] ?? 0) + days;
    }
    return map;
  }

  static const Set<String> _dynamicLeaveTypes = {
    'Vacation Leave',
    'Sick Leave',
  };

  static const Map<String, double> _staticLeaveCaps = {
    'Wellness Leave': 5,
    'VAWC Leave': 10,
    'Rehabilitation Leave': 180,
    'Special Leave Benefits for Women': 60,
    'Special Emergency (Calamity) Leave': 5,
    'Adoption Leave': 60,
    'Study Leave': 180,
    'Mandatory/Forced Leave': 5,
    'Maternity Leave': 105,
    'Paternity Leave': 7,
    'Special Privilege Leave': 3,
    'Solo Parent Leave': 7,
  };

  bool _isDynamicLeaveType(String name) => _dynamicLeaveTypes.contains(name);

  double _staticCapFor(String name, double apiTotal, double apiRemaining) {
    final mapped = _staticLeaveCaps[name];
    if (mapped != null) return mapped;
    if (apiTotal > 0) return apiTotal;
    return apiRemaining;
  }

  Widget _buildWelcomeHeader(
    Map<String, dynamic>? user, {
    required List<dynamic> credits,
    required int pendingCount,
    required Map<String, double> approvedUsedByType,
  }) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final statusLabel = titleCaseOrPlaceholder(auth.employmentStatus);
    final yearRange = _hiredYearRange();
    final subtitle = [
      statusLabel,
      if (_department != null && _department!.isNotEmpty) _department!,
      yearRange,
    ].where((s) => s.isNotEmpty).join(' · ');

    final username = (user?["username"] ?? "User").toString();
    final initial = username.isNotEmpty ? username[0].toUpperCase() : 'U';

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
          padding: const EdgeInsets.fromLTRB(20, 10, 16, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.18),
                      ),
                    ),
                    child: Text(
                      initial,
                      style: GoogleFonts.fraunces(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, $username!',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.fraunces(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.nunito(
                              color: Colors.white60,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
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
              const SizedBox(height: 20),
              LeaveOverviewStrip(
                credits: credits,
                pendingCount: pendingCount,
                approvedUsedByType: approvedUsedByType,
                year: _creditData?["year"],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, {String? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.fraunces(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: _navy,
          ),
        ),
        if (trailing != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: _navy.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              trailing,
              style: GoogleFonts.nunito(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: _navy.withOpacity(0.7),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHomeContent() {
    final user = Provider.of<AuthProvider>(context).user;
    final credits = extractCreditsList(_creditData);
    final approvedUsedByType = _approvedUsedByType();

    return RefreshIndicator(
      onRefresh: () async {
        await _loadCredits();
        await _loadPendingApplications();
        await _loadApprovedApplications();
        await _loadEmploymentStatus();
      },
      color: _navy,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildWelcomeHeader(
            user,
            credits: credits,
            pendingCount: _pendingApplications.length,
            approvedUsedByType: approvedUsedByType,
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 70),
              child: Center(
                child: CircularProgressIndicator(color: _navy),
              ),
            )
          else if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCEAEA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFD9455F),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.nunito(
                          color: const Color(0xFFB23A50),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader('Available Leave Type'),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: _leaveTypeCardHeight,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: credits.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final credit = credits[index];
                        final leaveTypeName =
                            (credit["leave_type"] ?? credit["name"] ?? "")
                                .toString();
                        final apiTotal = toDoubleOrZero(
                          credit["total_credits"],
                        );
                        final apiRemaining = toDoubleOrZero(
                          credit["remaining_balance"],
                        );
                        final isDynamic = _isDynamicLeaveType(leaveTypeName);
                        final approvedUsed =
                            approvedUsedByType[leaveTypeName] ?? 0;
                        final effectiveTotal = isDynamic
                            ? (apiTotal > 0
                                  ? apiTotal
                                  : apiRemaining + approvedUsed)
                            : _staticCapFor(
                                leaveTypeName,
                                apiTotal,
                                apiRemaining,
                              );

                        return SizedBox(
                          width: _leaveTypeCardWidth,
                          child: LeaveTypeCard(
                            leaveType: leaveTypeName,
                            remaining: apiRemaining,
                            total: effectiveTotal,
                            used: isDynamic
                                ? approvedUsed
                                : toDoubleOrZero(credit["used_credits"]),
                            accentColor:
                                _accentColors[index % _accentColors.length],
                            isDynamic: isDynamic,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 26),
                  _sectionHeader(
                    'Pending Requests',
                    trailing: _pendingApplications.isEmpty
                        ? null
                        : '${_pendingApplications.length}',
                  ),
                  const SizedBox(height: 14),
                  if (_isLoadingPending)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: CircularProgressIndicator(color: _navy),
                      ),
                    )
                  else if (_pendingApplications.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 28,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFEDEFF4)),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.task_alt_rounded,
                            color: _muted.withOpacity(0.5),
                            size: 26,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No pending requests',
                            style: GoogleFonts.nunito(
                              color: _muted,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "You're all caught up.",
                            style: GoogleFonts.nunito(
                              color: _muted.withOpacity(0.7),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _pendingApplications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final app =
                            _pendingApplications[index]
                                as Map<String, dynamic>;
                        final leaveType = app['leave_type_name'] ?? 'Leave';
                        final days = app['days_applied']?.toString() ?? '0';
                        final start = formatIsoDate(
                          app['start_date']?.toString(),
                        );
                        final end = formatIsoDate(app['end_date']?.toString());
                        final id = app['id'];
                        final dotColor =
                            _accentColors[index % _accentColors.length];

                        return Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: id == null
                                ? null
                                : () => _viewPendingPdf(id as int),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFEDEFF4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      color: dotColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          leaveType,
                                          style: GoogleFonts.nunito(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: _navy,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '$start – $end · $days day(s)',
                                          style: GoogleFonts.nunito(
                                            fontSize: 12,
                                            color: _muted,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFFF5A623,
                                      ).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Pending',
                                      style: GoogleFonts.nunito(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFFB5750E),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.picture_as_pdf_outlined,
                                    color: _muted,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderTab(String label) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.construction_rounded,
            color: _muted.withOpacity(0.4),
            size: 32,
          ),
          const SizedBox(height: 10),
          Text(
            '$label — coming soon',
            style: GoogleFonts.nunito(
              color: _muted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: null,
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        elevation: 10,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 62,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _bottomNavItem(icon: Icons.home_rounded, label: 'Home', index: 0),
              _bottomNavItem(
                icon: Icons.payments_rounded,
                label: 'Monetize',
                index: 1,
              ),
              const SizedBox(width: 48),
              _bottomNavItem(
                icon: Icons.person_outline_rounded,
                label: 'Profile',
                index: 2,
              ),
              _bottomNavItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
                index: 3,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _selectedIndex == 0
          ? Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _navy.withOpacity(0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: FloatingActionButton(
                backgroundColor: _navy,
                onPressed: _goToApplyLeave,
                shape: const CircleBorder(),
                child: const Icon(Icons.add, color: Colors.white, size: 28),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeContent(),
          const ApplyForLeaveMonetization(),
          ProfilePage(isActive: _selectedIndex == 2),
          _buildPlaceholderTab('Settings'),
        ],
      ),
    );
  }

  Widget _bottomNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    final color = isSelected ? _navy : _muted.withOpacity(0.75);
    return GestureDetector(
      onTap: () {
        final wasInactive = _selectedIndex != 0 && index == 0;
        setState(() => _selectedIndex = index);
        if (wasInactive) {
          _loadCredits(silent: true);
          _loadPendingApplications(silent: true);
          _loadApprovedApplications(silent: true);
          _loadEmploymentStatus();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _navy.withOpacity(0.07) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 10.5,
                color: color,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}