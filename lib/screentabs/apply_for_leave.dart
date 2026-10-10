import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_providers.dart';
import '../services/leave_application_service.dart';
import '../model/leave_type_option.dart';
import '../utils/date_utils.dart';
import '../widgets/date_picker_field.dart';
import '../widgets/app_header.dart';

class ApplyForLeave extends StatefulWidget {
  final List<dynamic>? leaveTypes;

  const ApplyForLeave({super.key, this.leaveTypes});

  @override
  State<ApplyForLeave> createState() => _ApplyForLeaveState();
}

class _ApplyForLeaveState extends State<ApplyForLeave> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  // Same lists as the web filing form. Types not listed only get "Other".
  static const Map<String, List<String>> _leaveReasons = {
    'VL': [
      'Personal matters',
      'Family matters',
      'Vacation (within the Philippines)',
      'Vacation (abroad)',
    ],
    'SL': [
      'Illness',
      'Medical check-up',
      'Hospitalization',
      'Recovery after procedure',
    ],
    'FL': ['Mandatory leave'],
  };
  static const String _otherReason = 'Other';

  /// Null or '' = no reason picked
  String? _reasonChoice;

  List<String> get _reasonOptions => [
    ...(_leaveReasons[_selectedLeaveType?.code] ?? const <String>[]),
    _otherReason,
  ];

  /// Dropdown choice plus optional details, as one string for the API.
  String? _buildReason() {
    final details = _reasonController.text.trim();
    final choice = (_reasonChoice ?? '').isEmpty ? null : _reasonChoice;

    if (choice == null) return details.isEmpty ? null : details;
    if (choice == _otherReason) return details.isEmpty ? null : details;
    return details.isEmpty ? choice : '$choice — $details';
  }

  LeaveTypeOption? _selectedLeaveType;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSubmitting = false;
  String? _errorMessage;

  /// The backend's own count for the chosen range. Local _numberOfDays is
  /// calendar days; this is what actually gets deducted.
  Map<String, dynamic>? _preview;
  bool _previewLoading = false;
  Timer? _previewTimer;

  static const Duration _networkTimeout = Duration(seconds: 30);
  static const Color _navy = Color(0xFF1B3B63);
  static const Color _text = Color(0xFF1E3A5F);
  static const Color _muted = Color(0xFF8A97A8);

  List<LeaveTypeOption> get _leaveTypeOptions =>
      LeaveTypeOption.listFromJson(widget.leaveTypes);

  int get _numberOfDays {
    if (_startDate == null || _endDate == null) return 0;
    return _endDate!.difference(_startDate!).inDays + 1;
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final code = _selectedLeaveType?.code;

    // VL: 5 days ahead. SL: filed after the absence, so past dates are
    // allowed (back to the start of last year). Others: from today.
    final DateTime earliestAllowed;
    if (code == 'VL' || code == 'WL') {
      earliestAllowed = DateTime(now.year, now.month, now.day + 5);
    } else if (code == 'SL') {
      earliestAllowed = DateTime(now.year - 1, 1, 1);
    } else {
      earliestAllowed = today;
    }

    // Open the calendar on today for SL, not on the earliest allowed date
    final defaultDate = code == 'SL' ? today : earliestAllowed;
    final initial = isStart
        ? (_startDate ?? defaultDate)
        : (_endDate ?? _startDate ?? defaultDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(earliestAllowed)
          ? earliestAllowed
          : initial,
      firstDate: isStart ? earliestAllowed : (_startDate ?? earliestAllowed),
      lastDate: DateTime(now.year + 2),
      builder: (context, child) {
        return Theme(
          data: Theme.of(
            context,
          ).copyWith(colorScheme: const ColorScheme.light(primary: _navy)),
          child: child!,
        );
      },
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(_startDate!)) {
          _endDate = _startDate;
        }
      } else {
        _endDate = picked;
      }
    });
    _autoFillEndDateIfNeeded();
    _schedulePreview();
  }

  void _autoFillEndDateIfNeeded() {
    if (_selectedLeaveType != null &&
        _selectedLeaveType!.isEventManual &&
        _startDate != null) {
      final days = _selectedLeaveType!.remainingBalance;
      if (days > 0) {
        setState(() {
          _endDate = _startDate!.add(Duration(days: days.toInt() - 1));
        });
      }
    }
  }

  /// Asks the backend what this range actually costs before the employee
  /// commits to it. Debounced, since it fires on every date and type change.
  void _schedulePreview() {
    _previewTimer?.cancel();

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;
    final employeeId = auth.employeeId;

    if (token == null ||
        employeeId == null ||
        _selectedLeaveType == null ||
        _startDate == null ||
        _endDate == null ||
        _endDate!.isBefore(_startDate!)) {
      setState(() {
        _preview = null;
        _previewLoading = false;
      });
      return;
    }

    setState(() => _previewLoading = true);

    _previewTimer = Timer(const Duration(milliseconds: 350), () async {
      final result = await LeaveApplicationService.preview(
        employeeId: employeeId,
        leaveConfigurationId: _selectedLeaveType!.id,
        startDate: _startDate!,
        endDate: _endDate!,
        token: token,
      );

      if (!mounted) return;
      setState(() {
        _preview = result['success'] == true ? result['data'] : null;
        _previewLoading = false;
      });
    });
  }

  Future<void> _submit() async {
    // Guard, not just a disabled button: the button only disables after
    // setState rebuilds, which leaves a window for a fast double-tap.
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    if (_selectedLeaveType == null) {
      setState(() => _errorMessage = 'Please select a leave type.');
      return;
    }

    if (_startDate == null || _endDate == null) {
      setState(() => _errorMessage = 'Please select both start and end dates.');
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      setState(() => _errorMessage = 'End date cannot be before start date.');
      return;
    }

    // "Other" alone says nothing — ask what it is
    if (_reasonChoice == _otherReason &&
        _reasonController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please specify the reason.');
      return;
    }

    final days = _numberOfDays.toDouble();
    final selected = _selectedLeaveType!;

    if (selected.code == 'WL' && days > 3) {
      setState(
        () => _errorMessage =
            'Wellness leave cannot exceed 3 consecutive days per application.',
      );
      return;
    }
    if (selected.code == 'VL' || selected.code == 'WL') {
      final minStartDate = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day + 5,
      );
      if (_startDate!.isBefore(minStartDate)) {
        setState(
          () => _errorMessage =
              '${selected.name} must be filed at least 5 days before the start date.',
        );
        return;
      }
    }

    // if (days > selected.remainingBalance) {
    //   setState(
    //     () => _errorMessage =
    //         'Insufficient leave balance. You only have ${selected.remainingBalance} '
    //         'days remaining for ${selected.name}.',
    //   );
    //   return;
    // }
    // The backend hard-blocks these types on insufficient balance. VL and SL
    // fall through to Leave Without Pay instead, so don't block them here.
    const hardBlockedCodes = [
      'WL',
      'SPL',
      'SOL',
      'ML',
      'PTL',
      'VAWC',
      'RHL',
      'SLB',
      'STL',
      'ADL',
      'CAL',
    ];

    if (hardBlockedCodes.contains(selected.code) &&
        days > selected.remainingBalance) {
      setState(
        () => _errorMessage =
            'Insufficient leave balance. You only have ${selected.remainingBalance} '
            'days remaining for ${selected.name}.',
      );
      return;
    }

    // Unpaid days are the one consequence the employee cannot undo after
    // approval, so make them say yes to it explicitly.
    if (_preview != null && _preview!['will_be_lwop'] == true) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            'Some days will be unpaid',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: _text,
            ),
          ),
          content: Text(
            'You have ${_preview!['remaining_balance']} day(s) of '
            '${_preview!['target_code']} left but are applying for '
            '${_preview!['days_applied']}. '
            '${_preview!['shortfall']} day(s) will be recorded as Leave '
            'Without Pay. Submit anyway?',
            style: GoogleFonts.nunito(fontSize: 13.5, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Go back',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w600,
                  color: _muted,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Submit anyway',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800,
                  color: _navy,
                ),
              ),
            ),
          ],
        ),
      );

      if (proceed != true || !mounted) return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;

    if (token == null) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'No employee record linked to your account.';
      });
      return;
    }

    try {
      final result = await LeaveApplicationService.apply(
        leaveConfigurationId: selected.id,
        startDate: _startDate!,
        endDate: _endDate!,
        daysApplied: days,
        token: token,
        reason: _buildReason(),
      ).timeout(_networkTimeout);

      if (!mounted) return;

      if (result["success"] == true) {
        // Pop before clearing the flag — the page is going away anyway,
        // and setState after pop would fire on a defunct State.
        Navigator.pop(context, {
          'success': true,
          'leaveConfigurationId': selected.id,
          'daysApplied': days,
        });
        return;
      }

      setState(() {
        _isSubmitting = false;
        _errorMessage = result["message"] ?? 'Failed to submit leave request.';
      });
    } catch (e) {
      debugPrint('APPLY LEAVE FAILED: $e');
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'The request timed out. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = _leaveTypeOptions;

    return Scaffold(
      backgroundColor: const Color(0xFFEEF0F5),
      body: Column(
        children: [
          const AppHeader(title: 'Apply for Leave', showBack: true),
          Expanded(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_errorMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red.shade400,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: GoogleFonts.nunito(
                                    color: Colors.red,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      _sectionCard(
                        icon: Icons.event_note_rounded,
                        label: 'Leave Type',
                        child: DropdownButtonFormField<LeaveTypeOption>(
                          value: _selectedLeaveType,
                          isExpanded: true,
                          decoration: _fieldDecoration(
                            hint: 'Select leave type',
                          ),
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: _muted,
                          ),
                          style: GoogleFonts.nunito(
                            color: _text,
                            fontSize: 13.5,
                          ),
                          items: options
                              .map(
                                (opt) => DropdownMenuItem(
                                  value: opt,
                                  child: Text(
                                    '${opt.name} (${opt.remainingBalance} left)',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              // Date limits differ by type, so start over
                              if (val?.code != _selectedLeaveType?.code) {
                                _startDate = null;
                                _endDate = null;
                                // A VL reason makes no sense on SL
                                _reasonChoice = null;
                              }
                              _selectedLeaveType = val;
                            });
                            _autoFillEndDateIfNeeded();
                            _schedulePreview();
                          },
                          validator: (val) =>
                              val == null ? 'Please select a leave type' : null,
                        ),
                      ),
                      const SizedBox(height: 16),

                      _sectionCard(
                        icon: Icons.calendar_month_rounded,
                        label: 'Dates',
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: DatePickerField(
                                    label: 'Start date',
                                    value: formatDate(_startDate),
                                    onTap: () => _pickDate(isStart: true),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DatePickerField(
                                    label: 'End date',
                                    value: formatDate(_endDate),
                                    onTap: () => _pickDate(isStart: false),
                                  ),
                                ),
                              ],
                            ),
                            if (_previewLoading) ...[
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Calculating…',
                                  style: GoogleFonts.nunito(
                                    color: _muted,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ] else if (_preview != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: _preview!['hard_blocked'] == true
                                      ? Colors.red.withOpacity(0.08)
                                      : _preview!['will_be_lwop'] == true
                                      ? const Color(
                                          0xFFD98F32,
                                        ).withOpacity(0.12)
                                      : _navy.withOpacity(0.07),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_preview!['days_applied']} day(s) will be deducted',
                                      style: GoogleFonts.nunito(
                                        color: _text,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _preview!['counting'] == 'working'
                                          ? 'Weekends and holidays are not counted.'
                                          : 'Counted as calendar days.',
                                      style: GoogleFonts.nunito(
                                        color: _muted,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                    if (_preview!['remaining_balance'] !=
                                        null) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        '${_preview!['target_code']} balance: '
                                        '${_preview!['remaining_balance']} → '
                                        '${_preview!['balance_after']}',
                                        style: GoogleFonts.nunito(
                                          color: _text,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                    if (_preview!['hard_blocked'] == true) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'You do not have enough balance for this '
                                        'leave type. This request will be refused.',
                                        style: GoogleFonts.nunito(
                                          color: Colors.red.shade700,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          height: 1.35,
                                        ),
                                      ),
                                    ] else if (_preview!['will_be_lwop'] ==
                                        true) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        '${_preview!['shortfall']} day(s) will be '
                                        'recorded as Leave Without Pay — you will '
                                        'not be paid for them.',
                                        style: GoogleFonts.nunito(
                                          color: const Color(0xFF8A5A16),
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
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
                        label: 'Reason (optional)',
                        child: Column(
                          children: [
                            DropdownButtonFormField<String>(
                              value: _reasonChoice,
                              isExpanded: true,
                              decoration: _fieldDecoration(
                                hint: 'Select a reason',
                              ),
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: _muted,
                              ),
                              style: GoogleFonts.nunito(
                                color: _text,
                                fontSize: 13.5,
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: '',
                                  child: Text('No reason given'),
                                ),
                                ..._reasonOptions.map(
                                  (r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(
                                      r,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (val) =>
                                  setState(() => _reasonChoice = val),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _reasonController,
                              maxLines: 3,
                              style: GoogleFonts.nunito(
                                fontSize: 13.5,
                                color: _text,
                              ),
                              decoration: _fieldDecoration(
                                hint: _reasonChoice == _otherReason
                                    ? 'Specify the reason'
                                    : 'Additional details (optional)',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _navy,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  'Submit Request',
                                  style: GoogleFonts.nunito(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
                  color: _navy.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 15, color: _navy),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: _text,
                ),
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
      hintStyle: GoogleFonts.nunito(
        color: Colors.grey.shade400,
        fontSize: 13.5,
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
        borderSide: const BorderSide(color: _navy, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.red.shade300),
      ),
    );
  }
}
