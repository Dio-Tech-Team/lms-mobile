import 'dart:convert';
import 'package:http/http.dart' as http;
import '../variables.dart';

class LeaveCreditService {
  static Future<Map<String, dynamic>> getCredits(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/dashboard/balances'),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // ✅ FIXED: Wraps raw array responses into the map structure HomePage expects
        if (decoded is List) {
          return {
            "success": true,
            "data": {
              "credits": decoded,
              "employee": "",
              "year": DateTime.now().year,
            }
          };
        }
        return {"success": true, "data": decoded};
      } else {
        String message = "Failed to load credits.";
        if (decoded is Map<String, dynamic> && decoded.containsKey('message')) {
          message = decoded['message'];
        }
        return {"success": false, "message": message};
      }
    } catch (e) {
      return {"success": false, "message": "Network error: Unable to connect."};
    }
  }
}