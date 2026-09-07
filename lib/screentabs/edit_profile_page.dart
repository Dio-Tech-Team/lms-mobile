import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_providers.dart';
import '../utils/app_theme.dart';
import '../utils/address_picker.dart';
import '../variables.dart';

/// Self-service profile editing. Only the fields the backend's
/// /profile endpoint accepts — work details stay with HR.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final _placeOfBirth = TextEditingController();
  final _address = TextEditingController();
  final _contact = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  final _tin = TextEditingController();
  final _umid = TextEditingController();
  final _pagibig = TextEditingController();
  final _philhealth = TextEditingController();
  final _psn = TextEditingController();

  DateTime? _birthdate;
  String? _sex;
  String? _civilStatus;
  String? _bloodType;
  String? _education;

  bool _saving = false;
  String? _error;

  static const _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  static const _educationLevels = [
    'elementary',
    'secondary',
    'vocational',
    'college',
    'graduate',
  ];

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  void _prefill() {
    final e = Provider.of<AuthProvider>(context, listen: false).employee;
    if (e == null) return;

    _placeOfBirth.text = (e['place_of_birth'] ?? '').toString();
    _address.text = (e['residential_address'] ?? '').toString();
    _contact.text = (e['contact_number'] ?? '').toString();
    _height.text = (e['height'] ?? '').toString();
    _weight.text = (e['weight'] ?? '').toString();
    _tin.text = (e['tin_number'] ?? '').toString();
    _umid.text = (e['umid_id'] ?? '').toString();
    _pagibig.text = (e['pagibig_id'] ?? '').toString();
    _philhealth.text = (e['philhealth_number'] ?? '').toString();
    _psn.text = (e['psn_number'] ?? '').toString();

    final raw = e['birthdate']?.toString();
    if (raw != null && raw.isNotEmpty) {
      _birthdate = DateTime.tryParse(raw.split('T').first);
    }

    // Only adopt stored values that match the dropdown options — an older
    // free-text entry would otherwise crash DropdownButtonFormField.
    _sex = _optionOrNull(e['sex'], const ['male', 'female']);
    _civilStatus = _optionOrNull(e['civil_status'], const [
      'single',
      'married',
      'widowed',
      'separated',
    ]);
    _bloodType = _optionOrNull(e['bloodtype'], _bloodTypes);
    _education = _optionOrNull(
      e['highest_educational_attainment'],
      _educationLevels,
    );
  }

  String? _optionOrNull(dynamic value, List<String> options) {
    final s = value?.toString();
    if (s == null || s.isEmpty) return null;
    return options.contains(s) ? s : null;
  }

  @override
  void dispose() {
    for (final c in [
      _placeOfBirth,
      _address,
      _contact,
      _height,
      _weight,
      _tin,
      _umid,
      _pagibig,
      _philhealth,
      _psn,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Empty strings are sent as null so a cleared field actually clears,
  /// rather than failing the backend's digit rules on ''.
  dynamic _orNull(String v) => v.trim().isEmpty ? null : v.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      _saving = true;
      _error = null;
    });

    final body = {
      'birthdate': _birthdate == null
          ? null
          : _birthdate!.toIso8601String().split('T').first,
      'place_of_birth': _orNull(_placeOfBirth.text),
      'residential_address': _orNull(_address.text),
      'contact_number': _orNull(_contact.text),
      'sex': _sex,
      'civil_status': _civilStatus,
      'height': _orNull(_height.text),
      'weight': _orNull(_weight.text),
      'bloodtype': _bloodType,
      'highest_educational_attainment': _education,
      'tin_number': _orNull(_tin.text),
      'umid_id': _orNull(_umid.text),
      'pagibig_id': _orNull(_pagibig.text),
      'philhealth_number': _orNull(_philhealth.text),
      'psn_number': _orNull(_psn.text),
    };

    try {
      final res = await http
          .put(
            Uri.parse('$baseUrl/profile'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${auth.token}',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (res.statusCode == 200) {
        await auth.fetchEmployeeDetails(forceRefresh: true);
        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      }

      // 422 returns {message, errors:{field:[msg]}} — show the first
      // real message rather than a generic failure.
      String message = 'Could not save your profile.';
      try {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        final errors = decoded['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values.first;
          message = first is List ? first.first.toString() : first.toString();
        } else if (decoded['message'] != null) {
          message = decoded['message'].toString();
        }
      } catch (_) {}

      setState(() => _error = message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Network error. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthdate ?? DateTime(now.year - 30),
      firstDate: DateTime(1940),
      lastDate: now.subtract(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _birthdate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.navyDark,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Edit Profile',
          style: AppText.display(size: 18, color: Colors.white),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
          children: [
            const SizedBox(height: 20),

            if (_error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: AppText.body(size: 13, color: AppColors.danger),
                ),
              ),
              const SizedBox(height: 18),
            ],

            _sectionLabel('Personal Information'),
            const SizedBox(height: 12),
            _card([
              _dateField(),
              _divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: AddressPicker(
                  label: 'Place of Birth',
                  initialValue: _placeOfBirth.text,
                  onChanged: (v) => _placeOfBirth.text = v ?? '',
                ),
              ),
              _divider(),
              _dropdown('Sex', _sex, const [
                'male',
                'female',
              ], (v) => setState(() => _sex = v)),
              _divider(),
              _dropdown('Civil Status', _civilStatus, const [
                'single',
                'married',
                'widowed',
                'separated',
              ], (v) => setState(() => _civilStatus = v)),
              _divider(),
              _textField(
                _height,
                'Height (cm)',
                keyboard: TextInputType.number,
              ),
              _divider(),
              _textField(
                _weight,
                'Weight (kg)',
                keyboard: TextInputType.number,
              ),
              _divider(),
              _dropdown(
                'Blood Type',
                _bloodType,
                _bloodTypes,
                (v) => setState(() => _bloodType = v),
                raw: true,
              ),
              _divider(),
              _dropdown(
                'Highest Educational Attainment',
                _education,
                _educationLevels,
                (v) => setState(() => _education = v),
              ),
            ]),

            const SizedBox(height: 26),
            _sectionLabel('Contact & Address'),
            const SizedBox(height: 12),
            _card([
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: AddressPicker(
                  label: 'Residential Address',
                  initialValue: _address.text,
                  withBarangay: true,
                  onChanged: (v) => _address.text = v ?? '',
                ),
              ),
              _divider(),
              _textField(
                _contact,
                'Contact Number',
                keyboard: TextInputType.phone,
                maxLength: 11,
                digitsOnly: true,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  return v.trim().length == 11
                      ? null
                      : 'Contact number must be 11 digits.';
                },
              ),
            ]),

            const SizedBox(height: 26),
            _sectionLabel('Government IDs'),
            const SizedBox(height: 12),
            _card([
              _textField(
                _tin,
                'TIN',
                keyboard: TextInputType.number,
                maxLength: 12,
                digitsOnly: true,
                validator: (v) => _digitsBetween(v, 9, 12, 'TIN'),
              ),
              _divider(),
              _textField(
                _umid,
                'UMID',
                keyboard: TextInputType.number,
                maxLength: 12,
                digitsOnly: true,
                validator: (v) => _exactDigits(v, 12, 'UMID'),
              ),
              _divider(),
              _textField(
                _pagibig,
                'Pag-IBIG',
                keyboard: TextInputType.number,
                maxLength: 12,
                digitsOnly: true,
                validator: (v) => _exactDigits(v, 12, 'Pag-IBIG'),
              ),
              _divider(),
              _textField(
                _philhealth,
                'PhilHealth',
                keyboard: TextInputType.number,
                maxLength: 12,
                digitsOnly: true,
                validator: (v) => _exactDigits(v, 12, 'PhilHealth'),
              ),
              _divider(),
              _textField(
                _psn,
                'PSN',
                keyboard: TextInputType.number,
                maxLength: 16,
                digitsOnly: true,
                validator: (v) => _exactDigits(v, 16, 'PSN'),
              ),
            ]),

            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.navy.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Save Changes',
                        style: AppText.body(
                          size: 14.5,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _exactDigits(String? v, int length, String label) {
    if (v == null || v.trim().isEmpty) return null;
    return v.trim().length == length ? null : '$label must be $length digits.';
  }

  String? _digitsBetween(String? v, int min, int max, String label) {
    if (v == null || v.trim().isEmpty) return null;
    final len = v.trim().length;
    return (len >= min && len <= max)
        ? null
        : '$label must be $min to $max digits.';
  }

  Widget _sectionLabel(String label) {
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

  Widget _card(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 16),
    child: Divider(height: 1, color: AppColors.hairline),
  );

  Widget _textField(
    TextEditingController controller,
    String label, {
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
    int? maxLength,
    bool digitsOnly = false,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: maxLines,
        maxLength: maxLength,
        validator: validator,
        inputFormatters: digitsOnly
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        style: AppText.body(size: 14, color: AppColors.navyDark),
        decoration: InputDecoration(
          labelText: label,
          counterText: '',
          isDense: true,
          border: InputBorder.none,
          labelStyle: AppText.body(size: 13, color: AppColors.muted),
        ),
      ),
    );
  }

  Widget _dateField() {
    final text = _birthdate == null
        ? 'Not set'
        : _birthdate!.toIso8601String().split('T').first;

    return InkWell(
      onTap: _pickBirthdate,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Birthdate',
                    style: AppText.body(size: 13, color: AppColors.muted),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    text,
                    style: AppText.body(
                      size: 14,
                      color: _birthdate == null
                          ? AppColors.muted
                          : AppColors.navyDark,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.calendar_today_outlined,
              size: 17,
              color: AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }

  /// [raw] keeps values like "O+" as-is; everything else is title-cased
  /// for display while the stored lowercase value is what gets sent.
  Widget _dropdown(
    String label,
    String? value,
    List<String> options,
    ValueChanged<String?> onChanged, {
    bool raw = false,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        style: AppText.body(size: 14, color: AppColors.navyDark),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: InputBorder.none,
          labelStyle: AppText.body(size: 13, color: AppColors.muted),
        ),
        items: options
            .map(
              (o) => DropdownMenuItem(
                value: o,
                child: Text(
                  raw ? o : '${o[0].toUpperCase()}${o.substring(1)}',
                  style: AppText.body(size: 14, color: AppColors.navyDark),
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}
