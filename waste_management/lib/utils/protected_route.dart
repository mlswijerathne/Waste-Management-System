import 'package:flutter/material.dart';
import 'package:waste_management/utils/route_guard.dart';

class ProtectedRoute extends StatefulWidget {
  final Widget child;
  final List<String> allowedRoles;
  
  const ProtectedRoute({
    Key? key,
    required this.child,
    required this.allowedRoles,
  }) : super(key: key);

  @override
  State<ProtectedRoute> createState() => _ProtectedRouteState();
}

class _ProtectedRouteState extends State<ProtectedRoute> {
  bool _isChecking = true;
  bool _hasAccess = false;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    bool hasAccess = await RouteGuard.checkUserRole(context, widget.allowedRoles);
    
    if (mounted) {
      setState(() {
        _isChecking = false;
        _hasAccess = hasAccess;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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