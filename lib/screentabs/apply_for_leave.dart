import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_providers.dart';
import '../services/leave_application_service.dart';
import '../model/leave_type_option.dart';
import '../utils/date_utils.dart';
import '../utils/form_styles.dart';
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

  List<LeaveTypeOption> get _leaveTypeOptions =>
      LeaveTypeOption.listFromJson(widget.leaveTypes);

  int get _numberOfDays {
    if (_startDate == null || _endDate == null) return 0;
    return _endDate!.difference(_startDate!).inDays + 1;
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_startDate ?? now)
        : (_endDate ?? _startDate ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
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
      setState(() => _errorMessage =
          'Wellness leave cannot exceed 3 consecutive days per application.');
      return;
    }

    if (days > selected.remainingBalance) {
      setState(() => _errorMessage =
          'Insufficient leave balance. You only have ${selected.remainingBalance} '
          'days remaining for ${selected.name}.');
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
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        title: const Text('Apply for Leave', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              const SizedBox(height: 16),
            ],

            const Text('Leave Type',
                style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E3A5F))),
            const SizedBox(height: 8),
            DropdownButtonFormField<LeaveTypeOption>(
              value: _selectedLeaveType,
              decoration: AppInputDecoration.standard(hint: 'Select leave type'),
              items: options
                  .map((opt) => DropdownMenuItem(
                        value: opt,
                        child: Text('${opt.name} (${opt.remainingBalance} left)'),
                      ))
                  .toList(),
              onChanged: (val) => setState(() => _selectedLeaveType = val),
              validator: (val) => val == null ? 'Please select a leave type' : null,
            ),
            const SizedBox(height: 20),

            const Text('Dates',
                style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E3A5F))),
            const SizedBox(height: 8),
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
              const SizedBox(height: 8),
              Text(
                '$_numberOfDays day${_numberOfDays > 1 ? 's' : ''} requested',
                style: const TextStyle(color: Color(0xFF8A97A8), fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),

            const Text('Reason',
                style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E3A5F))),
            const SizedBox(height: 8),
            TextFormField(
              controller: _reasonController,
              maxLines: 4,
              decoration: AppInputDecoration.standard(
                  hint: 'Briefly describe your reason for leave (optional)'),
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                    : const Text('Submit Request', style: TextStyle(fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}