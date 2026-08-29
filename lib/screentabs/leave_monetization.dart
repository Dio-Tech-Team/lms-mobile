import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_providers.dart';
import '../services/leave_credit_service.dart';
import '../services/leave_monetization_service.dart';
import '../utils/app_theme.dart';
import '../widgets/app_header.dart';

class ApplyForLeaveMonetization extends StatefulWidget {
  /// False while another tab is showing. The parent keeps every tab alive
  /// in an IndexedStack, so without this the form would fetch its configs
  /// and credits at app start, for a screen nobody has opened yet.
  final bool isActive;

  const ApplyForLeaveMonetization({super.key, this.isActive = true});

  @override
  State<ApplyForLeaveMonetization> createState() =>
      _ApplyForLeaveMonetizationsState();
}

class _ApplyForLeaveMonetizationsState
    extends State<ApplyForLeaveMonetization> {
  static const Duration _networkTimeout = Duration(seconds: 30);

  final _formKey = GlobalKey<FormState>();
  final _daysController = TextEditingController();
  final _reasonController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _hasLoaded = false;
  String? _loadError;
  String? _successMessage;

  List<Map<String, dynamic>> _eligibleConfigs = [];
  List<dynamic> _credits = [];
  int? _selectedConfigId;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _loadData();
  }

  @override
  void didUpdateWidget(covariant ApplyForLeaveMonetization oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      // Balances may have changed while the user was on another tab.
      _loadData(silent: _hasLoaded);
    }
  }

  @override
  void dispose() {
    _daysController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;

    if (token == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'You must be logged in to file a request.';
      });
      return;
    }

    try {
      final results = await Future.wait([
        LeaveMonetizationService.getLeaveConfigurations(
          token: token,
        ).timeout(_networkTimeout),
        LeaveCreditService.getCredits(token).timeout(_networkTimeout),
      ]).timeout(_networkTimeout + const Duration(seconds: 2));

      final configResult = results[0];
      final creditResult = results[1];

      if (configResult['success'] != true) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          if (!silent) {
            _loadError =
                configResult['message'] ?? 'Failed to load leave types.';
          }
        });
        return;
      }

      final allConfigs = List<Map<String, dynamic>>.from(
        configResult['data'] ?? [],
      );
      final eligible = allConfigs
          .where((c) => c['can_monetize'] == true || c['can_monetize'] == 1)
          .toList();

      List<dynamic> credits = [];
      if (creditResult['success'] == true) {
        final data = creditResult['data'];
        if (data is Map) {
          if (data['credits'] is List) credits = data['credits'];
          if (credits.isEmpty && data['data'] is List) credits = data['data'];
        }
      }

      if (!mounted) return;
      setState(() {
        _eligibleConfigs = eligible;
        _credits = credits;
        // Keep the user's current selection if it's still valid, so a
        // background refresh doesn't reset a form they're filling in.
        final stillValid = eligible.any((c) => c['id'] == _selectedConfigId);
        if (!stillValid) {
          _selectedConfigId = eligible.isNotEmpty
              ? eligible.first['id'] as int?
              : null;
        }
        _isLoading = false;
        _hasLoaded = true;
      });
    } catch (e) {
      debugPrint('MONETIZATION LOAD FAILED: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (!silent) {
          _loadError = 'Something went wrong loading this form.';
        }
      });
    }
  }

  Map<String, dynamic>? get _selectedConfig {
    if (_selectedConfigId == null) return null;
    try {
      return _eligibleConfigs.firstWhere((c) => c['id'] == _selectedConfigId);
    } catch (_) {
      return null;
    }
  }

  double? get _selectedRemainingBalance {
    final config = _selectedConfig;
    if (config == null) return null;
    final name = (config['name'] ?? '').toString();
    final match = _credits.firstWhere(
      (c) => (c['leave_type'] ?? c['name'] ?? '').toString() == name,
      orElse: () => null,
    );
    if (match == null) return null;
    return double.tryParse(match['remaining_balance']?.toString() ?? '0') ??
        0.0;
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedConfigId == null) {
      _showSnack('Please select a leave type.', isError: true);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _successMessage = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;
    if (token == null) {
      setState(() => _isSubmitting = false);
      _showSnack('You must be logged in to file a request.', isError: true);
      return;
    }

    final days = double.parse(_daysController.text.trim());

    try {
      final result = await LeaveMonetizationService.apply(
        token: token,
        leaveConfigurationId: _selectedConfigId!,
        daysMonetized: days,
        reason: _reasonController.text,
      ).timeout(_networkTimeout);

      if (!mounted) return;

      if (result['success'] == true) {
        // This screen is a tab inside an IndexedStack, not a pushed route,
        // so there is nothing to pop. Reset the form and show the result
        // in place instead, then refresh balances to reflect the request.
        _daysController.clear();
        _reasonController.clear();
        _formKey.currentState?.reset();
        setState(() {
          _isSubmitting = false;
          _successMessage =
              result['message'] ??
              'Request submitted. HR will review it shortly.';
        });
        await _loadData(silent: true);
      } else {
        setState(() => _isSubmitting = false);
        _showSnack(
          result['message'] ?? 'Failed to submit request.',
          isError: true,
        );
      }
    } catch (e) {
      debugPrint('MONETIZATION SUBMIT FAILED: $e');
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showSnack('The request timed out. Please try again.', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppText.body(size: 13, color: Colors.white),
        ),
        backgroundColor: isError ? AppColors.red : AppColors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          const AppHeader(title: 'Leave Monetization'),
          Expanded(
            child: SingleChildScrollView(
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 100),
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.navy),
                      ),
                    )
                  : _loadError != null
                  ? _buildError()
                  : _eligibleConfigs.isEmpty
                  ? _buildEmpty()
                  : _buildForm(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 30),
          Icon(
            Icons.error_outline_rounded,
            color: Colors.red.shade300,
            size: 32,
          ),
          const SizedBox(height: 14),
          Text(
            _loadError!,
            textAlign: TextAlign.center,
            style: AppText.body(size: 13.5, color: Colors.red.shade600),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: () => _loadData(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              child: Text(
                'Try again',
                style: AppText.body(
                  size: 13.5,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(
            Icons.inbox_rounded,
            color: AppColors.muted.withOpacity(0.4),
            size: 32,
          ),
          const SizedBox(height: 14),
          Text(
            'No leave types are currently eligible for monetization.',
            textAlign: TextAlign.center,
            style: AppText.body(
              size: 13.5,
              weight: FontWeight.w500,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 18,
            color: AppColors.green,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _successMessage!,
              style: AppText.body(size: 12.5, color: AppColors.green),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _successMessage = null),
            child: Icon(
              Icons.close_rounded,
              size: 16,
              color: AppColors.green.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final remaining = _selectedRemainingBalance;
    final daysText = _daysController.text.trim();
    final requestedDays = double.tryParse(daysText);
    final overBalance =
        remaining != null && requestedDays != null && requestedDays > remaining;

    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_successMessage != null) _buildSuccessBanner(),

            _sectionCard(
              icon: Icons.event_note_rounded,
              label: 'Leave Type',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F6FA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: _selectedConfigId,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.muted,
                        ),
                        style: AppText.body(size: 13.5),
                        items: _eligibleConfigs
                            .map(
                              (c) => DropdownMenuItem<int>(
                                value: c['id'] as int,
                                child: Text(
                                  c['name']?.toString() ?? 'Leave type',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedConfigId = value),
                      ),
                    ),
                  ),
                  if (remaining != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.navy.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.savings_rounded,
                            size: 16,
                            color: AppColors.navy,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Remaining balance: '
                            '${remaining.toStringAsFixed(1)} day(s)',
                            style: AppText.body(
                              size: 12.5,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            _sectionCard(
              icon: Icons.calculate_rounded,
              label: 'Days to Monetize',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _daysController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: AppText.body(size: 13.5),
                    onChanged: (_) => setState(() {}),
                    decoration: _fieldDecoration(hint: 'e.g. 10 or 10.000'),
                    validator: (value) {
                      final trimmed = value?.trim() ?? '';
                      if (trimmed.isEmpty) return 'Enter the number of days.';
                      final parsed = double.tryParse(trimmed);
                      if (parsed == null) return 'Enter a valid number.';
                      if (parsed < 0.5) return 'Minimum is 0.5 day.';
                      if (remaining != null && parsed > remaining) {
                        return 'Exceeds your remaining balance of '
                            '${remaining.toStringAsFixed(1)} day(s).';
                      }
                      return null;
                    },
                  ),
                  if (requestedDays != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 14,
                      ),
                      decoration: BoxDecoration(
                        color: (overBalance ? AppColors.red : AppColors.navy)
                            .withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            overBalance
                                ? Icons.warning_amber_rounded
                                : Icons.timelapse_rounded,
                            size: 16,
                            color: overBalance ? AppColors.red : AppColors.navy,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              overBalance
                                  ? 'Exceeds your remaining balance'
                                  : '$requestedDays day(s) requested for '
                                        'monetization',
                              style: AppText.body(
                                size: 12.5,
                                weight: FontWeight.w700,
                                color: overBalance
                                    ? AppColors.red
                                    : AppColors.navy,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            _sectionCard(
              icon: Icons.notes_rounded,
              label: 'Reason',
              child: TextFormField(
                controller: _reasonController,
                maxLines: 4,
                style: AppText.body(size: 13.5),
                decoration: _fieldDecoration(
                  hint:
                      'Add a note for the HR admin reviewing this request '
                      '(optional)',
                ),
              ),
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.navy.withOpacity(0.5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Submitting...',
                            style: AppText.body(
                              size: 15,
                              weight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        'Submit request',
                        style: AppText.body(
                          size: 15,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
        boxShadow: [
          BoxShadow(
            color: AppColors.navyDark.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.navy.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 15, color: AppColors.navy),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppText.body(size: 13.5, weight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppText.body(
        size: 13.5,
        weight: FontWeight.w500,
        color: Colors.grey.shade400,
      ),
      filled: true,
      fillColor: const Color(0xFFF5F6FA),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.navy, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.red.shade300),
      ),
    );
  }
}
