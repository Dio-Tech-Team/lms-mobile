import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'dart:convert';

import '../providers/auth_providers.dart';
import '../services/leave_application_service.dart';
import '../variables.dart';

/// NOTE: This widget renders its own content only (no Scaffold/AppBar),
/// since HomePage already provides those and swaps this in as the body
/// when the Profile tab is selected.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _employee;
  List<Map<String, dynamic>> _leaveLogs = [];
  bool _isLoading = true;
  String? _errorMessage;

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
      ]);

      final employeeResult = results[0] as Map<String, dynamic>;
      final approvedResult = results[1] as Map<String, dynamic>;
      final cancelledResult = results[2] as Map<String, dynamic>;

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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      color: Colors.deepPurple,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildProfileCard(),
          const SizedBox(height: 24),
          const Text(
            'Leave Request Logs',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A5F),
            ),
          ),
          const SizedBox(height: 14),
          if (_leaveLogs.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text(
                  'No approved or cancelled leave requests yet.',
                  style: TextStyle(color: Color(0xFF8A97A8)),
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
    );
  }

  Widget _buildProfileCard() {
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
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.deepPurple.withOpacity(0.1),
                  child: const Icon(Icons.person, size: 40, color: Colors.deepPurple),
                ),
                const SizedBox(height: 12),
                Text(
                  _fullName(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
                Text(
                  _employee?['position']?.toString() ?? '',
                  style: const TextStyle(color: Color(0xFF8A97A8)),
                ),
              ],
            ),
          ),
          const Divider(height: 32),
          _infoRow('ID Number', _employee?['id_number']),
          _infoRow('Employment Status', _employee?['employment_status']),
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
              style: const TextStyle(color: Color(0xFF8A97A8), fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              (value ?? '—').toString(),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF1E3A5F),
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
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$start – $end · $days day(s)',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF8A97A8)),
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
                  color: isApproved
                      ? const Color(0xFF8A97A8)
                      : const Color(0xFF8A97A8).withOpacity(0.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}