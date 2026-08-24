import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_providers.dart';
import '../users/login_page.dart';

double toDoubleOrZero(dynamic value) =>
    double.tryParse(value?.toString() ?? '0') ?? 0.0;

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

String titleCaseOrPlaceholder(String? value, {String placeholder = ''}) {
  if (value == null || value.isEmpty) return placeholder;
  return value
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

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
