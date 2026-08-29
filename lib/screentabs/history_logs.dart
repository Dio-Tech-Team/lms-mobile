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

  /// 'all' | 'approved' | 'rejected' | 'cancelled'
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
      // Rejected is fetched alongside approved and cancelled — without it an
      // employee whose request was denied sees nothing at all, and never
      // learns the reason HR recorded.
      final results = await Future.wait([
        LeaveApplicationService.getMyApplications(
          token: token,
          status: 'approved',
        ).timeout(_networkTimeout),
        LeaveApplicationService.getMyApplications(
          token: token,
          status: 'rejected',
        ).timeout(_networkTimeout),
        LeaveApplicationService.getMyApplications(
          token: token,
          status: 'cancelled',
        ).timeout(_networkTimeout),
      ]).timeout(_networkTimeout + const Duration(seconds: 2));

      final List<Map<String, dynamic>> logs = [
        for (final result in results)
          if (result['success'] == true)
            ...List<Map<String, dynamic>>.from(result['data'] ?? []),
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
      useRootNavigator: true,
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

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final logs = _visibleLogs;

    return Container(
      color: AppColors.bg,
      child: Column(
        children: [
          _buildHeader(),
          _buildFilterRow(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadLogs(),
              color: AppColors.navy,
              child: _buildBody(logs),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(List<Map<String, dynamic>> logs) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.navy),
      );
    }

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [_buildErrorState()],
      );
    }

    if (logs.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [_buildEmptyState()],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: logs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _buildLeaveLogTile(logs[i]),
    );
  }

  // ---------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
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
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Filter
  // ---------------------------------------------------------------------

  Widget _buildFilterRow() {
    return SizedBox(
      height: 58,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        children: [
          _chip('All', 'all'),
          _chip('Approved', 'approved'),
          _chip('Rejected', 'rejected'),
          _chip('Cancelled', 'cancelled'),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    final isSelected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _filter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.navyDark : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.navyDark : AppColors.hairline,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppText.body(
              size: 12.5,
              weight: FontWeight.w700,
              color: isSelected ? Colors.white : AppColors.muted,
            ),
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
        ? 'Settled requests land here once HR has reviewed them.'
        : 'No $_filter requests yet.';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
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

  Color _accentFor(String status) {
    switch (status) {
      case 'approved':
        return AppColors.green;
      case 'rejected':
        return AppColors.red;
      default:
        return AppColors.muted;
    }
  }

  String _labelFor(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Cancelled';
    }
  }

  IconData _iconFor(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      default:
        return Icons.remove_circle_rounded;
    }
  }

  /// Plain Column inside a plain Container. No stretch, no IntrinsicHeight,
  /// no mixed-colour border — every one of those needed a height the list
  /// could not give it. The status is carried by a coloured icon and badge
  /// instead of a full-height rail.
  Widget _buildLeaveLogTile(Map<String, dynamic> item) {
    final status = (item['status'] ?? '').toString().toLowerCase();
    final isApproved = status == 'approved';
    final isRejected = status == 'rejected';
    final accent = _accentFor(status);
    final leaveType = item['leave_type_name']?.toString() ?? 'Leave';
    final reason = item['rejection_reason']?.toString();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isApproved ? () => _viewPdf(item['id']) : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_iconFor(status), size: 16, color: accent),
                const SizedBox(width: 8),
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
                    _labelFor(status),
                    style: AppText.body(
                      size: 10.5,
                      weight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
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
                      weight: FontWeight.w500,
                      color: AppColors.navyDark,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDays(item['days_applied']),
                  style: AppText.body(
                    size: 11.5,
                    weight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
            // HR records a reason when declining; this is the only place the
            // employee can ever see it.
            if (isRejected && reason != null && reason.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  reason,
                  style: AppText.body(
                    size: 11.5,
                    weight: FontWeight.w500,
                    color: AppColors.navyDark,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            if (isApproved) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.description_outlined,
                    size: 13,
                    color: AppColors.navy,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'View leave form',
                    style: AppText.body(
                      size: 12,
                      weight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
