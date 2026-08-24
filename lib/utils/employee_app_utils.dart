import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_providers.dart';
import '../users/login_page.dart';

const Color _navy = Color(0xFF1B3B63);
const Color _text = Color(0xFF1E3A5F);
const Color _muted = Color(0xFF8A97A8);

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
    barrierColor: Colors.black.withOpacity(0.45),
    builder: (context) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 56),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _navy.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.logout_rounded,
                size: 16,
                color: _navy,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Confirm Logout',
              style: GoogleFonts.fraunces(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _text,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Are you sure you want to log out of your account?',
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: _muted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _muted,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.nunito(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _navy,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Logout',
                        style: GoogleFonts.nunito(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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