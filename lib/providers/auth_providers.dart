import 'package:flutter/material.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  String? _token;

  bool get isLoggedIn => _isLoggedIn;
  String? get token => _token;
<<<<<<< Updated upstream
=======
  Map<String, dynamic>? get user => _user;
  int? get employeeId => _user?['employee_id'];
>>>>>>> Stashed changes

  void login(String token) {
    _token = token;
    _isLoggedIn = true;
    notifyListeners();
  }

  void logout() {
    _token = null;
    _isLoggedIn = false;
    notifyListeners();
  }
}