import 'package:flutter/material.dart';
import 'package:waste_management/utils/route_guard.dart';

/// A wrapper widget that protects routes based on user roles
/// This widget checks if the current user has the required role permissions
/// before displaying the protected content, showing a loading state during verification
class ProtectedRoute extends StatefulWidget {
  /// The widget to display if access is granted
  final Widget child;
  
  /// List of user roles that are allowed to access this route
  /// User must have at least one of these roles to gain access
  final List<String> allowedRoles;
  
  /// Constructor for creating a protected route with role-based access control
  const ProtectedRoute({
    Key? key,
    required this.child,
    required this.allowedRoles,
  }) : super(key: key);

  @override
  State<ProtectedRoute> createState() => _ProtectedRouteState();
}

/// Private state class that manages the access verification process
class _ProtectedRouteState extends State<ProtectedRoute> {
  /// Flag to track if the role verification is still in progress
  bool _isChecking = true;
  
  /// Flag to store the result of the access check
  /// True if user has required permissions, false otherwise
  bool _hasAccess = false;

  @override
  void initState() {
    super.initState();
    // Start the access verification process immediately when widget initializes
    _checkAccess();
  }

  /// Asynchronously verifies if the current user has access to this route
  /// Uses RouteGuard utility to check user roles against allowed roles
  /// Updates the widget state once verification is complete
  Future<void> _checkAccess() async {
    // Delegate role checking to RouteGuard utility
    bool hasAccess = await RouteGuard.checkUserRole(context, widget.allowedRoles);
    
    // Only update state if the widget is still mounted to avoid memory leaks
    if (mounted) {
      setState(() {
        _isChecking = false;  // Mark verification as complete
        _hasAccess = hasAccess;  // Store the access result
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while role verification is in progress
    if (_isChecking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    // If access is granted, show the child widget
    // The RouteGuard will handle redirects if access is denied
    return widget.child;
  }
}