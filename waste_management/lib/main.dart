import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:waste_management/screens/auth/forget_password_screen.dart';
import 'package:waste_management/screens/auth/loading_screen.dart';
import 'package:waste_management/screens/auth/sign_in_screen.dart';
import 'package:waste_management/screens/auth/sign_up_screen.dart';
import 'package:waste_management/screens/city_management_screens/admin_assign_history_screen.dart';
import 'package:waste_management/screens/city_management_screens/admin_breakdown_list.dart';
import 'package:waste_management/screens/city_management_screens/admin_cleanliness_issue_list_screen.dart';
import 'package:waste_management/screens/city_management_screens/admin_fetch_active_trucks_screen.dart';
import 'package:waste_management/screens/city_management_screens/admin_home_screen.dart';
import 'package:waste_management/screens/city_management_screens/admin_route_create_screen.dart';
import 'package:waste_management/screens/city_management_screens/admin_route_list_screen.dart';
import 'package:waste_management/screens/city_management_screens/admin_special_garbage_request_screen.dart';
import 'package:waste_management/screens/driver_screens/driver_assignment_screen.dart';
import 'package:waste_management/screens/driver_screens/driver_cleanliness_issue_list.dart';
import 'package:waste_management/screens/driver_screens/driver_home_screen.dart';
import 'package:waste_management/screens/driver_screens/driver_profile_screen.dart';
import 'package:waste_management/screens/driver_screens/driver_route_list_screen.dart';
import 'package:waste_management/screens/driver_screens/driver_special_garbage_screen.dart';
import 'package:waste_management/screens/driver_screens/drver_breakdown_screen.dart';
import 'package:waste_management/screens/resident_screens/resident-detailtwo_screen.dart';
import 'package:waste_management/screens/resident_screens/resident_Location_picker_screen.dart';
import 'package:waste_management/screens/resident_screens/resident_active_route_screen.dart';
import 'package:waste_management/screens/resident_screens/resident_detail_screen.dart';
import 'package:waste_management/screens/resident_screens/resident_home_screen.dart';
import 'package:waste_management/screens/resident_screens/resident_notification_screen.dart';
import 'package:waste_management/screens/resident_screens/resident_profile_screen.dart';
import 'package:waste_management/screens/resident_screens/resident_recent_cleanliness_report_screen.dart';
import 'package:waste_management/screens/resident_screens/resident_report_cleanliness_issue_screen.dart';
import 'package:waste_management/screens/resident_screens/resident_special_garbage_request_screen.dart';
import 'package:waste_management/utils/protected_route.dart';
import 'package:waste_management/utils/theme.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter binding is initialized
  await Firebase.initializeApp(); // Initialize Firebase
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Waste Management System',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/resident_profile', // Set initial route to LoadingScreen
      routes: {
        // Public routes - accessible without authentication
        '/loading_screen': (context) => const LoadingScreen(),
        '/sign_in_page': (context) => const SignInPage(),
        '/sign_up_page': (context) => const SignupScreen(),
        '/forget_passowrd': (context) => const ForgotPasswordScreen(),
        
        // Resident-only routes
        '/resident_home': (context) => ProtectedRoute(
          allowedRoles: ['resident'],
          child: const ResidentHome(),
        ),
        '/resident_detail': (context) => ProtectedRoute(
          allowedRoles: ['resident'],
          child: const DetailPage(),
        ),
        '/resident_detailtwo': (context) => ProtectedRoute(
          allowedRoles: ['resident'],
          child: const DetailTwoScreen(),
        ),
        '/resident_profile': (context) => ProtectedRoute(
          allowedRoles: ['resident'],
          child: const ResidentProfileScreen(),
        ),
        '/report_cleanliness_issue': (context) => ProtectedRoute(
          allowedRoles: ['resident'],
          child: ReportCleanlinessIssuePage(),
        ),
        '/recent_report_and_request': (context) => ProtectedRoute(
          allowedRoles: ['resident'],
          child: RecentReportsRequestsPage(),
        ),
        '/active_route_screen': (context) => ProtectedRoute(
          allowedRoles: ['resident'],
          child: ResidentActiveRoutesScreen(),
        ),
        '/resident_location_picker_screen': (context) => ProtectedRoute(
          allowedRoles: ['resident'],
          child: ResidentLocationPickerScreen(),
        ),
        '/resident_notification_screen': (context) => ProtectedRoute(
          allowedRoles: ['resident'],
          child: ResidentNotificationScreen(),
        ),
        '/resident_special_garbage_request_screen': (context) => ProtectedRoute(
          allowedRoles: ['resident'],
          child: SpecialGarbageRequestsScreen(),
        ),
        
        // Driver-only routes
        '/driver_home': (context) => ProtectedRoute(
          allowedRoles: ['driver'],
          child: const DriverHome(),
        ),
        '/driver_profile': (context) => ProtectedRoute(
          allowedRoles: ['driver'],
          child: DriverProfileScreen(),
        ),
        '/driver_route_list': (context) => ProtectedRoute(
          allowedRoles: ['driver'],
          child: DriverRouteListScreen(),
        ),
        '/driver_cleanliness_issue_list': (context) => ProtectedRoute(
          allowedRoles: ['driver'],
          child: DriverCleanlinessIssueListScreen(),
        ),
        '/breakdown_screen': (context) => ProtectedRoute(
          allowedRoles: ['driver'],
          child: BreakdownReportScreen(),
        ),
        '/driver_special_garbage_screen': (context) => ProtectedRoute(
          allowedRoles: ['driver'],
          child: DriverSpecialGarbageScreen(),
        ),
        '/driver_assignment_screen': (context) => ProtectedRoute(
          allowedRoles: ['driver'],
          child: DriverAssignmentScreen(),
        ),
        
        // City Management/Admin-only routes
        '/admin_home': (context) => ProtectedRoute(
          allowedRoles: ['cityManagement'],
          child: const AdminHome(),
        ),
        '/admin_create_route': (context) => ProtectedRoute(
          allowedRoles: ['cityManagement'],
          child: AdminRouteCreationScreen(),
        ),
        '/admin_route_list': (context) => ProtectedRoute(
          allowedRoles: ['cityManagement'],
          child: AdminRouteListScreen(),
        ),
        '/admin_cleanliness_issue_list': (context) => ProtectedRoute(
          allowedRoles: ['cityManagement'],
          child: AdminCleanlinessIssueListScreen(),
        ),
        '/admin_breakdown': (context) => ProtectedRoute(
          allowedRoles: ['cityManagement'],
          child: AdminBreakdownListScreen(),
        ),
        '/admin_special_garbage_requests': (context) => ProtectedRoute(
          allowedRoles: ['cityManagement'],
          child: AdminSpecialGarbageIssuesScreen(),
        ),
        '/admin_history': (context) => ProtectedRoute(
          allowedRoles: ['cityManagement'],
          child: AdminAssignedRequestsHistoryScreen(),
        ),
        '/admin_active_drivers_screen': (context) => ProtectedRoute(
          allowedRoles: ['cityManagement'],
          child: AdminActiveDriversScreen(),
        ),
      },
    );
  }
}