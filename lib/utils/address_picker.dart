import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'app_theme.dart';

/// A single PSGC entry — province, city/municipality or barangay.
class PsgcEntry {
  final String code;
  final String name;

  const PsgcEntry({required this.code, required this.name});

  factory PsgcEntry.fromJson(Map<String, dynamic> json) =>
      PsgcEntry(code: json['code'].toString(), name: json['name'].toString());
}

/// psgc.cloud lookups with module-level caching, mirroring the web
/// component: the API is rate limited, so a list is fetched once per
/// app session and reused.
///
/// Note the documented /api/v1/ routes are not actually deployed —
/// everything lives under /api/ with full-length PSGC codes.
class PsgcService {
  PsgcService._();

  static const _base = 'https://psgc.cloud/api';
  static const _timeout = Duration(seconds: 12);

  static List<PsgcEntry>? _provinces;
  static final Map<String, List<PsgcEntry>> _localities = {};
  static final Map<String, List<PsgcEntry>> _barangays = {};

  static Future<List<PsgcEntry>> _getList(String url) async {
    final res = await http
        .get(Uri.parse(url), headers: {'Accept': 'application/json'})
        .timeout(_timeout);

    if (res.statusCode != 200) {
      throw Exception('PSGC responded ${res.statusCode}');
    }

    final decoded = jsonDecode(res.body);
    final raw = decoded is List ? decoded : (decoded['data'] ?? []);

    final list = (raw as List)
        .map((e) => PsgcEntry.fromJson(e as Map<String, dynamic>))
        .toList();

    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  static Future<List<PsgcEntry>> provinces() async {
    if (_provinces != null) return _provinces!;
    _provinces = await _getList('$_base/provinces');
    return _provinces!;
  }

  static Future<List<PsgcEntry>> localities(String provinceCode) async {
    final cached = _localities[provinceCode];
    if (cached != null) return cached;

    final list = await _getList(
      '$_base/provinces/$provinceCode/cities-municipalities',
    );
    _localities[provinceCode] = list;
    return list;
  }

  static Future<List<PsgcEntry>> barangays(String localityCode) async {
    final cached = _barangays[localityCode];
    if (cached != null) return cached;

    final list = await _getList(
      '$_base/cities-municipalities/$localityCode/barangays',
    );
    _barangays[localityCode] = list;
    return list;
  }
}

/// Full-screen searchable list. A phone can't scroll 80+ provinces
/// comfortably in a dropdown, so selection happens on its own page.
class _PsgcSearchPage extends StatefulWidget {
  final String title;
  final List<PsgcEntry> options;

  const _PsgcSearchPage({required this.title, required this.options});

