import 'package:flutter/material.dart';
import 'package:waste_management/service/auth_service.dart';
import 'package:waste_management/models/userModel.dart';

class RouteGuard {
  static final AuthService _authService = AuthService();
  
  // Check if current user has required role
  static Future<bool> checkUserRole(BuildContext context, List<String> allowedRoles) async {
    try {
      UserModel? currentUser = await _authService.getCurrentUser();
      
      // If no user is logged in, redirect to login
      if (currentUser == null) {
        // If not already on sign in page, navigate there
        if (ModalRoute.of(context)?.settings.name != '/sign_in_page') {
          Navigator.of(context).pushReplacementNamed('/sign_in_page');
        }
        return false;
      }
      
      // Check if user role is in allowed roles
      if (allowedRoles.contains(currentUser.role)) {
        return true;
      } else {
        // Redirect based on actual role
        _redirectBasedOnRole(context, currentUser.role);
        return false;
      }
    } catch (e) {
      print('Error checking user role: $e');
      // On error, redirect to sign in
      Navigator.of(context).pushReplacementNamed('/sign_in_page');
      return false;
    }
  }
  
  // Redirect user to appropriate home screen based on role
  static void _redirectBasedOnRole(BuildContext context, String role) {
    switch (role) {
      case 'resident':
        Navigator.of(context).pushReplacementNamed('/resident_home');
        break;
      case 'driver':
        Navigator.of(context).pushReplacementNamed('/driver_home');
        break;
      case 'cityManagement':
        Navigator.of(context).pushReplacementNamed('/admin_home');
        break;
      default:
        Navigator.of(context).pushReplacementNamed('/sign_in_page');
    }
  }
}