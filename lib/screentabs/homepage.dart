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
  bool _isLoadingPending = true;

  Timer? _refreshTimer;
  static const Duration _networkTimeout = Duration(seconds: 10);
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
    _loadEmploymentStatus();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (!mounted) return;
      _loadCredits(silent: true);
      _loadEmploymentStatus();
    });
    _pendingRefreshTimer = Timer.periodic(_pendingRefreshInterval, (_) {
      if (!mounted) return;
      _loadPendingApplications(silent: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadCredits(silent: true);
      _loadPendingApplications(silent: true);
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
    required double totalDays,
    required double usedDays,
    required double remaining,
    required int pendingCount,
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
                totalDays: totalDays,
                usedDays: usedDays,
                remaining: remaining,
                pendingCount: pendingCount,
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

    final totalDays = credits.fold(0.0, (sum, c) => sum + _toDouble(c["total_credits"]));
    final usedDays = credits.fold(0.0, (sum, c) => sum + _toDouble(c["used_credits"]));
    final remaining = totalDays - usedDays;

    return RefreshIndicator(
      onRefresh: () async {
        await _loadCredits();
        await _loadPendingApplications();
        await _loadEmploymentStatus();
      },
      color: Colors.deepPurple,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildWelcomeHeader(
            user,
            totalDays: totalDays,
            usedDays: usedDays,
            remaining: remaining,
            pendingCount: _pendingApplications.length,
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
                        return SizedBox(
                          width: _leaveTypeCardWidth,
                          child: LeaveTypeCard(
                            leaveType: credit["leave_type"] ?? credit["name"] ?? "",
                            remaining: _toDouble(credit["remaining_balance"]),
                            total: _toDouble(credit["total_credits"]),
                            used: _toDouble(credit["used_credits"]),
                            accentColor: _accentColors[index % _accentColors.length],
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
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeContent(),
          const ProfilePage(),
        ],
      ),
    );
  }

  Widget _bottomNavItem({required IconData icon, required String label, required int index}) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
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