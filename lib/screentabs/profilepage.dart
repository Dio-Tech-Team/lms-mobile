import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_providers.dart';
import '../services/leave_application_service.dart';
import '../services/leave_credit_service.dart';
import '../widgets/leave_balance_card.dart';
import '../widgets/pdf_view_page.dart';
import '../utils/employee_app_utils.dart';

class ProfilePage extends StatefulWidget {
  final bool isActive;
  const ProfilePage({super.key, this.isActive = true});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with WidgetsBindingObserver {
  Map<String, dynamic>? _employee;
  List<Map<String, dynamic>> _leaveLogs = [];
  Map<String, dynamic>? _creditData;
  bool _isLoading = true;
  String? _errorMessage;

  Timer? _refreshTimer;
  static const Duration _networkTimeout = Duration(seconds: 10);
  static const Duration _refreshInterval = Duration(seconds: 20);

  static const Color _navy = Color(0xFF1E3A5F);
  static const Color _muted = Color(0xFF8A97A8);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Only fetch/poll if this tab is actually visible. IndexedStack builds
    // this widget immediately even when it's not the selected tab, so
    // without this guard we'd fire a network request on app start before
    // the user ever opens Profile.
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

      final results = await Future.wait([
        LeaveApplicationService.getMyApplications(
          token: token,
          status: 'approved',
        ).timeout(_networkTimeout),
        LeaveApplicationService.getMyApplications(
          token: token,
          status: 'cancelled',
        ).timeout(_networkTimeout),
        LeaveCreditService.getCredits(token).timeout(_networkTimeout),
      ]).timeout(_networkTimeout + const Duration(seconds: 2));

      final approvedResult = results[0] as Map<String, dynamic>;
      final cancelledResult = results[1] as Map<String, dynamic>;
      final creditResult = results[2] as Map<String, dynamic>;

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

      final List<Map<String, dynamic>> logs = [
        if (approvedResult['success'] == true)
          ...List<Map<String, dynamic>>.from(approvedResult['data'] ?? []),
        if (cancelledResult['success'] == true)
          ...List<Map<String, dynamic>>.from(cancelledResult['data'] ?? []),
      ];

      logs.sort((a, b) {
        final da =
            DateTime.tryParse(a['applied_at']?.toString() ?? '') ??
            DateTime(1970);
        final db =
            DateTime.tryParse(b['applied_at']?.toString() ?? '') ??
            DateTime(1970);
        return db.compareTo(da);
      });

      if (!mounted) return;
      setState(() {
        _employee = auth.employee;
        _leaveLogs = logs;
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

  Future<void> _viewPdf(dynamic applicationId) async {
    if (applicationId == null) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;
    if (token == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.deepPurple),
      ),
    );

    try {
      final result = await LeaveApplicationService.getApplicationPdfBytes(
        applicationId: applicationId is int
            ? applicationId
            : int.parse(applicationId.toString()),
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

      final rawBytes = result['bytes'];
      final Uint8List bytes = rawBytes is Uint8List
          ? rawBytes
          : Uint8List.fromList(List<int>.from(rawBytes as List));
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PdfViewOnlyPage(bytes: bytes, title: 'Leave Application'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request timed out. Please try again.')),
      );
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

    double _vlSlField(dynamic entry, String field) =>
        entry != null ? toDoubleOrZero(entry[field]) : 0.0;
    final vlTotal = _vlSlField(vlEntry, "total_credits") > 0
        ? _vlSlField(vlEntry, "total_credits")
        : _vlSlField(vlEntry, "remaining_balance");
    final slTotal = _vlSlField(slEntry, "total_credits") > 0
        ? _vlSlField(slEntry, "total_credits")
        : _vlSlField(slEntry, "remaining_balance");

    final totalDays = vlTotal + slTotal;
    final usedDays =
        _vlSlField(vlEntry, "used_credits") +
        _vlSlField(slEntry, "used_credits");
    final remaining = totalDays - usedDays;
    final overallProgress = totalDays > 0
        ? (usedDays / totalDays).clamp(0.0, 1.0)
        : 0.0;
    final vlMonetizable = _vlSlField(vlEntry, "remaining_balance");

    return RefreshIndicator(
      onRefresh: () => _loadAll(),
      color: Colors.deepPurple,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHeader(),
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
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(),
                  const SizedBox(height: 24),
                  if (_creditData != null) ...[
                    LeaveBalanceCard(
                      totalDays: totalDays,
                      usedDays: usedDays,
                      remaining: remaining,
                      overallProgress: overallProgress,
                      vlMonetizable: vlMonetizable,
                      year: _creditData?["year"],
                      employeeName: _creditData?["employee"],
                    ),
                    const SizedBox(height: 24),
                  ],
                  const Text(
                    'Leave Request Logs',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: _navy,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_leaveLogs.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text(
                          'No approved or cancelled requests yet.',
                          style: TextStyle(color: _muted),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _leaveLogs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) =>
                          _buildLeaveLogTile(_leaveLogs[index]),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 28),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    onPressed: () => confirmAndLogout(context),
                  ),
                ],
              ),
              if (_employee != null) ...[
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.15),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.35),
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _initials(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _fullName(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _employee?['position']?.toString() ?? '',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Text(
                    titleCaseOrPlaceholder(
                      _employee?['employment_status']?.toString(),
                      placeholder: '—',
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow('ID Number', _employee?['id_number']),
          _infoRow('Position', _employee?['position']),
          _infoRow(
            'Date Hired',
            formatIsoDate(
              _employee?['date_hired']?.toString(),
              placeholder: '—',
            ),
          ),
          _infoRow('Department', _employee?['department']),
          _infoRow('Email', _employee?['email']),
        ],
      ),
    );
  }

  Widget _infoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(color: _muted, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              (value ?? '—').toString(),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: _navy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveLogTile(Map<String, dynamic> item) {
    final status = (item['status'] ?? '').toString().toLowerCase();
    final isApproved = status == 'approved';
    final leaveType = item['leave_type_name']?.toString() ?? 'Leave';
    final start = formatIsoDate(
      item['start_date']?.toString(),
      placeholder: '—',
    );
    final end = formatIsoDate(item['end_date']?.toString(), placeholder: '—');
    final days = item['days_applied']?.toString() ?? '0';

    return InkWell(
      onTap: isApproved ? () => _viewPdf(item['id']) : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              isApproved ? Icons.check_circle : Icons.cancel,
              color: isApproved ? Colors.green : Colors.redAccent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    leaveType,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: _navy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$start – $end · $days day(s)',
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isApproved ? 'Approved' : 'Cancelled',
                  style: TextStyle(
                    color: isApproved ? Colors.green : Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Icon(
                  isApproved
                      ? Icons.picture_as_pdf_outlined
                      : Icons.block_rounded,
                  size: 15,
                  color: isApproved ? _muted : _muted.withOpacity(0.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}