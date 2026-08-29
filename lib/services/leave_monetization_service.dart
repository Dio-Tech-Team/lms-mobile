import 'dart:convert';
import 'package:http/http.dart' as http;
import '../variables.dart';

class LeaveMonetizationService {
  static const Duration _timeout = Duration(seconds: 10);

  static Future<Map<String, dynamic>> getLeaveConfigurations({
    required String token,
  }) async {
    try {
      final res = await http
          .get(
            Uri.parse('$baseUrl/leave-configurations'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final List<dynamic> list = decoded is List
            ? decoded
            : List<dynamic>.from(decoded['data'] ?? []);
        return {'success': true, 'data': list};
      }
      return {
        'success': false,
        'message': 'Failed to load leave types (${res.statusCode})',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error while loading leave types.',
      };
    }
  }

  static Future<Map<String, dynamic>> getMyRequests({
    required String token,
    String? status,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/leave-monetizations').replace(
        queryParameters: (status != null && status.isNotEmpty)
            ? {'status': status}
            : null,
      );

      final res = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final List<dynamic> list = decoded is Map && decoded['data'] is List
            ? List<dynamic>.from(decoded['data'])
            : (decoded is List ? decoded : []);
        return {'success': true, 'data': list};
      }
      return {
        'success': false,
        'message': 'Failed to load requests (${res.statusCode})',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error while loading requests.',
      };
    }
  }

  static Future<Map<String, dynamic>> apply({
    required String token,
    required int leaveConfigurationId,
    required double daysMonetized,
    String? reason,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/leave-monetizations'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'leave_configuration_id': leaveConfigurationId,
              'days_monetized': daysMonetized,
              if (reason != null && reason.trim().isNotEmpty)
                'reason': reason.trim(),
            }),
          )
          .timeout(_timeout);

      final decoded = res.body.isNotEmpty
          ? jsonDecode(res.body)
          : <String, dynamic>{};

      if (res.statusCode == 201) {
        return {
          'success': true,
          'message': decoded['message'] ?? 'Request submitted successfully.',
          'data': decoded['data'],
        };
      }

      return {
        'success': false,
        'message':
            decoded['message'] ??
            'Failed to submit request (${res.statusCode}).',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Request timed out. Please try again.',
      };
    }
  }

  static Future<Map<String, dynamic>> cancelRequest({
    required String token,
    required int monetizationId,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/leave-monetizations/$monetizationId/cancel'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);

      final decoded = res.body.isNotEmpty
          ? jsonDecode(res.body)
          : <String, dynamic>{};

      if (res.statusCode == 200) {
        return {
          'success': true,
          'message': decoded['message'] ?? 'Request cancelled.',
        };
      }

      return {
        'success': false,
        'message':
            decoded['message'] ??
            'Failed to cancel request (${res.statusCode}).',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Request timed out. Please try again.',
      };
    }
  }
}
