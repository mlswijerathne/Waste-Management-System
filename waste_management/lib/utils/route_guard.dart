import 'package:flutter/material.dart';
import 'package:waste_management/service/auth_service.dart';
import 'package:waste_management/models/userModel.dart';

/// Utility class for role-based route protection and navigation control
/// Handles user authentication verification and automatic redirects based on user roles
class RouteGuard {
  /// Singleton instance of AuthService for user authentication operations
  static final AuthService _authService = AuthService();
  
  /// Verifies if the current user has permission to access a route with specific role requirements
  /// Returns true if access is granted, false if denied (with automatic redirect)
  /// Handles unauthenticated users by redirecting to sign-in page
  // Check if current user has required role
  static Future<bool> checkUserRole(BuildContext context, List<String> allowedRoles) async {
    try {
      // Fetch current authenticated user from the auth service
      UserModel? currentUser = await _authService.getCurrentUser();
      
      // If no user is logged in, redirect to login
      if (currentUser == null) {
        // If not already on sign in page, navigate there
        if (ModalRoute.of(context)?.settings.name != '/sign_in_page') { // Prevent navigation loop
          Navigator.of(context).pushReplacementNamed('/sign_in_page'); // Replace current route to prevent back navigation
        }
        return false; // Deny access for unauthenticated users
      }
      
      // Check if user role is in allowed roles
      if (allowedRoles.contains(currentUser.role)) { // Verify user's role against permitted roles
        return true; // Grant access if role matches
      } else {
        // Redirect based on actual role
        _redirectBasedOnRole(context, currentUser.role); // Send user to their appropriate home screen
        return false; // Deny access to this specific route
      }
    } catch (e) {
      print('Error checking user role: $e'); // Log authentication errors for debugging
      // On error, redirect to sign in
      Navigator.of(context).pushReplacementNamed('/sign_in_page'); // Fallback to login on any error
      return false; // Deny access when verification fails
    }
  }
  
  /// Redirects authenticated users to their role-specific home screen
  /// Ensures users land on the correct dashboard based on their permissions
  /// Fallback to sign-in page for unrecognized roles
  // Redirect user to appropriate home screen based on role
  static void _redirectBasedOnRole(BuildContext context, String role) {
    switch (role) {
      case 'resident': // Regular app users/citizens
        Navigator.of(context).pushReplacementNamed('/resident_home'); // Navigate to resident dashboard
        break;
      case 'driver': // Waste collection drivers
        Navigator.of(context).pushReplacementNamed('/driver_home'); // Navigate to driver dashboard
        break;
      case 'cityManagement': // Administrative users
        Navigator.of(context).pushReplacementNamed('/admin_home'); // Navigate to admin dashboard
        break;
      default: // Unknown or invalid roles
        Navigator.of(context).pushReplacementNamed('/sign_in_page'); // Fallback to authentication
    }
  }
}