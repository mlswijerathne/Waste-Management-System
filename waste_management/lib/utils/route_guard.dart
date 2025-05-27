import 'package:flutter/material.dart';
import 'package:waste_management/service/auth_service.dart';
import 'package:waste_management/models/userModel.dart';

/**
 * Centralized security enforcement layer for role-based access control (RBAC)
 * Implements authentication gates and intelligent routing based on user permissions
 * Provides unified navigation logic with automatic role-appropriate redirects
 * Acts as the single source of truth for authorization decisions across the app
 */
class RouteGuard {
  static final AuthService _authService = AuthService(); // Service dependency - handles token validation and user retrieval
  
  /**
   * Primary authorization gate - validates user permissions against route requirements
   * Implements security-first design: deny by default, explicit allow on match
   * Handles complete authentication flow including error cases and redirect logic
   * @param context Navigation context for route transitions
   * @param allowedRoles Permission whitelist - user needs ANY role to proceed
   * @returns Promise<boolean> - true for authorized access, false for denied (with redirect)
   */
  static Future<bool> checkUserRole(BuildContext context, List<String> allowedRoles) async { // Main security checkpoint
    try { // Defensive error handling for auth service failures
      UserModel? currentUser = await _authService.getCurrentUser(); // Query current session state
      
      if (currentUser == null) { // Unauthenticated user detected
        if (ModalRoute.of(context)?.settings.name != '/sign_in_page') { // Loop prevention check
          Navigator.of(context).pushReplacementNamed('/sign_in_page'); // Force authentication flow
        }
        return false; // Security policy: deny all unauthenticated requests
      }
      
      if (allowedRoles.contains(currentUser.role)) { // Permission validation against whitelist
        return true; // Authorization granted - allow route access
      } else { // User authenticated but lacks required permissions
        _redirectBasedOnRole(context, currentUser.role); // Smart redirect to user's permitted area
        return false; // Security policy: deny unauthorized role access
      }
    } catch (e) { // Exception handling for service failures
      print('Error checking user role: $e'); // Debug logging for troubleshooting
      Navigator.of(context).pushReplacementNamed('/sign_in_page'); // Fail-safe: force re-authentication
      return false; // Security policy: deny access on system errors
    }
  }
  
  /**
   * Intelligent navigation dispatcher based on user role hierarchy
   * Prevents users from being stuck on unauthorized pages
   * Maps business roles to appropriate UI dashboards
   * Implements graceful degradation for unknown roles
   */
  static void _redirectBasedOnRole(BuildContext context, String role) { // Role-based routing logic
    switch (role) { // Role hierarchy mapping
      case 'resident': // End-user role - citizens reporting issues
        Navigator.of(context).pushReplacementNamed('/resident_home'); // Consumer dashboard
        break; // Exit switch
      case 'driver': // Field worker role - cleanup crew members
        Navigator.of(context).pushReplacementNamed('/driver_home'); // Operational dashboard
        break; // Exit switch
      case 'cityManagement': // Administrator role - system managers
        Navigator.of(context).pushReplacementNamed('/admin_home'); // Management dashboard
        break; // Exit switch
      default: // Unrecognized or invalid role
        Navigator.of(context).pushReplacementNamed('/sign_in_page'); // Security fallback - force re-auth
    }
  }
}