import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
import 'package:waste_management/screens/city_management_screens/admin_notification_screen.dart';
import 'package:waste_management/screens/city_management_screens/admin_route_create_screen.dart';
import 'package:waste_management/screens/city_management_screens/admin_route_list_screen.dart';
import 'package:waste_management/screens/city_management_screens/admin_special_garbage_request_screen.dart';
import 'package:waste_management/screens/driver_screens/driver_assignment_screen.dart';
import 'package:waste_management/screens/driver_screens/driver_cleanliness_issue_list.dart';
import 'package:waste_management/screens/driver_screens/driver_home_screen.dart';
import 'package:waste_management/screens/driver_screens/driver_notification_screen.dart';
import 'package:waste_management/screens/driver_screens/driver_profile_screen.dart';
import 'package:waste_management/screens/driver_screens/driver_route_list_screen.dart';
import 'package:waste_management/screens/driver_screens/driver_special_garbage_screen.dart';
import 'package:waste_management/screens/driver_screens/drver_breakdown_screen.dart';
import 'package:waste_management/screens/resident_screens/resident-detailtwo_screen.dart';
import 'package:waste_management/screens/resident_screens/resident_Location_picker_screen.dart';
import 'package:waste_management/screens/resident_screens/resident_active_route_screen.dart';
import 'package:waste_management/screens/resident_screens/resident_detail_screen.dart';
import 'package:waste_management/screens/resident_screens/resident_home_screen.dart';
import 'package:waste_management/screens/resident_screens/resident_cleanliness%20issue_feedback_screen.dart';
import 'package:waste_management/screens/resident_screens/resident_notification_screen.dart';
import 'package:waste_management/screens/resident_screens/resident_profile_screen.dart';
import 'package:waste_management/screens/resident_screens/resident_recent_cleanliness_report_screen.dart';
import 'package:waste_management/screens/resident_screens/resident_report_cleanliness_issue_screen.dart';
import 'package:waste_management/screens/resident_screens/resident_special_garbage_request_screen.dart';
import 'package:waste_management/service/auth_service.dart';
import 'package:waste_management/service/notification_service.dart';
import 'package:waste_management/utils/protected_route.dart';
import 'package:waste_management/utils/theme.dart';

