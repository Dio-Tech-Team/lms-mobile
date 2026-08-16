import 'dart:convert';
import 'dart:async';
import '../variables.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/login'),
            headers: {
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: jsonEncode({
              "login": email,
              "password": password,
            }),
          )
          .timeout(const Duration(seconds: 10));
 
      final data = jsonDecode(response.body);
 
      if (response.statusCode == 200) {
        return {
          "success": true,
          "token": data["token"],
          "user": data["user"],
        };
      } else if (response.statusCode == 401) {
        return {
          "success": false,
          "message": data["message"] ?? "Invalid email or password.",
        };
      } else if (response.statusCode == 422) {
        final errors = data["errors"] as Map<String, dynamic>?;
        final firstError = errors?.values.first?.first ?? "Validation failed.";
        return {
          "success": false,
          "message": firstError,
        };
      } else {
        return {
          "success": false,
          "message": data["message"] ?? "Unexpected server error.",
        };
      }
    } on TimeoutException {
      return {
        "success": false,
        "message":
            "Couldn't reach the server. Check your connection and try again.",
      };
    } catch (e) {
      return {
        "success": false,
        "message": "Network error: Unable to connect to server.",
      };
    }
  }
}