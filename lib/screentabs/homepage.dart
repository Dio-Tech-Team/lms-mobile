import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/auth_providers.dart';
import '../services/leave_credit_service.dart';
import '../services/leave_application_service.dart';
import '../users/login_page.dart';
import '../screentabs/apply_for_leave.dart';
import '../widgets/leave_type_card.dart';
import '../widgets/leave_overview_strips.dart';
import '../screentabs/profilepage.dart';
import '../variables.dart';

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

  String? _employmentStatus;
  String? _dateHired;

  List<dynamic> _pendingApplications = [];
  // Used to compute real VL/SL usage for the Overview strip, since the
  // API's used_credits field isn't reliably updated after approval.
  List<dynamic> _approvedApplications = [];
  bool _isLoadingPending = true;

  Timer? _refreshTimer;
  static const Duration _networkTimeout = Duration(seconds: 10);
  // Pending requests are the thing users most want to see update quickly
  // (e.g. right after an approval), so poll them more often than credits.
  static const Duration _pendingRefreshInterval = Duration(seconds: 15);
  static const Duration _refreshInterval = Duration(seconds: 30);

  static const double _leaveTypeCardWidth = 140;
  static const double _leaveTypeCardHeight = 150;

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

    // Silently refresh credits/employment info in the background —
    // only while the Home tab is actually visible.
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (!mounted || _selectedIndex != 0) return;
      _loadCredits(silent: true);
      _loadEmploymentStatus();
    });

    // Pending requests get their own, faster timer since approvals/rejections
    // should disappear from this list as soon as possible. Approved
    // applications refresh on the same cadence, since a newly-approved
    // request is exactly what should update the Overview's "Used" number.
    _pendingRefreshTimer = Timer.periodic(_pendingRefreshInterval, (_) {
      if (!mounted || _selectedIndex != 0) return;
      _loadPendingApplications(silent: true);
      _loadApprovedApplications(silent: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Timers pause while the app is backgrounded on most platforms, so an
    // approval that happens while the app was minimized won't show up until
    // we explicitly refresh here, the moment the user comes back.
    // Only do this if Home is the visible tab — Profile handles its own.
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
      final result = await LeaveCreditService.getCredits(token)
          .timeout(_networkTimeout);

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

  Future<void> _loadEmploymentStatus() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;
    final employeeId = auth.employeeId;

    if (token == null || employeeId == null) return;

    try {
      final res = await http
          .get(
            Uri.parse('$baseUrl/employees/$employeeId'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_networkTimeout);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (!mounted) return;
        setState(() {
          _employmentStatus = data['employment_status']?.toString();
          _dateHired = data['date_hired']?.toString();
        });
      }
    } catch (_) {
      // Silent by nature already — no UI to show for this one.
    }
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
    } catch (_) {
      // Silent by design — this is a background/supplementary fetch.
    }
  }

  Future<void> _viewPendingPdf(int applicationId) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;
    if (token == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.deepPurple)),
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

  String _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '';
    try {
      final date = DateTime.parse(isoDate);
      return '${date.month.toString().padLeft(2, '0')}/'
          '${date.day.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return isoDate;
    }
  }

  String _titleCase(String? value) {
    if (value == null || value.isEmpty) return '';
    return value
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  String _hiredYearRange() {
    if (_dateHired == null || _dateHired!.isEmpty) return '';
    final parsed = DateTime.tryParse(_dateHired!);
    if (parsed == null) return '';
    final currentYear = int.tryParse(_creditData?["year"]?.toString() ?? '') ??
        DateTime.now().year;
    return '${parsed.year}-$currentYear';
  }

  Future<void> _goToApplyLeave() async {
    List<dynamic> credits = [];

    if (_creditData is Map) {
      if (_creditData!["credits"] is List) {
        credits = _creditData!["credits"];
      } else if (_creditData!["data"] is List) {
        credits = _creditData!["data"];
      }
    } else if (_creditData is List) {
      credits = _creditData as List<dynamic>;
    }

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
            content: Text('Leave application submitted! It is pending approval.'),
          ),
        );
      }
    }
  }

  double _toDouble(dynamic value) =>
      double.tryParse(value?.toString() ?? '0') ?? 0.0;

  /// Maps leave type name -> total approved days_applied. Used instead of
  /// the API's used_credits field, which isn't reliably updated after an
  /// application is approved. Needed per-type (not just a VL+SL combined
  /// sum) because we also use it to reconstruct each type's true total —
  /// remaining_balance may or may not already be decremented by the
  /// backend depending on the leave type, so total = remaining + used is
  /// the only reconstruction that works in both cases.
  Map<String, double> _approvedUsedByType() {
    final map = <String, double>{};
    for (final app in _approvedApplications) {
      final typeName = (app['leave_type_name'] ?? '').toString();
      final days = _toDouble(app['days_applied']);
      map[typeName] = (map[typeName] ?? 0) + days;
    }
    return map;
  }

  // Vacation Leave and Sick Leave accrue monthly, so both their cap
  // (total_credits) and remaining balance genuinely change over time —
  // for these we show the numbers exactly as the API sends them.
  static const Set<String> _dynamicLeaveTypes = {
    'Vacation Leave',
    'Sick Leave',
  };

  // Everything else is a fixed, non-accruing allocation. The API's
  // total_credits field isn't populated for these, so we use a known
  // fixed cap instead. Update this map to match your actual
  // leave_configuration values — these are standard PH civil-service
  // defaults and may not match your setup exactly (e.g. Paternity Leave
  // is statutorily 7 days, but your data showed a remaining balance of 3,
  // which could mean days were already used, or your config differs).
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

  /// Returns the fixed cap for a static leave type. Falls back to the
  /// API's total_credits if the type isn't in the map, and if that's
  /// also 0/missing, falls back to remaining_balance (better to show
  /// a number that's at least equal to the true entitlement so far,
  /// than a misleading "of 0").
  double _staticCapFor(String name, double apiTotal, double apiRemaining) {
    final mapped = _staticLeaveCaps[name];
    if (mapped != null) return mapped;
    if (apiTotal > 0) return apiTotal;
    return apiRemaining;
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 10),
            Text('Confirm Logout'),
          ],
        ),
        content: const Text('Do you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      Provider.of<AuthProvider>(context, listen: false).logout();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  Widget _buildWelcomeHeader(
    Map<String, dynamic>? user, {
    required List<dynamic> credits,
    required int pendingCount,
    required Map<String, double> approvedUsedByType,
  }) {
    final statusLabel = _titleCase(_employmentStatus);
    final yearRange = _hiredYearRange();
    final subtitle = [statusLabel, yearRange]
        .where((s) => s.isNotEmpty)
        .join(' · ');

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF13224A), Color(0xFF1B3B63)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Hello, ${user?["username"] ?? "User"}!',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    onPressed: _handleLogout,
                  ),
                ],
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                ),
              ],
              const SizedBox(height: 18),
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

  Widget _buildHomeContent() {
    final user = Provider.of<AuthProvider>(context).user;
    final List<dynamic> credits = () {
      if (_creditData is Map) {
        if (_creditData!["credits"] is List) return _creditData!["credits"];
        if (_creditData!["data"] is List) return _creditData!["data"];
      } else if (_creditData is List) {
        return _creditData as List<dynamic>;
      }
      return <dynamic>[];
    }();
    final approvedUsedByType = _approvedUsedByType();

    return RefreshIndicator(
      onRefresh: () async {
        await _loadCredits();
        await _loadPendingApplications();
        await _loadApprovedApplications();
        await _loadEmploymentStatus();
      },
      color: Colors.deepPurple,
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
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: CircularProgressIndicator(color: Colors.deepPurple),
              ),
            )
          else if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Available Leave Type',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
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
                            (credit["leave_type"] ?? credit["name"] ?? "").toString();
                        final apiTotal = _toDouble(credit["total_credits"]);
                        final apiRemaining = _toDouble(credit["remaining_balance"]);
                        final isDynamic = _isDynamicLeaveType(leaveTypeName);

                        // total_credits isn't reliably populated by the API for
                        // ANY leave type, and remaining_balance may or may not
                        // already be decremented depending on the type — so for
                        // dynamic types, reconstruct the true total as
                        // remaining + approved-used rather than assuming either.
                        final approvedUsed = approvedUsedByType[leaveTypeName] ?? 0;
                        final effectiveTotal = isDynamic
                            ? (apiTotal > 0 ? apiTotal : apiRemaining + approvedUsed)
                            : _staticCapFor(leaveTypeName, apiTotal, apiRemaining);

                        return SizedBox(
                          width: _leaveTypeCardWidth,
                          child: LeaveTypeCard(
                            leaveType: leaveTypeName,
                            remaining: apiRemaining,
                            total: effectiveTotal,
                            used: isDynamic
                                ? approvedUsed
                                : _toDouble(credit["used_credits"]),
                            accentColor: _accentColors[index % _accentColors.length],
                            isDynamic: isDynamic,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Pending Requests',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_isLoadingPending)
                    const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
                  else if (_pendingApplications.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text(
                          'No pending requests.',
                          style: TextStyle(color: Color(0xFF8A97A8)),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _pendingApplications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final app = _pendingApplications[index] as Map<String, dynamic>;
                        final leaveType = app['leave_type_name'] ?? 'Leave';
                        final days = app['days_applied']?.toString() ?? '0';
                        final start = _formatDate(app['start_date']?.toString());
                        final end = _formatDate(app['end_date']?.toString());
                        final id = app['id'];

                        return InkWell(
                          onTap: id == null ? null : () => _viewPendingPdf(id as int),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        leaveType,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: Color(0xFF1E3A5F),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$start – $end · $days day(s)',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF8A97A8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.picture_as_pdf_outlined,
                                    color: Color(0xFF8A97A8), size: 20),
                              ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF0F5),
      appBar: null,
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        elevation: 8,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _bottomNavItem(icon: Icons.home_rounded, label: 'Home', index: 0),
              const SizedBox(width: 48),
              _bottomNavItem(icon: Icons.person_outline_rounded, label: 'Profile', index: 1),
            ],
          ),
        ),
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              backgroundColor: Colors.deepPurple,
              onPressed: _goToApplyLeave,
              shape: const CircleBorder(),
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      // IndexedStack keeps both tabs mounted so switching between them is
      // instant and ProfilePage doesn't re-run its network calls every time.
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeContent(),
          ProfilePage(isActive: _selectedIndex == 1),
        ],
      ),
    );
  }

  Widget _bottomNavItem({required IconData icon, required String label, required int index}) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        final wasInactive = _selectedIndex != 0 && index == 0;
        setState(() => _selectedIndex = index);
        if (wasInactive) {
          // Coming back to Home after the timer was paused — catch up now
          // rather than waiting for the next tick.
          _loadCredits(silent: true);
          _loadPendingApplications(silent: true);
          _loadApprovedApplications(silent: true);
          _loadEmploymentStatus();
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isSelected ? Colors.deepPurple : Colors.grey, size: 24),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isSelected ? Colors.deepPurple : Colors.grey,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}