// Define the background message handler at the top level
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter binding is initialized
  await Firebase.initializeApp(); // Initialize Firebase

  // Set up the background message handler for Firebase Messaging
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initializeNotificationChannels();

  // Request notification permissions
  await notificationService.requestNotificationPermissions();

  // Set up foreground message handling
  notificationService.setupNotificationHandlers(
    onMessageHandler: (RemoteMessage message) {
      print("Received foreground message: ${message.messageId}");

      // Show an in-app notification or update UI when a message arrives
      if (message.notification != null) {
        print("Message notification: ${message.notification?.title}");
        print("Message notification: ${message.notification?.body}");
        // You could display an in-app notification here
      }
    },
  );

  // Ensure admin account exists
  final authService = AuthService();
  await authService.setupAdminAccount();

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
      initialRoute: '/loading_screen',
      routes: {
        // Public routes - accessible without authentication
        '/loading_screen': (context) => const LoadingScreen(),
        '/sign_in_page': (context) => const SignInPage(),
        '/sign_up_page': (context) => const SignupScreen(),
        '/forget_passowrd': (context) => const ForgotPasswordScreen(),

        // Resident-only routes
        '/resident_home':
            (context) => ProtectedRoute(
              allowedRoles: ['resident'],
              child: const ResidentHome(),
            ),
        '/resident_detail':
            (context) => ProtectedRoute(
              allowedRoles: ['resident'],
              child: const DetailPage(),
            ),
        '/resident_detailtwo':
            (context) => ProtectedRoute(
              allowedRoles: ['resident'],
              child: const DetailTwoScreen(),
            ),
        '/resident_profile':
            (context) => ProtectedRoute(
              allowedRoles: ['resident'],
              child: const ResidentProfileScreen(),
            ),
        '/resident_notifications':
            (context) => ProtectedRoute(
              allowedRoles: ['resident'],
              child: const ResidentNotificationScreen(),
            ),
        '/report_cleanliness_issue':
            (context) => ProtectedRoute(
              allowedRoles: ['resident'],
              child: ReportCleanlinessIssuePage(),
            ),
        '/recent_report_and_request':
            (context) => ProtectedRoute(
              allowedRoles: ['resident'],
              child: RecentReportsRequestsPage(),
            ),
        '/active_route_screen':
            (context) => ProtectedRoute(
              allowedRoles: ['resident'],
              child: ResidentActiveRoutesScreen(),
            ),
        '/resident_location_picker_screen':
            (context) => ProtectedRoute(
              allowedRoles: ['resident'],
              child: ResidentLocationPickerScreen(),
            ),
        '/resident_special_garbage_request_screen':
            (context) => ProtectedRoute(
              allowedRoles: ['resident'],
              child: SpecialGarbageRequestsScreen(),
            ),

        // Driver-only routes
        '/driver_home':
            (context) => ProtectedRoute(
              allowedRoles: ['driver'],
              child: const DriverHome(),
            ),
        '/driver_profile':
            (context) => ProtectedRoute(
              allowedRoles: ['driver'],
              child: DriverProfileScreen(),
            ),
        '/driver_notifications':
            (context) => ProtectedRoute(
              allowedRoles: ['driver'],
              child: const DriverNotificationScreen(),
            ),
        '/driver_route_list':
            (context) => ProtectedRoute(
              allowedRoles: ['driver'],
              child: DriverRouteListScreen(),
            ),
        '/driver_cleanliness_issue_list':
            (context) => ProtectedRoute(
              allowedRoles: ['driver'],
              child: DriverCleanlinessIssueListScreen(),
            ),
        '/breakdown_screen':
            (context) => ProtectedRoute(
              allowedRoles: ['driver'],
              child: BreakdownReportScreen(),
            ),
        '/driver_special_garbage_screen':
            (context) => ProtectedRoute(
              allowedRoles: ['driver'],
              child: DriverSpecialGarbageScreen(),
            ),
        '/driver_assignment_screen':
            (context) => ProtectedRoute(
              allowedRoles: ['driver'],
              child: DriverAssignmentScreen(),
            ),

        // City Management/Admin-only routes
        '/admin_home':
            (context) => ProtectedRoute(
              allowedRoles: ['cityManagement'],
              child: const AdminHome(),
            ),
        '/admin_create_route':
            (context) => ProtectedRoute(
              allowedRoles: ['cityManagement'],
              child: AdminRouteCreationScreen(),
            ),
        '/admin_route_list':
            (context) => ProtectedRoute(
              allowedRoles: ['cityManagement'],
              child: AdminRouteListScreen(),
            ),
        '/admin_cleanliness_issue_list':
            (context) => ProtectedRoute(
              allowedRoles: ['cityManagement'],
              child: AdminCleanlinessIssueListScreen(),
            ),
        '/admin_breakdown':
            (context) => ProtectedRoute(
              allowedRoles: ['cityManagement'],
              child: AdminBreakdownListScreen(),
            ),
        '/admin_special_garbage_requests':
            (context) => ProtectedRoute(
              allowedRoles: ['cityManagement'],
              child: AdminSpecialGarbageIssuesScreen(),
            ),
        '/admin_history':
            (context) => ProtectedRoute(
              allowedRoles: ['cityManagement'],
              child: AdminAssignedRequestsHistoryScreen(),
            ),
        '/admin_active_drivers_screen':
            (context) => ProtectedRoute(
              allowedRoles: ['cityManagement'],
              child: AdminActiveDriversScreen(),
            ),
        '/admin_notifications':
            (context) => ProtectedRoute(
              allowedRoles: ['cityManagement'],
              child: const AdminNotificationScreen(),
            ),
      },
    );
  }
}
