import 'dart:convert';
import 'package:http/http.dart' as http;
import '../variables.dart';

class AttendanceService {
  /// The logged-in employee's own monthly attendance summaries
  /// (late / undertime minutes, VL deducted, LWOP, absences).
  static Future<Map<String, dynamic>> getMyAttendance({
    required String token,
    int? year,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/my-attendance',
    ).replace(queryParameters: year != null ? {'year': '$year'} : null);

    try {
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {}

      if (response.statusCode == 200) {
        return {'success': true, 'data': body['data'] ?? []};
      }
      return {
        'success': false,
        'message':
            body['message'] ??
            'Failed to load tardiness records (${response.statusCode}).',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: Unable to connect to server.',
      };
    }
  }
}