  @override
  State<_PsgcSearchPage> createState() => _PsgcSearchPageState();
}

class _PsgcSearchPageState extends State<_PsgcSearchPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.options
        : widget.options
              .where((o) => o.name.toLowerCase().contains(q))
              .toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.navyDark,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.title,
          style: AppText.display(size: 17, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              style: AppText.body(size: 14, color: AppColors.navyDark),
              decoration: InputDecoration(
                hintText: 'Search…',
                hintStyle: AppText.body(size: 14, color: AppColors.muted),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 19,
                  color: AppColors.muted,
                ),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.hairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.hairline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.navy),
                ),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No matches.',
                      style: AppText.body(size: 13, color: AppColors.muted),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.hairline),
                    itemBuilder: (_, i) => ListTile(
                      dense: true,
                      title: Text(
                        filtered[i].name,
                        style: AppText.body(
                          size: 14,
                          color: AppColors.navyDark,
                        ),
                      ),
                      onTap: () => Navigator.of(context).pop(filtered[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Chained province → city/municipality → barangay picker that writes a
/// composed address string, matching the web form's format exactly:
///   place of birth   "City, Province"
///   residence        "Brgy. X, City, Province"
///
/// Falls back to a plain text field when psgc.cloud can't be reached —
/// on mobile data that's a real possibility, and an employee shouldn't
/// be blocked from saving the rest of their profile because of it.
class AddressPicker extends StatefulWidget {
  final String label;
  final String? initialValue;
  final bool withBarangay;
  final ValueChanged<String?> onChanged;

  const AddressPicker({
    super.key,
    required this.label,
    required this.onChanged,
    this.initialValue,
    this.withBarangay = false,
  });

  @override
  State<AddressPicker> createState() => _AddressPickerState();
}

class _AddressPickerState extends State<AddressPicker> {
  PsgcEntry? _province;
  PsgcEntry? _locality;
  PsgcEntry? _barangay;

  bool _loading = false;
  bool _manual = false;
  bool _apiFailed = false;
  String? _error;

  /// A stored address is a plain string with no PSGC codes, so it can't be
  /// mapped back onto the pickers. Show it until the user chooses to change.
  bool _locked = false;
  late final TextEditingController _manualController;

  @override
  void initState() {
    super.initState();
    _manualController = TextEditingController(text: widget.initialValue ?? '');
    _locked = (widget.initialValue ?? '').trim().isNotEmpty;
  }

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  String get _composed {
    final parts = <String>[];
    if (widget.withBarangay && _barangay != null) {
      parts.add('Brgy. ${_barangay!.name}');
    }
    if (_locality != null) parts.add(_locality!.name);
    if (_province != null) parts.add(_province!.name);
    return parts.join(', ');
  }

  void _emit() {
    final value = _composed;
    // Only emit something real, so a half-finished selection can't wipe
    // an address that was already on file.
    if (value.isNotEmpty) widget.onChanged(value);
  }

  Future<void> _pick({
    required String title,
    required Future<List<PsgcEntry>> Function() fetch,
    required ValueChanged<PsgcEntry> onPicked,
  }) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    List<PsgcEntry> options;
    try {
      options = await fetch();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _apiFailed = true;
        _manual = true;
        _locked = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() => _loading = false);

    final picked = await Navigator.of(context).push<PsgcEntry>(
      MaterialPageRoute(
        builder: (_) => _PsgcSearchPage(title: title, options: options),
      ),
    );

    if (picked != null && mounted) {
      setState(() => onPicked(picked));
      _emit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.label,
              style: AppText.body(size: 13, color: AppColors.muted),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _manual = !_manual;
                  _locked = false;
                  if (_manual) {
                    _manualController.text = widget.initialValue ?? _composed;
                  }
                });
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _manual ? 'Use dropdowns' : 'Enter manually',
                style: AppText.body(size: 11.5, color: AppColors.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        if (_locked)
          _lockedView()
        else if (_manual)
          _manualView()
        else
          _pickerView(),

        if (_error != null) ...[
          const SizedBox(height: 5),
          Text(
            _error!,
            style: AppText.body(size: 11.5, color: AppColors.amber),
          ),
        ],
      ],
    );
  }

  Widget _lockedView() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            widget.initialValue ?? '',
            style: AppText.body(size: 14, color: AppColors.navyDark),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => setState(() => _locked = false),
          child: Text(
            'Change',
            style: AppText.body(
              size: 13,
              weight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
        ),
      ],
    );
  }

  Widget _manualView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _manualController,
          onChanged: widget.onChanged,
          style: AppText.body(size: 14, color: AppColors.navyDark),
          decoration: InputDecoration(
            hintText: 'Type the full address',
            hintStyle: AppText.body(size: 13.5, color: AppColors.muted),
            isDense: true,
            border: InputBorder.none,
          ),
        ),
        if (_apiFailed)
          Text(
            'Address service unavailable — entering manually.',
            style: AppText.body(size: 11.5, color: AppColors.amber),
          ),
      ],
    );
  }

  Widget _pickerView() {
    return Column(
      children: [
        _row(
          'Province',
          _province?.name,
          () => _pick(
            title: 'Select Province',
            fetch: PsgcService.provinces,
            onPicked: (p) {
              _province = p;
              _locality = null;
              _barangay = null;
            },
          ),
        ),
        _row(
          'City / Municipality',
          _locality?.name,
          _province == null
              ? null
              : () => _pick(
                  title: 'Select City / Municipality',
                  fetch: () => PsgcService.localities(_province!.code),
                  onPicked: (l) {
                    _locality = l;
                    _barangay = null;
                  },
                ),
        ),
        if (widget.withBarangay)
          _row(
            'Barangay',
            _barangay?.name,
            _locality == null
                ? null
                : () => _pick(
                    title: 'Select Barangay',
                    fetch: () => PsgcService.barangays(_locality!.code),
                    onPicked: (b) => _barangay = b,
                  ),
          ),
      ],
    );
  }

  Widget _row(String placeholder, String? value, VoidCallback? onTap) {
    final disabled = onTap == null;

    return InkWell(
      onTap: _loading ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? placeholder,
                style: AppText.body(
                  size: 14,
                  color: value != null
                      ? AppColors.navyDark
                      : (disabled
                            ? AppColors.muted.withOpacity(0.5)
                            : AppColors.muted),
                ),
              ),
            ),
            if (_loading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.muted,
                ),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                size: 19,
                color: disabled
                    ? AppColors.muted.withOpacity(0.4)
                    : AppColors.muted,
              ),
          ],
        ),
      ),
    );
  }
}
