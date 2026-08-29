import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_providers.dart';
import '../services/leave_credit_service.dart';
import '../services/leave_application_service.dart';
import '../screentabs/apply_for_leave.dart';
import '../widgets/leave_type_card.dart';
import '../screentabs/profilepage.dart';
import '../screentabs/leave_monetization.dart';
import '../screentabs/history_logs.dart';
import '../utils/employee_app_utils.dart';
import '../utils/app_theme.dart';
import 'dart:typed_data';
import '../widgets/pdf_view_page.dart';
import '../widgets/app_header.dart';

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

  /// Id of the application currently being cancelled, or null. Doubles as
  /// the double-submit guard and as the per-tile spinner flag.
  int? _cancellingId;
  bool _isApplyOpen = false;

  Timer? _refreshTimer;
  static const Duration _networkTimeout = Duration(seconds: 30);
  static const Duration _pendingRefreshInterval = Duration(minutes: 2);
  static const Duration _refreshInterval = Duration(minutes: 2);

  static const double _leaveTypeCardWidth = 150;
  static const double _leaveTypeCardHeight = 178;

  Timer? _pendingRefreshTimer;
  DateTime? _lastResumeRefresh;

  /// A Navigator scoped to just the tab-content area (below the app's
  /// persistent nav bar). Any push made by a widget inside the tabs
  /// resolves to THIS Navigator automatically, since Flutter looks up
  /// the nearest ancestor Navigator — so sub-pages open on top of the
  /// tab content while the bottom nav bar (which lives on the outer
  /// Scaffold, outside this Navigator) stays put.
  final GlobalKey<NavigatorState> _bodyNavigatorKey =
      GlobalKey<NavigatorState>();

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
    if (state != AppLifecycleState.resumed || _selectedIndex != 0) return;

    // Chrome fires `resumed` on every window focus change, which otherwise
    // means four fresh requests each time the user clicks away and back.
    final now = DateTime.now();
    if (_lastResumeRefresh != null &&
        now.difference(_lastResumeRefresh!) < const Duration(seconds: 30)) {
      return;
    }
    _lastResumeRefresh = now;

    _loadCredits(silent: true);
    _loadPendingApplications(silent: true);
    _loadApprovedApplications(silent: true);
    _loadEmploymentStatus();
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

    // TEMPORARY DIAGNOSTIC — remove once the data-loading issue is fixed.
    debugPrint(
      'LOAD CREDITS: hasToken=${token != null} employeeId=${auth.employeeId}',
    );

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

      // TEMPORARY DIAGNOSTIC — shows what the API actually returned.
      debugPrint('LOAD CREDITS RESULT: $result');

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
    } catch (e, st) {
      // TEMPORARY DIAGNOSTIC — the old bare `catch (_)` reported every
      // failure as a network error, which hid parse/cast/HTTP failures.
      debugPrint('LOAD CREDITS FAILED: $e');
      debugPrint('$st');

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
    if (auth.token == null || auth.employeeId == null) {
      debugPrint(
        'SKIPPED EMPLOYMENT STATUS: token=${auth.token != null} '
        'employeeId=${auth.employeeId}',
      );
      return;
    }

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
    } catch (e) {
      debugPrint('LOAD PENDING FAILED: $e');
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
    } catch (e) {
      debugPrint('LOAD APPROVED FAILED: $e');
    }
  }

  Future<void> _viewPendingPdf(int applicationId) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;
    if (token == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: AppColors.navy)),
    );

    try {
      final result = await LeaveApplicationService.getApplicationPdfBytes(
        applicationId: applicationId,
        token: token,
      ).timeout(_networkTimeout);

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (result['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Unable to load PDF.')),
        );
        return;
      }

      final rawBytes = result['bytes'];
      final Uint8List bytes = rawBytes is Uint8List
          ? rawBytes
          : Uint8List.fromList(List<int>.from(rawBytes as List));
      if (!mounted) return;
      // _bodyNavigatorKey.currentState?.push(
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) =>
              PdfViewOnlyPage(bytes: bytes, title: 'Leave Application'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request timed out. Please try again.')),
      );
    }
  }

  /// Withdraws a still-pending application. Pending applications never
  /// deducted credits, so there is nothing to restore — the backend just
  /// flips the status and writes an activity log entry.
  Future<void> _cancelApplication(int applicationId) async {
    if (_cancellingId != null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel this request?', style: AppText.display(size: 17)),
        content: Text(
          'This cannot be undone. You can file a new application afterwards.',
          style: AppText.body(size: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Keep it',
              style: AppText.body(
                size: 13,
                weight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Cancel request',
              style: AppText.body(
                size: 13,
                weight: FontWeight.w700,
                color: AppColors.red,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;
    if (token == null) return;

    setState(() => _cancellingId = applicationId);

    try {
      final result = await LeaveApplicationService.cancelApplication(
        applicationId: applicationId,
        token: token,
      ).timeout(_networkTimeout);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Done.')),
      );

      if (result['success'] == true) {
        await _loadPendingApplications();
        await _loadCredits(silent: true);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request timed out. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _cancellingId = null);
    }
  }

  Future<void> _goToApplyLeave() async {
    final credits = extractCreditsList(_creditData);

    setState(() => _isApplyOpen = true);
    final result = await _bodyNavigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (context) => ApplyForLeave(leaveTypes: credits),
      ),
    );
    if (mounted) setState(() => _isApplyOpen = false);

    if (result != null) {
      await _loadCredits();
      await _loadPendingApplications();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Leave application submitted! It is pending for approval.',
              style: AppText.body(size: 13, color: Colors.white),
            ),
            backgroundColor: AppColors.green,
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

  /// Finds a credit entry by leave type name. Mirrors the exact lookup
  /// pattern already used in the leave-type card loop.
  Map<String, dynamic> _findCredit(List<dynamic> credits, String typeName) {
    for (final c in credits) {
      final name = (c["leave_type"] ?? c["name"] ?? "").toString();
      if (name == typeName) return c as Map<String, dynamic>;
    }
    return const {};
  }

  /// Computes remaining/total/used for one leave type using the same
  /// formula already applied per-card in _buildHomeContent — kept as a
  /// single source of truth so the overview and the cards can never
  /// show different numbers for the same data.
  Map<String, double> _statsForType(
    String typeName,
    List<dynamic> credits,
    Map<String, double> approvedUsedByType,
  ) {
    final credit = _findCredit(credits, typeName);
    final apiTotal = toDoubleOrZero(credit["total_credits"]);
    final apiRemaining = toDoubleOrZero(credit["remaining_balance"]);
    final isDynamic = _isDynamicLeaveType(typeName);
    final approvedUsed = approvedUsedByType[typeName] ?? 0;

    final effectiveTotal = isDynamic
        ? (apiTotal > 0 ? apiTotal : apiRemaining + approvedUsed)
        : _staticCapFor(typeName, apiTotal, apiRemaining);
    final usedForType = isDynamic
        ? approvedUsed
        : toDoubleOrZero(credit["used_credits"]);
    final effectiveRemaining = isDynamic
        ? apiRemaining
        : (apiTotal > 0
              ? apiRemaining
              : (effectiveTotal - usedForType).clamp(0.0, effectiveTotal));

    return {
      "remaining": effectiveRemaining,
      "total": effectiveTotal,
      "used": usedForType,
    };
  }

  String _fmtDays(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  Widget _overviewHeroStat({
    required String label,
    required IconData icon,
    required double remaining,
    required double total,
    required Color accent,
  }) {
    final pct = total > 0 ? (remaining / total).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 13),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(
                    size: 11,
                    weight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _fmtDays(remaining),
                style: AppText.display(
                  size: 23,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '/ ${_fmtDays(total)}d',
                style: AppText.body(
                  size: 11,
                  weight: FontWeight.w600,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 4,
              backgroundColor: Colors.white.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewPill({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: AppText.body(
                    size: 14,
                    weight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(
                    size: 10,
                    weight: FontWeight.w600,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader({
    required List<dynamic> credits,
    required int pendingCount,
    required Map<String, double> approvedUsedByType,
  }) {
    return AppHeader(
      title: 'Home',
      bottom: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Builder(
          builder: (context) {
            final vl = _statsForType(
              'Vacation Leave',
              credits,
              approvedUsedByType,
            );
            final sl = _statsForType('Sick Leave', credits, approvedUsedByType);
            final usedThisYear = (vl['used'] ?? 0) + (sl['used'] ?? 0);
            final year = _creditData?["year"]?.toString() ?? '';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'OVERVIEW',
                      style: AppText.eyebrow(size: 11, color: Colors.white60),
                    ),
                    if (year.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          year,
                          style: AppText.body(
                            size: 11,
                            weight: FontWeight.w700,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _overviewHeroStat(
                        label: 'Vacation Leave',
                        icon: Icons.flight_takeoff_rounded,
                        remaining: vl['remaining'] ?? 0,
                        total: vl['total'] ?? 0,
                        accent: AppColors.amber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _overviewHeroStat(
                        label: 'Sick Leave',
                        icon: Icons.medical_services_outlined,
                        remaining: sl['remaining'] ?? 0,
                        total: sl['total'] ?? 0,
                        accent: AppColors.teal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _overviewPill(
                        icon: Icons.event_busy_rounded,
                        label: 'Used this year',
                        value: '${_fmtDays(usedThisYear)}d',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _overviewPill(
                        icon: Icons.pending_actions_rounded,
                        label: 'Pending',
                        value: '$pendingCount',
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, {String? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppText.display(size: 17, weight: FontWeight.w600)),
        if (trailing != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.navy.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              trailing,
              style: AppText.body(
                size: 11.5,
                weight: FontWeight.w700,
                color: AppColors.navy.withOpacity(0.7),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHomeContent() {
    final credits = extractCreditsList(_creditData);
    final approvedUsedByType = _approvedUsedByType();

    return RefreshIndicator(
      onRefresh: () async {
        await _loadCredits();
        await _loadPendingApplications();
        await _loadApprovedApplications();
        await _loadEmploymentStatus();
      },
      color: AppColors.navy,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildWelcomeHeader(
            credits: credits,
            pendingCount: _pendingApplications.length,
            approvedUsedByType: approvedUsedByType,
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 70),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.navy),
              ),
            )
          else if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.withOpacity(0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                        style: AppText.body(
                          size: 13,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
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

                        final usedForType = isDynamic
                            ? approvedUsed
                            : toDoubleOrZero(credit["used_credits"]);
                        final effectiveRemaining = isDynamic
                            ? apiRemaining
                            : (apiTotal > 0
                                  ? apiRemaining
                                  : (effectiveTotal - usedForType).clamp(
                                      0.0,
                                      effectiveTotal,
                                    ));

                        return SizedBox(
                          width: _leaveTypeCardWidth,
                          child: LeaveTypeCard(
                            leaveType: leaveTypeName,
                            remaining: effectiveRemaining,
                            total: effectiveTotal,
                            used: usedForType,
                            accentColor: AppColors
                                .accents[index % AppColors.accents.length],
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
                        child: CircularProgressIndicator(color: AppColors.navy),
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
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.hairline),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.navy.withOpacity(0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.navy.withOpacity(0.06),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.task_alt_rounded,
                              color: AppColors.navy.withOpacity(0.55),
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No pending requests',
                            style: AppText.body(
                              size: 13,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "You're all caught up.",
                            style: AppText.body(
                              size: 11.5,
                              weight: FontWeight.w500,
                              color: AppColors.muted.withOpacity(0.7),
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
                            _pendingApplications[index] as Map<String, dynamic>;
                        final leaveType = app['leave_type_name'] ?? 'Leave';
                        final days = app['days_applied']?.toString() ?? '0';
                        final start = formatIsoDate(
                          app['start_date']?.toString(),
                        );
                        final end = formatIsoDate(app['end_date']?.toString());
                        final id = app['id'];
                        final dotColor =
                            AppColors.accents[index % AppColors.accents.length];

                        return Material(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: id == null
                                ? null
                                : () => _viewPendingPdf(id as int),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.hairline),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.navy.withOpacity(0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
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
                                          style: AppText.body(
                                            size: 14,
                                            weight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '$start – $end · $days day(s)',
                                          style: AppText.body(
                                            size: 12,
                                            weight: FontWeight.w500,
                                            color: AppColors.muted,
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
                                      color: AppColors.amber.withOpacity(0.14),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Pending',
                                      style: AppText.body(
                                        size: 10,
                                        weight: FontWeight.w700,
                                        color: const Color(0xFF8A5A16),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  if (_cancellingId == id)
                                    const SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: Padding(
                                        padding: EdgeInsets.all(8),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.navy,
                                        ),
                                      ),
                                    )
                                  else
                                    PopupMenuButton<String>(
                                      icon: const Icon(
                                        Icons.more_vert_rounded,
                                        color: AppColors.muted,
                                        size: 18,
                                      ),
                                      padding: EdgeInsets.zero,
                                      splashRadius: 18,
                                      tooltip: 'Options',
                                      onSelected: (value) {
                                        if (id == null) return;
                                        if (value == 'pdf') {
                                          _viewPendingPdf(id as int);
                                        } else if (value == 'cancel') {
                                          _cancelApplication(id as int);
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        PopupMenuItem(
                                          value: 'pdf',
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.picture_as_pdf_outlined,
                                                size: 17,
                                                color: AppColors.muted,
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                'View leave form',
                                                style: AppText.body(size: 13),
                                              ),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'cancel',
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.cancel_outlined,
                                                size: 17,
                                                color: AppColors.red,
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                'Cancel request',
                                                style: AppText.body(
                                                  size: 13,
                                                  weight: FontWeight.w600,
                                                  color: AppColors.red,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // If a sub-page is open (e.g. Apply for Leave, or something
        // pushed from within Profile/Monetize/Logs), let back close
        // that first instead of leaving the app/tab.
        final navigator = _bodyNavigatorKey.currentState;
        if (navigator != null && navigator.canPop()) {
          navigator.pop();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: null,
        bottomNavigationBar: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          height: 68,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.navyDark.withOpacity(0.10),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _bottomNavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  index: 0,
                ),
              ),
              Expanded(
                child: _bottomNavItem(
                  icon: Icons.payments_outlined,
                  label: 'Monetize',
                  index: 1,
                ),
              ),
              Expanded(child: _applyNavItem()),
              Expanded(
                child: _bottomNavItem(
                  icon: Icons.history_rounded,
                  label: 'History',
                  index: 3,
                ),
              ),
              Expanded(
                child: _bottomNavItem(
                  icon: Icons.person_outline_rounded,
                  label: 'Profile',
                  index: 2,
                ),
              ),
            ],
          ),
        ),
        // Nested Navigator scoped to just the tab content. Any
        // Navigator.push(context, ...) called by a widget inside this
        // subtree (ProfilePage, ApplyForLeaveMonetization, LeaveLogsPage,
        // and their descendants) resolves to THIS Navigator, not the
        // app's root one — so their sub-pages open here, on top of the
        // tab content, while the bottomNavigationBar above (which
        // belongs to the outer Scaffold) stays visible.
        body: Navigator(
          key: _bodyNavigatorKey,
          onGenerateRoute: (settings) => MaterialPageRoute(
            builder: (context) => IndexedStack(
              index: _selectedIndex,
              children: [
                _buildHomeContent(),
                ApplyForLeaveMonetization(isActive: _selectedIndex == 1),
                ProfilePage(isActive: _selectedIndex == 2),
                LeaveLogsPage(isActive: _selectedIndex == 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Pops any sub-page open in the tab-content Navigator (e.g. Apply for
  /// Leave) back to the IndexedStack. Without this, tapping a tab changes
  /// _selectedIndex underneath a pushed page that's still covering it —
  /// so nothing appears to happen until the user hits back manually.
  void _popToTabRoot() {
    final navigator = _bodyNavigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }
  }

  Widget _applyNavItem() {
    return GestureDetector(
      onTap: () {
        _popToTabRoot();
        _goToApplyLeave();
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 68,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.amber,
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Apply',
              style: AppText.body(
                size: 10,
                weight: FontWeight.w800,
                color: AppColors.amber,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index && !_isApplyOpen;
    final color = isSelected
        ? AppColors.navy
        : AppColors.muted.withOpacity(0.7);
    return GestureDetector(
      onTap: () {
        _popToTabRoot();
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
      child: SizedBox(
        height: 68,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: AppText.body(
                size: 10,
                weight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
