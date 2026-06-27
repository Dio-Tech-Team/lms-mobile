import 'dart:convert';
import 'package:http/http.dart' as http;
import '../variables.dart';

class AuthService {
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "email": email,
          "password": password,
        }),
      );

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
        return {
          "success": false,
          "errors": data["errors"] ?? {"form": ["Validation failed."]},
        };
      } else {
        return {
          "success": false,
          "message": data["message"] ?? "Unexpected server error.",
        };
      }
    } catch (e) {
      return {
        "success": false,
        "message": "Network error: Unable to connect to server.",
      };
    }
  }
}