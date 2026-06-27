import 'package:flutter/material.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  String? _token;
  Map<String, dynamic>? _user;

  bool get isLoggedIn => _isLoggedIn;
  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  int? get employeeId => _user?['employee_id'];

  void login(String token, Map<String, dynamic> user) {
    _token = token;
    _user = user;
    _isLoggedIn = true;
    notifyListeners();
  }

  void logout() {
    _token = null;
    _user = null;
    _isLoggedIn = false;
    notifyListeners();
  }
}