import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_providers.dart';
import '../services/leave_application_service.dart';
import '../model/leave_type_option.dart';
import '../utils/date_utils.dart';
import '../widgets/date_picker_field.dart';

class ApplyForLeave extends StatefulWidget {
  final List<dynamic>? leaveTypes;

  const ApplyForLeave({super.key, this.leaveTypes});

  @override
  State<ApplyForLeave> createState() => _ApplyForLeaveState();
}

class _ApplyForLeaveState extends State<ApplyForLeave> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  LeaveTypeOption? _selectedLeaveType;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSubmitting = false;
  String? _errorMessage;

  static const Color _navyDark = Color(0xFF13224A);
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
    final isVL = _selectedLeaveType?.code == 'VL';
    final earliestAllowed = isVL
        ? DateTime(now.year, now.month, now.day + 5)
        : DateTime(now.year, now.month, now.day);

    final initial = isStart
        ? (_startDate ?? earliestAllowed)
        : (_endDate ?? _startDate ?? earliestAllowed);
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
  }

  Future<void> _submit() async {
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

    final days = _numberOfDays.toDouble();
    final selected = _selectedLeaveType!;

    if (selected.code == 'WL' && days > 3) {
      setState(
        () => _errorMessage =
            'Wellness leave cannot exceed 3 consecutive days per application.',
      );
      return;
    }
    if (selected.code == 'VL') {
      final minStartDate = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day + 5,
      );
      if (_startDate!.isBefore(minStartDate)) {
        setState(
          () => _errorMessage =
              'Vacation Leave must be filed at least 5 days before the start date.',
        );
        return;
      }
    }

    if (days > selected.remainingBalance) {
      setState(
        () => _errorMessage =
            'Insufficient leave balance. You only have ${selected.remainingBalance} '
            'days remaining for ${selected.name}.',
      );
      return;
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

    final result = await LeaveApplicationService.apply(
      leaveConfigurationId: selected.id,
      startDate: _startDate!,
      endDate: _endDate!,
      daysApplied: days,
      token: token,
      reason: _reasonController.text.trim().isEmpty
          ? null
          : _reasonController.text.trim(),
    );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (result["success"] == true) {
      Navigator.pop(context, {
        'success': true,
        'leaveConfigurationId': selected.id,
        'daysApplied': days,
      });
    } else {
      setState(() {
        _errorMessage = result["message"] ?? 'Failed to submit leave request.';
      });
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = _leaveTypeOptions;

    return Scaffold(
      backgroundColor: const Color(0xFFEEF0F5),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            elevation: 0,
            backgroundColor: _navy,
            expandedHeight: 120,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              title: const Text(
                'Apply for Leave',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_navyDark, _navy],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
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
                                style: const TextStyle(
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

                    // Leave type card
                    _sectionCard(
                      icon: Icons.event_note_rounded,
                      label: 'Leave Type',
                      child: DropdownButtonFormField<LeaveTypeOption>(
                        value: _selectedLeaveType,
                        isExpanded: true,
                        decoration: _fieldDecoration(hint: 'Select leave type'),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: _muted,
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
                        onChanged: (val) =>
                            setState(() => _selectedLeaveType = val),
                        validator: (val) =>
                            val == null ? 'Please select a leave type' : null,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Dates card
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
                          if (_numberOfDays > 0) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 14,
                              ),
                              decoration: BoxDecoration(
                                color: _navy.withOpacity(0.07),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.timelapse_rounded,
                                    size: 16,
                                    color: _navy,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$_numberOfDays day${_numberOfDays > 1 ? 's' : ''} requested',
                                    style: const TextStyle(
                                      color: _navy,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
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

                    // Reason card
                    _sectionCard(
                      icon: Icons.notes_rounded,
                      label: 'Reason',
                      child: TextFormField(
                        controller: _reasonController,
                        maxLines: 4,
                        decoration: _fieldDecoration(
                          hint:
                              'Briefly describe your reason for leave (optional)',
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
                            : const Text(
                                'Submit Request',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
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
                style: const TextStyle(
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
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13.5),
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
