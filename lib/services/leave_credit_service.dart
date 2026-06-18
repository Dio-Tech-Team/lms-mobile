import 'dart:convert';
import 'package:http/http.dart' as http;
import '../variables.dart';

class LeaveCreditService {
  static Future<Map<String, dynamic>> getCredits(int employeeId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/employees/$employeeId/leave-credits'),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {"success": true, "data": data};
      } else {
        return {"success": false, "message": data["message"] ?? "Failed to load credits."};
      }
    } catch (e) {
      return {"success": false, "message": "Network error: Unable to connect."};
    }
  }
}