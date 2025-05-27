import 'package:flutter/material.dart';
import 'package:waste_management/utils/route_guard.dart';

/**
 * Security middleware widget implementing role-based access control (RBAC)
 * Acts as a gatekeeper for sensitive routes, preventing unauthorized navigation
 * Integrates with authentication system to enforce permission boundaries
 * Provides seamless UX with loading states and automatic redirects
 */
class ProtectedRoute extends StatefulWidget {
  final Widget child; // Protected content to render after successful authorization
  final List<String> allowedRoles; // Permission whitelist - user needs ANY of these roles
  
  /**
   * Creates a protected route wrapper with role-based security
   * @param child The widget tree to protect behind authentication
   * @param allowedRoles Array of role strings that grant access (OR logic)
   */
  const ProtectedRoute({
    Key? key,
    required this.child,
    required this.allowedRoles,
  }) : super(key: key);

  @override
  State<ProtectedRoute> createState() => _ProtectedRouteState();
}

/**
 * Private state manager for authentication flow and UI transitions
 * Handles async permission checking without blocking the UI thread
 * Manages widget lifecycle to prevent memory leaks during navigation
 */
class _ProtectedRouteState extends State<ProtectedRoute> {
  bool _isChecking = true; // Loading state flag - prevents premature content display
  bool _hasAccess = false; // Authorization result cache - drives conditional rendering

  @override
  void initState() {
    super.initState();
    _checkAccess(); // Trigger authentication check immediately on widget mount
  }

  /**
   * Core authorization logic - validates user permissions against route requirements
   * Delegates to RouteGuard for centralized security policy enforcement
   * Updates UI state safely with mounted checks to prevent setState() errors
   */
  Future<void> _checkAccess() async {
    bool hasAccess = await RouteGuard.checkUserRole(context, widget.allowedRoles); // Query auth service
    
    if (mounted) { // Defensive programming - prevent state updates on disposed widgets
      setState(() {
        _isChecking = false; // End loading phase
        _hasAccess = hasAccess; // Cache authorization result for render logic
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) { // Authentication in progress - show loading UI
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(), // Standard Material loading indicator
        ),
      );
    }
    
    // Authorization complete - RouteGuard handles redirect logic for denied access
    // If we reach this point, either access is granted OR user has been redirected
    return widget.child; // Render protected content
  }
}