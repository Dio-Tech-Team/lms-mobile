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
  }) async {
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
          'leave_configuration_id': leaveConfigurationId,
          'start_date': _formatDate(startDate),
          'end_date': _formatDate(endDate),
          'days_applied': daysApplied,
          'reason': reason,
        }),
      );

      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {}

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': body['message'] ?? 'Leave application submitted successfully.',
          'data': body['data'],
        };
      }
      return {
        'success': false,
        'message': body['message'] ??
            _firstValidationError(body) ??
            'Failed to submit leave application (${response.statusCode}).',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: Unable to connect to server.',
      };
    }
  }

  static Future<Map<String, dynamic>> getMyApplications({
    required String token,
    String? status,
    int page = 1,
  }) async {
    final queryParams = <String, String>{'page': '$page'};
    if (status != null) queryParams['status'] = status;
    
    // ✅ FIXED: Correct endpoint for GET /api/leave-applications
    final uri = Uri.parse('$baseUrl/leave-applications')
        .replace(queryParameters: queryParams);

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
        return {
          'success': true,
          'data': body['data'] ?? [],
          'currentPage': body['current_page'] ?? 1,
          'lastPage': body['last_page'] ?? 1,
        };
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Failed to load leave applications (${response.statusCode}).',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: Unable to connect to server.',
      };
    }
  }

  static Future<Map<String, dynamic>> getApplicationPdfBytes({
    required int applicationId,
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl/leave-applications/$applicationId/pdf');

    try {
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/pdf',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'bytes': response.bodyBytes,
        };
      }

      String message = 'Failed to load PDF (${response.statusCode}).';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        message = body['message'] ?? message;
      } catch (_) {}

      return {'success': false, 'message': message};
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: Unable to connect to server.',
      };
    }
  }

  static String? _firstValidationError(Map<String, dynamic> body) {
    final errors = body['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final firstList = errors.values.first;
      if (firstList is List && firstList.isNotEmpty) {
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