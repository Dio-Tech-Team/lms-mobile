import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_providers.dart';
import '../utils/employee_app_utils.dart';
import '../utils/app_theme.dart';
import '../widgets/app_header.dart';

class ProfilePage extends StatefulWidget {
  final bool isActive;
  final VoidCallback? onViewLogs;

  const ProfilePage({super.key, this.isActive = true, this.onViewLogs});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with WidgetsBindingObserver {
  Map<String, dynamic>? _employee;
  bool _isLoading = true;
  String? _errorMessage;

  Timer? _refreshTimer;
  static const Duration _refreshInterval = Duration(seconds: 60);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

      if (!mounted) return;
      setState(() {
        _employee = auth.employee;
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
    return Container(
      color: AppColors.bg,
      child: RefreshIndicator(
        onRefresh: () => _loadAll(),
        color: AppColors.navy,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _buildHeader(),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.navy),
                ),
              )
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    _errorMessage!,
                    style: AppText.body(size: 13, color: Colors.red.shade700),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionLabel('Work Information'),
                    const SizedBox(height: 10),
                    _buildInfoCard(),
                    const SizedBox(height: 32),
                    _buildLogoutButton(context),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () => confirmAndLogout(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.danger,
          side: BorderSide(color: AppColors.danger.withOpacity(0.35)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: Text(
          'Log Out',
          style: AppText.body(
            size: 14,
            weight: FontWeight.w700,
            color: AppColors.danger,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 15,
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: AppText.eyebrow(
            size: 11.5,
            color: AppColors.navyDark.withOpacity(0.55),
          ),
        ),
      ],
    );
  }

  // Widget _buildHeader() {
  //   if (_employee == null) return const AppHeader(title: 'Profile');

  //   final position = (_employee?['position'] ?? '').toString();

  //   return AppHeader(
  //     title: 'Profile',
  //     bottom: Row(
  //       children: [
  //         Container(
  //           width: 52,
  //           height: 52,
  //           decoration: BoxDecoration(
  //             shape: BoxShape.circle,
  //             color: Colors.white.withOpacity(0.10),
  //             border: Border.all(color: Colors.white.withOpacity(0.16)),
  //           ),
  //           alignment: Alignment.center,
  //           child: Text(
  //             _initials(),
  //             style: AppText.display(
  //               size: 17,
  //               weight: FontWeight.w700,
  //               color: Colors.white,
  //             ),
  //           ),
  //         ),
  //         const SizedBox(width: 14),
  //         Expanded(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text(
  //                 _fullName(),
  //                 style: AppText.display(
  //                   size: 20,
  //                   weight: FontWeight.w700,
  //                   color: Colors.white,
  //                 ),
  //               ),
  //               if (position.isNotEmpty) ...[
  //                 const SizedBox(height: 2),
  //                 Text(
  //                   position,
  //                   maxLines: 1,
  //                   overflow: TextOverflow.ellipsis,
  //                   style: AppText.body(
  //                     size: 12.5,
  //                     weight: FontWeight.w500,
  //                     color: Colors.white60,
  //                   ),
  //                 ),
  //               ],
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }
  Widget _buildHeader() {
    return const AppHeader(title: 'Profile');
  }

  Widget _buildInfoCard() {
    final rows = [
      (Icons.person_outline_rounded, 'Name', _fullName()),
      (Icons.badge_outlined, 'ID Number', _employee?['id_number']),
      (Icons.work_outline_rounded, 'Position', _employee?['position']),
      (
        Icons.verified_outlined,
        'Employment Status',
        titleCaseOrPlaceholder(
          _employee?['employment_status']?.toString(),
          placeholder: '—',
        ),
      ),
      (
        Icons.event_outlined,
        'Date Hired',
        formatIsoDate(_employee?['date_hired']?.toString(), placeholder: '—'),
      ),
      (Icons.apartment_rounded, 'Department', _employee?['department']),
      (Icons.mail_outline_rounded, 'Email', _employee?['email']),
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.hairline),
        boxShadow: [
          BoxShadow(
            color: AppColors.navyDark.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            _infoRow(rows[i].$1, rows[i].$2, rows[i].$3),
            if (i != rows.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(height: 1, color: AppColors.hairline),
              ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.navy.withOpacity(0.06),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: AppColors.navy.withOpacity(0.7)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppText.body(
                    size: 11.5,
                    weight: FontWeight.w600,
                    color: AppColors.muted,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  (value ?? '—').toString(),
                  style: AppText.body(
                    size: 14,
                    weight: FontWeight.w600,
                    color: AppColors.navyDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
