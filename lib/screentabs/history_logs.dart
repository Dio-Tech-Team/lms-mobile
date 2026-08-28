import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_providers.dart';
import '../services/leave_application_service.dart';
import '../widgets/pdf_view_page.dart';
import '../utils/employee_app_utils.dart';
import '../utils/app_theme.dart';

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

  /// 'all' | 'approved' | 'cancelled'
  String _filter = 'all';

  Timer? _refreshTimer;
  static const Duration _networkTimeout = Duration(seconds: 30);
  static const Duration _refreshInterval = Duration(seconds: 60);

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
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: AppColors.navy)),
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

  /// Total approved days this year — the one number an employee actually
  /// wants off this screen, and the reason the header now exists.
  double get _daysTakenThisYear {
    final year = DateTime.now().year;
    double total = 0;
    for (final log in _leaveLogs) {
      if ((log['status'] ?? '').toString().toLowerCase() != 'approved') {
        continue;
      }
      final start = DateTime.tryParse(log['start_date']?.toString() ?? '');
      if (start == null || start.year != year) continue;
      total += double.tryParse(log['days_applied']?.toString() ?? '') ?? 0;
    }
    return total;
  }

  List<Map<String, dynamic>> get _visibleLogs {
    if (_filter == 'all') return _leaveLogs;
    return _leaveLogs
        .where((l) => (l['status'] ?? '').toString().toLowerCase() == _filter)
        .toList();
  }

  String _fmtDays(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  /// Turns the API's raw decimal ('2.000') into '2 days' / '1 day' / '0.5 day'.
  String _formatDays(dynamic raw) {
    final v = double.tryParse(raw?.toString() ?? '') ?? 0;
    return '${_fmtDays(v)} ${v == 1 ? 'day' : 'days'}';
  }

  static const List<String> _monthAbbr = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// 'Sep 2 – 5, 2026' when same month, 'Sep 28 – Oct 3, 2026' across months,
  /// 'Sep 2, 2026' for a single day. Falls back to the raw strings if unparseable.
  String _dateRange(String? startRaw, String? endRaw) {
    final s = DateTime.tryParse(startRaw ?? '');
    final e = DateTime.tryParse(endRaw ?? '');
    if (s == null || e == null) {
      return '${formatIsoDate(startRaw, placeholder: '—')} – '
          '${formatIsoDate(endRaw, placeholder: '—')}';
    }
    final sm = _monthAbbr[s.month - 1];
    final em = _monthAbbr[e.month - 1];
    if (s.year == e.year && s.month == e.month && s.day == e.day) {
      return '$sm ${s.day}, ${s.year}';
    }
    if (s.year == e.year && s.month == e.month) {
      return '$sm ${s.day} – ${e.day}, ${s.year}';
    }
    if (s.year == e.year) {
      return '$sm ${s.day} – $em ${e.day}, ${s.year}';
    }
    return '$sm ${s.day}, ${s.year} – $em ${e.day}, ${e.year}';
  }

  /// Groups visible logs by the month they were applied in, preserving the
  /// newest-first order already established by the sort in _loadLogs().
  List<MapEntry<String, List<Map<String, dynamic>>>> _groupedLogs() {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final log in _visibleLogs) {
      final applied = DateTime.tryParse(log['applied_at']?.toString() ?? '');
      final key = applied == null
          ? 'Earlier'
          : '${_monthAbbr[applied.month - 1]} ${applied.year}';
      groups.putIfAbsent(key, () => []).add(log);
    }
    return groups.entries.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg,
      child: RefreshIndicator(
        onRefresh: () => _loadLogs(),
        color: AppColors.navy,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_isLoading && _errorMessage == null) ...[
                    _buildSegmentedFilter(),
                    const SizedBox(height: 20),
                  ],
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.navy),
                      ),
                    )
                  else if (_errorMessage != null)
                    _buildErrorState()
                  else if (_visibleLogs.isEmpty)
                    _buildEmptyState()
                  else
                    ..._buildGroupedList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroupedList() {
    final widgets = <Widget>[];
    final groups = _groupedLogs();

    for (int g = 0; g < groups.length; g++) {
      final entry = groups[g];
      if (g > 0) widgets.add(const SizedBox(height: 22));
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(entry.key.toUpperCase(), style: AppText.eyebrow()),
        ),
      );
      for (int i = 0; i < entry.value.length; i++) {
        if (i > 0) widgets.add(const SizedBox(height: 8));
        widgets.add(_buildLeaveLogTile(entry.value[i]));
      }
    }
    return widgets;
  }

  // ---------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------

  /// Matches Home's gradient + glass-card treatment so the two screens read
  /// as one app. The summary strip replaces the counts that used to sit
  /// inside the filter chips, which left the control doing two jobs at once.
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x38131F3A),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Leave History',
                style: AppText.display(
                  size: 26,
                  weight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Every request that has been settled.',
                style: AppText.body(
                  size: 12.5,
                  weight: FontWeight.w500,
                  color: Colors.white60,
                ),
              ),
              if (!_isLoading && _errorMessage == null) ...[
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _headerStat(
                        icon: Icons.event_available_rounded,
                        value: '${_fmtDays(_daysTakenThisYear)}d',
                        label: 'Taken in ${DateTime.now().year}',
                        accent: AppColors.amber,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _headerStat(
                        icon: Icons.check_circle_outline_rounded,
                        value: '$_approvedCount',
                        label: 'Approved',
                        accent: AppColors.teal,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _headerStat(
                        icon: Icons.cancel_outlined,
                        value: '$_cancelledCount',
                        label: 'Cancelled',
                        accent: AppColors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerStat({
    required IconData icon,
    required String value,
    required String label,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: accent),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppText.display(
              size: 19,
              weight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.body(
              size: 10.5,
              weight: FontWeight.w600,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Filter
  // ---------------------------------------------------------------------

  /// One connected control rather than three free-floating pills — reads as
  /// a view switcher instead of three tappable buttons of equal weight.
  /// Counts moved to the header, so each segment is now just a label.
  Widget _buildSegmentedFilter() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Expanded(child: _segment('All', 'all')),
          Expanded(child: _segment('Approved', 'approved')),
          Expanded(child: _segment('Cancelled', 'cancelled')),
        ],
      ),
    );
  }

  Widget _segment(String label, String value) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.navyDark : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: AppText.body(
            size: 12.5,
            weight: FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.muted,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // States
  // ---------------------------------------------------------------------

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
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.red,
            size: 24,
          ),
          const SizedBox(height: 10),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: AppText.body(size: 13, color: const Color(0xFFB23A50)),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _loadLogs(),
            child: Text(
              'Try again',
              style: AppText.body(
                size: 12.5,
                weight: FontWeight.w800,
                color: const Color(0xFFB23A50),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final message = _filter == 'all'
        ? 'Approved and cancelled requests land here once they are settled.'
        : 'No $_filter requests yet.';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.navyDark.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.inbox_rounded,
              color: AppColors.navyDark.withOpacity(0.3),
              size: 26,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Nothing here yet',
            style: AppText.display(
              size: 15,
              weight: FontWeight.w600,
              color: AppColors.navyDark.withOpacity(0.75),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppText.body(
              size: 12.5,
              weight: FontWeight.w500,
              color: AppColors.muted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Tile
  // ---------------------------------------------------------------------

  Widget _buildLeaveLogTile(Map<String, dynamic> item) {
    final status = (item['status'] ?? '').toString().toLowerCase();
    final isApproved = status == 'approved';
    final accent = isApproved ? AppColors.green : AppColors.red;
    final leaveType = item['leave_type_name']?.toString() ?? 'Leave';

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isApproved ? () => _viewPdf(item['id']) : null,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // A full-height status rail instead of a small dot — the
              // approved/cancelled split is the primary thing being scanned,
              // so it gets an edge the eye can run down.
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              leaveType,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body(
                                size: 14.5,
                                weight: FontWeight.w800,
                                color: AppColors.navyDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isApproved ? 'Approved' : 'Cancelled',
                              style: AppText.body(
                                size: 10.5,
                                weight: FontWeight.w800,
                                color: accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 11),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 13,
                            color: AppColors.muted.withOpacity(0.8),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              _dateRange(
                                item['start_date']?.toString(),
                                item['end_date']?.toString(),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body(
                                size: 12.5,
                                color: AppColors.navyDark.withOpacity(0.75),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.bg,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              _formatDays(item['days_applied']),
                              style: AppText.body(
                                size: 11,
                                weight: FontWeight.w700,
                                color: AppColors.navyDark.withOpacity(0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (isApproved) ...[
                        const SizedBox(height: 11),
                        Container(height: 1, color: AppColors.hairline),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              Icons.description_outlined,
                              size: 13,
                              color: AppColors.navy.withOpacity(0.7),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              'View leave form',
                              style: AppText.body(
                                size: 12,
                                weight: FontWeight.w700,
                                color: AppColors.navy.withOpacity(0.8),
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 11,
                              color: AppColors.muted.withOpacity(0.7),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
