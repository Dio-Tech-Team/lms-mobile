import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_providers.dart';
import '../services/leave_application_service.dart';

class _LeaveTypeOption {
  final int id;
  final String name;
  final String? code;
  final double remainingBalance;

  const _LeaveTypeOption({
    required this.id,
    required this.name,
    this.code,
    required this.remainingBalance,
  });

  @override
  bool operator ==(Object other) =>
      other is _LeaveTypeOption && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class ApplyForLeave extends StatefulWidget {
  final List<dynamic>? leaveTypes;

  const ApplyForLeave({super.key, this.leaveTypes});

  @override
  State<ApplyForLeave> createState() => _ApplyForLeaveState();
}

class _ApplyForLeaveState extends State<ApplyForLeave> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  _LeaveTypeOption? _selectedLeaveType;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<_LeaveTypeOption> get _leaveTypeOptions => _buildLeaveTypeOptions();

  List<_LeaveTypeOption> _buildLeaveTypeOptions() {
    final types = widget.leaveTypes ?? [];
    debugPrint("DEBUG ApplyForLeave received types: $types");

    final options = <_LeaveTypeOption>[];

    for (int i = 0; i < types.length; i++) {
      final c = types[i];
      if (c is! Map) continue;

      final rawId = c["leave_configuration_id"] ?? c["id"] ?? c["leave_type_id"];
      int intId;
      if (rawId != null) {
        intId = rawId is int ? rawId : (int.tryParse(rawId.toString()) ?? i + 1);
      } else {
        intId = c["code"]?.hashCode ?? (i + 1);
      }

      final name = (c["name"] ?? c["leave_type"] ?? c["leave_type_name"] ?? "Leave").toString();

      final rawBalance = c["remaining_balance"] ?? c["balance"] ?? c["remaining"] ?? 0;
      final double balance = rawBalance is num
          ? rawBalance.toDouble()
          : (double.tryParse(rawBalance.toString()) ?? 0.0);

      options.add(_LeaveTypeOption(
        id: intId,
        name: name,
        code: c["code"]?.toString() ?? c["leave_type_code"]?.toString(),
        remainingBalance: balance,
      ));
    }
    
    debugPrint("DEBUG Parsed Dropdown Options: ${options.length} item(s)");
    return options;
  }

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

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select date';
    return '${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')}/${date.year}';
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
            DropdownButtonFormField<_LeaveTypeOption>(
              value: _selectedLeaveType,
              decoration: _inputDecoration(hint: 'Select leave type'),
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
                  child: _DatePickerField(
                    label: 'Start date',
                    value: _formatDate(_startDate),
                    onTap: () => _pickDate(isStart: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DatePickerField(
                    label: 'End date',
                    value: _formatDate(_endDate),
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
              decoration: _inputDecoration(hint: 'Briefly describe your reason for leave (optional)'),
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

  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF8A97A8))),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value, style: const TextStyle(fontSize: 14)),
                const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF8A97A8)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}