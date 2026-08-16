import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_providers.dart';
import '../services/leave_credit_service.dart';
import '../services/leave_monetization_service.dart';

class ApplyForLeaveMonetization extends StatefulWidget {
  const ApplyForLeaveMonetization({super.key});

  @override
  State<ApplyForLeaveMonetization> createState() =>
      _ApplyForLeaveMonetizationsState();
}

class _ApplyForLeaveMonetizationsState
    extends State<ApplyForLeaveMonetization> {
  static const Color _navy = Color(0xFF1E3A5F);
  static const Color _muted = Color(0xFF8A97A8);
  static const Duration _networkTimeout = Duration(seconds: 10);

  final _formKey = GlobalKey<FormState>();
  final _daysController = TextEditingController();
  final _reasonController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _loadError;

  List<Map<String, dynamic>> _eligibleConfigs = [];
  List<dynamic> _credits = [];
  int? _selectedConfigId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _daysController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;

    if (token == null) {
      setState(() {
        _isLoading = false;
        _loadError = 'You must be logged in to file a request.';
      });
      return;
    }

    try {
      final results = await Future.wait([
        LeaveMonetizationService.getLeaveConfigurations(token: token)
            .timeout(_networkTimeout),
        LeaveCreditService.getCredits(token).timeout(_networkTimeout),
      ]).timeout(_networkTimeout + const Duration(seconds: 2));

      final configResult = results[0];
      final creditResult = results[1];

      if (configResult['success'] != true) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _loadError = configResult['message'] ?? 'Failed to load leave types.';
        });
        return;
      }

      final allConfigs = List<Map<String, dynamic>>.from(configResult['data'] ?? []);
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
        _selectedConfigId = eligible.isNotEmpty ? eligible.first['id'] as int? : null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Something went wrong loading this form.';
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
    return double.tryParse(match['remaining_balance']?.toString() ?? '0') ?? 0.0;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedConfigId == null) {
      _showSnack('Please select a leave type.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;
    if (token == null) {
      setState(() => _isSubmitting = false);
      _showSnack('You must be logged in to file a request.', isError: true);
      return;
    }

    final days = double.parse(_daysController.text.trim());

    final result = await LeaveMonetizationService.apply(
      token: token,
      leaveConfigurationId: _selectedConfigId!,
      daysMonetized: days,
      reason: _reasonController.text,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      _showSnack(result['message'] ?? 'Request submitted successfully.');
      Navigator.pop(context, true);
    } else {
      _showSnack(result['message'] ?? 'Failed to submit request.', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Apply for Leave Monetization'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : _loadError != null
              ? _buildError()
              : _eligibleConfigs.isEmpty
                  ? _buildEmpty()
                  : _buildForm(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_loadError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No leave types are currently eligible for monetization.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted),
        ),
      ),
    );
  }

  Widget _buildForm() {
    final remaining = _selectedRemainingBalance;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Leave Type',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _muted),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                isExpanded: true,
                value: _selectedConfigId,
                items: _eligibleConfigs
                    .map((c) => DropdownMenuItem<int>(
                          value: c['id'] as int,
                          child: Text(c['name']?.toString() ?? 'Leave type'),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedConfigId = value),
              ),
            ),
          ),
          if (remaining != null) ...[
            const SizedBox(height: 8),
            Text(
              'Remaining balance: ${remaining.toStringAsFixed(1)} day(s)',
              style: const TextStyle(fontSize: 12, color: _muted),
            ),
          ],
          const SizedBox(height: 20),
          const Text(
            'Days to Monetize',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _muted),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _daysController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'e.g. 10 or 10.000',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) return 'Enter the number of days.';
              final parsed = double.tryParse(trimmed);
              if (parsed == null) return 'Enter a valid number.';
              if (parsed < 0.5) return 'Minimum is 0.5 day.';
              if (remaining != null && parsed > remaining) {
                return 'Exceeds your remaining balance of ${remaining.toStringAsFixed(1)} day(s).';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'Reason (optional)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _muted),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _reasonController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Add a note for the HR admin reviewing this request',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Submit Request', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Submitted requests are reviewed by an HR admin before approval.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: _muted),
          ),
        ],
      ),
    );
  }
}