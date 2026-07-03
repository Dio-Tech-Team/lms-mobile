import 'dart:convert';
import 'package:http/http.dart' as http;
import '../variables.dart';

class LeaveApplicationService {
  static Future<Map<String, dynamic>> apply({
    required int leaveConfigurationId,
    required DateTime startDate,
    required DateTime endDate,
    required double daysApplied,
    required String token,
    String? reason,
  }) async{
    final uri = Uri.parse('$baseUrl/leave-applications');

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
    },
    body: jsonEncode({
      'leave_config_id': leaveConfigurationId,
          'start_date': _formatDate(startDate),
          'end_date': _formatDate(endDate),
          'days_applied': daysApplied,
          'reason': reason,
        }),
      );

      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(response.body) as Map<String, dynamic>;
      } catch(_) {

      }

      if (response.statusCode ==201){
        return{
          'success': true,
          'message': body['message'] ?? 'Leave application submitted successfully.',
          'data': body['data'],
        };
      }
      return{
        'success': false,
        'message': body['message'] ?? _firstValidationError(body) ??
        'Failed to submit leave application (${response.statusCode}).',
      };
    } catch (e) {
      return{
        'success': false,
        'message': 'Network error: Unable to connect to server.',
      };
    }
  }
    static String? _firstValidationError(Map<String, dynamic> body) {
    final errors = body['errors'];
    if (errors is Map && errors.isNotEmpty){
      final firstList = errors.values.first;
      if (firstList is List && firstList.isNotEmpty){
        return firstList.first.toString();
      }
    }
    return null;
  }
  static String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
  }
}

