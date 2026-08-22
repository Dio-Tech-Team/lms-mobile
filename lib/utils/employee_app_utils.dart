import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_providers.dart';
import '../users/login_page.dart';

double toDoubleOrZero(dynamic value) =>
    double.tryParse(value?.toString() ?? '0') ?? 0.0;

/// Formats an ISO date string as MM/DD/YYYY. Returns [placeholder] for
/// null/empty input (homepage used '', profile used '—' — pass whichever
/// fits the call site).
String formatIsoDate(String? isoDate, {String placeholder = ''}) {
  if (isoDate == null || isoDate.isEmpty) return placeholder;
  try {
    final date = DateTime.parse(isoDate);
    return '${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')}/${date.year}';
  } catch (_) {
    return isoDate;
  }
}

/// Converts snake_case to Title Case (e.g. employment_status values).
String titleCaseOrPlaceholder(String? value, {String placeholder = ''}) {
  if (value == null || value.isEmpty) return placeholder;
  return value
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

/// Unwraps the various shapes the credits endpoint can come back in —
/// {"credits": [...]}, {"data": [...]}, or a bare list.
List<dynamic> extractCreditsList(dynamic creditData) {
  if (creditData is Map) {
    if (creditData["credits"] is List) return creditData["credits"];
    if (creditData["data"] is List) return creditData["data"];
    return <dynamic>[];
  } else if (creditData is List) {
    return creditData;
  }
  return <dynamic>[];
}

/// Shows the shared "Confirm Logout" dialog and, if confirmed, logs the
/// user out and returns to the login screen.
Future<void> confirmAndLogout(BuildContext context) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.warning, color: Colors.red),
          SizedBox(width: 10),
          Text('Confirm Logout'),
        ],
      ),
      content: const Text('Do you want to logout?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('No', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );

  if (confirm == true && context.mounted) {
    Provider.of<AuthProvider>(context, listen: false).logout();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }
}
