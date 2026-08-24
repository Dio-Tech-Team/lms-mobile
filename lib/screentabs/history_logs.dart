import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_providers.dart';
import '../services/leave_application_service.dart';
import '../widgets/pdf_view_page.dart';
import '../utils/employee_app_utils.dart';

class LeaveLogsPage extends StatefulWidget {
  final bool isActive;
  const LeaveLogsPage({super.key, this.isActive = true});

  @override
  State<LeaveLogsPage> createState() => _LeaveLogsPageState();
}

class _LeaveLogsPageState extends State<LeaveLogsPage>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _leaveLogs = [];
  bool _isLoading = true;
  String? _errorMessage;

  Timer? _refreshTimer;
  static const Duration _networkTimeout = Duration(seconds: 10);
  static const Duration _refreshInterval = Duration(seconds: 20);

  static const Color _navyDark = Color(0xFF13224A);
  static const Color _navy = Color(0xFF1B3B63);
  static const Color _muted = Color(0xFF8A97A8);
  static const Color _bg = Color(0xFFF3F5F9);
  static const Color _hairline = Color(0xFFEDEFF4);
  static const Color _green = Color(0xFF3A8C5C);
  static const Color _red = Color(0xFFD94F70);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.isActive) {
      _loadLogs();
      _startTimer();
    }
  }

  void _startTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (mounted) _loadLogs(silent: true);
    });
  }

  void _stopTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void didUpdateWidget(covariant LeaveLogsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _loadLogs(silent: true);
        _startTimer();
      } else {
        _stopTimer();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && widget.isActive) {
      _loadLogs(silent: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLogs({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;

    if (token == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (!silent) {
          _errorMessage = 'You are not logged in.';
        }
      });
      return;
    }

    try {
      final results = await Future.wait([
        LeaveApplicationService.getMyApplications(
          token: token,
          status: 'approved',
        ).timeout(_networkTimeout),
        LeaveApplicationService.getMyApplications(
          token: token,
          status: 'cancelled',
        ).timeout(_networkTimeout),
      ]).timeout(_networkTimeout + const Duration(seconds: 2));

      final approvedResult = results[0];
      final cancelledResult = results[1];

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
        _leaveLogs = logs;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (!silent) {
          _errorMessage = 'Something went wrong loading your leave logs.';
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
        child: CircularProgressIndicator(color: _navy),
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

  int get _approvedCount => _leaveLogs
      .where((l) => (l['status'] ?? '').toString().toLowerCase() == 'approved')
      .length;
  int get _cancelledCount => _leaveLogs
      .where((l) => (l['status'] ?? '').toString().toLowerCase() == 'cancelled')
      .length;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: RefreshIndicator(
        onRefresh: () => _loadLogs(),
        color: _navy,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'History',
                        style: GoogleFonts.fraunces(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: _navyDark,
                        ),
                      ),
                      if (!_isLoading && _errorMessage == null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _navyDark.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_leaveLogs.length}',
                            style: GoogleFonts.nunito(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: _navyDark.withOpacity(0.7),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: CircularProgressIndicator(color: _navy),
                      ),
                    )
                  else if (_errorMessage != null)
                    _buildErrorState()
                  else if (_leaveLogs.isEmpty)
                    _buildEmptyState()
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
          colors: [_navyDark, _navy],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
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
                    child: const Icon(
                      Icons.history_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Leave Request Logs',
                          style: GoogleFonts.fraunces(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Approved and cancelled applications',
                          style: GoogleFonts.nunito(
                            color: Colors.white60,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _summaryPill(
                      icon: Icons.check_circle_rounded,
                      value: _isLoading ? '—' : '$_approvedCount',
                      label: 'Approved',
                      color: const Color(0xFF6FE3A6),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _summaryPill(
                      icon: Icons.cancel_rounded,
                      value: _isLoading ? '—' : '$_cancelledCount',
                      label: 'Cancelled',
                      color: const Color(0xFFEF95A6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryPill({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.fraunces(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.nunito(
                  color: Colors.white54,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEAEA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, color: _red, size: 24),
          const SizedBox(height: 10),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              color: const Color(0xFFB23A50),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _hairline),
      ),
      child: Column(
        children: [
          Icon(
            Icons.folder_open_rounded,
            color: _muted.withOpacity(0.5),
            size: 30,
          ),
          const SizedBox(height: 10),
          Text(
            'No history yet',
            style: GoogleFonts.nunito(
              color: _muted,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Approved or cancelled requests will show up here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              color: _muted.withOpacity(0.7),
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveLogTile(Map<String, dynamic> item) {
    final status = (item['status'] ?? '').toString().toLowerCase();
    final isApproved = status == 'approved';
    final accent = isApproved ? _green : _red;
    final leaveType = item['leave_type_name']?.toString() ?? 'Leave';
    final start = formatIsoDate(
      item['start_date']?.toString(),
      placeholder: '—',
    );
    final end = formatIsoDate(item['end_date']?.toString(), placeholder: '—');
    final days = item['days_applied']?.toString() ?? '0';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isApproved ? () => _viewPdf(item['id']) : null,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _hairline),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isApproved
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            color: accent,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                leaveType,
                                style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: _navyDark,
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
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isApproved ? 'Approved' : 'Cancelled',
                                style: GoogleFonts.nunito(
                                  color: accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Icon(
                              isApproved
                                  ? Icons.picture_as_pdf_outlined
                                  : Icons.block_rounded,
                              size: 15,
                              color: isApproved
                                  ? _muted
                                  : _muted.withOpacity(0.5),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}