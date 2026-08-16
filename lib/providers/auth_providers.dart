import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../variables.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  String? _token;
  Map<String, dynamic>? _user;
  bool _isInitializing = true;
  Map<String, dynamic>? _employee;
  bool _isLoadingEmployee = false;

  static const Duration _networkTimeout = Duration(seconds: 20);

  bool get isLoggedIn => _isLoggedIn;
  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  int? get employeeId => _user?['employee_id'];
  bool get isInitializing => _isInitializing;

  Map<String, dynamic>? get employee => _employee;
  bool get isLoadingEmployee => _isLoadingEmployee;
  String? get employmentStatus => _employee?['employment_status']?.toString();
  String? get dateHired => _employee?['date_hired']?.toString();
  bool get mustChangePassword => _user?['must_change_password'] == true;

  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final userJson = prefs.getString('auth_user');

    if (token != null && userJson != null) {
      _token = token;
      _user = jsonDecode(userJson) as Map<String, dynamic>;
      _isLoggedIn = true;
    }

    _isInitializing = false;
    notifyListeners();
  }

  Future<void> login(String token, Map<String, dynamic> user) async {
    _token = token;
    _user = user;
    _isLoggedIn = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('auth_user', jsonEncode(user));

    notifyListeners();
  }

  Future<void> clearMustChangePassword() async {
    if (_user == null) return;

    _user = {..._user!, 'must_change_password': false};

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_user', jsonEncode(_user));

    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    _isLoggedIn = false;
    _employee = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_user');

    notifyListeners();
  }

  Future<void> fetchEmployeeDetails({bool silent = false}) async {
    if (_token == null || employeeId == null) return;

    if (!silent) {
      _isLoadingEmployee = true;
      notifyListeners();
    }

    try {
      final res = await http
          .get(
            Uri.parse('$baseUrl/employees/$employeeId'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $_token',
            },
          )
          .timeout(_networkTimeout);

      if (res.statusCode == 200) {
        _employee = jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {
    } finally {
      _isLoadingEmployee = false;
      notifyListeners();
    }
  }
}