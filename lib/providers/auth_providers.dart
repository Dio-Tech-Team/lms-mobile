import 'package:flutter/material.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  String? _token;

  bool get isLoggedIn => _isLoggedIn;
  String? get token => _token;

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