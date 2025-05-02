import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:waste_management/service/auth_service.dart';
import 'package:waste_management/models/userModel.dart';

class AuthStatus with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  UserModel? _currentUser;
  bool _isLoading = true;

  AuthStatus() {
    _init();
  }

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  String? get userRole => _currentUser?.role;

  Future<void> _init() async {
    // Set up listener for auth state changes
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        // User is signed in, get user details
        _currentUser = await _authService.getCurrentUser();
      } else {
        // User is signed out
        _currentUser = null;
      }
      _isLoading = false;
      notifyListeners();
    });
  }

  // Check if user has a specific role
  bool hasRole(String role) {
    return _currentUser?.role == role;
  }

  // Check if user has any of the specified roles
  bool hasAnyRole(List<String> roles) {
    if (_currentUser == null) return false;
    return roles.contains(_currentUser!.role);
  }
}