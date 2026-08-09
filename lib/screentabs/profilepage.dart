import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'dart:convert';

import '../providers/auth_providers.dart';
import '../services/leave_application_service.dart';
import '../services/leave_credit_service.dart';
import '../widgets/leave_balance_card.dart';
import '../users/login_page.dart';
import '../variables.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _employee;
  List<Map<String, dynamic>> _leaveLogs = [];
  Map<String, dynamic>? _creditData;
  bool _isLoading = true;
  String? _errorMessage;

  static const Color _navy = Color(0xFF1E3A5F);
  static const Color _muted = Color(0xFF8A97A8);

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;
    final employeeId = auth.employeeId;

    if (token == null || employeeId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No employee record linked to your account.';
      });
      return;
    }

    try {
      final results = await Future.wait([
        _fetchEmployee(token: token, employeeId: employeeId),
        LeaveApplicationService.getMyApplications(token: token, status: 'approved'),
        LeaveApplicationService.getMyApplications(token: token, status: 'cancelled'),
        LeaveCreditService.getCredits(token),
      ]);

      final employeeResult = results[0] as Map<String, dynamic>;
      final approvedResult = results[1] as Map<String, dynamic>;
      final cancelledResult = results[2] as Map<String, dynamic>;
      final creditResult = results[3] as Map<String, dynamic>;

      if (employeeResult['success'] != true) {
        setState(() {
          _isLoading = false;
          _errorMessage = employeeResult['message'] ?? 'Failed to load profile.';
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
        final da = DateTime.tryParse(a['applied_at']?.toString() ?? '') ?? DateTime(1970);
        final db = DateTime.tryParse(b['applied_at']?.toString() ?? '') ?? DateTime(1970);
        return db.compareTo(da);
      });

      if (!mounted) return;
      setState(() {
        _employee = employeeResult['data'];
        _leaveLogs = logs;
        _creditData = creditResult['success'] == true ? creditResult['data'] : null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Something went wrong loading your profile.';
      });
    }
  }

  Future<Map<String, dynamic>> _fetchEmployee({
    required String token,
    required int employeeId,
  }) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/employees/$employeeId'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(res.body)};
      }
      return {'success': false, 'message': 'Failed to load profile (${res.statusCode})'};
    } catch (e) {
      return {'success': false, 'message': 'Network error while loading profile.'};
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
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.deepPurple)),
    );

    final result = await LeaveApplicationService.getApplicationPdfBytes(
      applicationId: applicationId is int ? applicationId : int.parse(applicationId.toString()),
      token: token,
    );

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

  String _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '—';
    try {
      final date = DateTime.parse(isoDate);
      return '${date.month.toString().padLeft(2, '0')}/'
          '${date.day.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return isoDate;
    }
  }

  String _fullName() {
    if (_employee == null) return '';
    final first = _employee!['first_name'] ?? '';
    final middle = _employee!['middle_name'];
    final last = _employee!['surname'] ?? '';
    final middleInitial =
        (middle is String && middle.isNotEmpty) ? '${middle[0]}.' : '';
    return [first, middleInitial, last]
        .where((s) => s.toString().trim().isNotEmpty)
        .join(' ');
  }

  String _initials() {
    if (_employee == null) return '';
    final first = (_employee!['first_name'] ?? '').toString();
    final last = (_employee!['surname'] ?? '').toString();
    final a = first.isNotEmpty ? first[0] : '';
    final b = last.isNotEmpty ? last[0] : '';
    return (a + b).toUpperCase();
  }

  String _titleCase(String? value) {
    if (value == null || value.isEmpty) return '—';
    return value
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  double _toDouble(dynamic value) =>
      double.tryParse(value?.toString() ?? '0') ?? 0.0;

  @override
  Widget build(BuildContext context) {
    final List<dynamic> credits = () {
      if (_creditData is Map) {
        if (_creditData!["credits"] is List) return _creditData!["credits"];
        if (_creditData!["data"] is List) return _creditData!["data"];
      }
      return <dynamic>[];
    }();

    final totalDays = credits.fold(0.0, (sum, c) => sum + _toDouble(c["total_credits"]));
    final usedDays = credits.fold(0.0, (sum, c) => sum + _toDouble(c["used_credits"]));
    final remaining = totalDays - usedDays;
    final overallProgress = totalDays > 0 ? (usedDays / totalDays).clamp(0.0, 1.0) : 0.0;

    return RefreshIndicator(
      onRefresh: _loadAll,
      color: Colors.deepPurple,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHeader(),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator(color: Colors.deepPurple)),
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Employee info now comes first...
                  _buildInfoCard(),
                  const SizedBox(height: 24),
                  // ...followed by the leave balance card.
                  if (_creditData != null) ...[
                    LeaveBalanceCard(
                      totalDays: totalDays,
                      usedDays: usedDays,
                      remaining: remaining,
                      overallProgress: overallProgress,
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
                      itemBuilder: (context, index) => _buildLeaveLogTile(_leaveLogs[index]),
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
                    onPressed: _handleLogout,
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
                    border: Border.all(color: Colors.white.withOpacity(0.35), width: 2),
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
                  style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Text(
                    _titleCase(_employee?['employment_status']?.toString()),
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
          _infoRow('Date Hired', _formatDate(_employee?['date_hired']?.toString())),
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
    final start = _formatDate(item['start_date']?.toString());
    final end = _formatDate(item['end_date']?.toString());
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
                  isApproved ? Icons.picture_as_pdf_outlined : Icons.block_rounded,
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