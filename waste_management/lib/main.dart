import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:waste_management/screens/auth/forget_password_screen.dart';
import 'package:waste_management/screens/auth/loading_screen.dart';
import 'package:waste_management/screens/auth/sign_in_screen.dart';
import 'package:waste_management/screens/auth/sign_up_screen.dart';
import 'package:waste_management/screens/city_management_screens/admin_home_screen.dart';
import 'package:waste_management/screens/city_management_screens/admin_route_create_screen.dart';
import 'package:waste_management/screens/city_management_screens/admin_route_list_screen.dart';
import 'package:waste_management/screens/driver_screens/breakdown_screen.dart';
import 'package:waste_management/screens/driver_screens/driver_home_screen.dart';
import 'package:waste_management/screens/driver_screens/driver_profile_screen.dart';
import 'package:waste_management/screens/driver_screens/driver_route_list_screen.dart';
import 'package:waste_management/screens/resident_screens/active_route_screen.dart';
import 'package:waste_management/screens/resident_screens/report_cleanliness_issue_screen.dart';
import 'package:waste_management/screens/resident_screens/request_special_garbage_location_screen.dart';
import 'package:waste_management/screens/resident_screens/recent_cleanliness_report_screen.dart';
import 'package:waste_management/screens/resident_screens/resident-detailtwo_screen.dart';
import 'package:waste_management/screens/resident_screens/resident_detail_screen.dart';
import 'package:waste_management/screens/resident_screens/resident_home_screen.dart';
import 'package:waste_management/screens/resident_screens/resident_profile_screen.dart';
import 'package:waste_management/screens/resident_screens/route_details_screen.dart';
import './utils/theme.dart';

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
      initialRoute: '/loading_screen', // Set initial route to HomeScreen
      routes: {
        '/breakdown_screen' :(context) => BreakdownReportScreen(),//Route for BreakdownReportScreen
        '/driver_home' : (context) => const DriverHome(), // Route for DriverHomeScreen
        '/forget_passowrd' : (context) =>const ForgotPasswordScreen(), //Route for ForgotPasswordScreen
        '/sign_in_page' : (context) => const SignInPage(), //Route for SignInPage
        '/sign_up_page' : (context) => const SignupScreen(),//Route for SignupScreen
        '/loading_screen' : (context) =>const LoadingScreen(),//Route for LoadingScreen
        '/admin_home' : (context) => const AdminHome(),//Route for AdminHome
        '/resident_home': (context) => const ResidentHome(), // Route for ResidentHomeScreen
        '/resident_detail':(context)=> const DetailPage(),//Route for DetailPage
        '/resident_detailtwo' : (context)=> const DetailTwoScreen(),//Route for DetailTwoScreen
        '/resident_profile' : (context) =>const ResidentProfileScreen(), //Route for Resident Profile
        '/driver_profile' : (context) => DriverProfileScreen(), //Route Driver Profile
        '/report_cleanliness_issue' : (context) => ReportCleanlinessIssuePage(), //Route for ReportCleanlinessIssuePage
        '/request_special_garbage_location' : (context) => RequestSpecialGarbageLocationScreen(),//Route for RequestSpecialGarbageLocationScreen
        '/recent_report_and_request' : (context) => RecentReportsRequestsPage(),//Route for RecentReportsRequestsPage
        '/admin_create_route' : (context) => AdminRouteCreationScreen(),//Route for AdminCreateRouteScreen
        '/admin_route_list' : (context) => AdminRouteListScreen(),//Route for AdminRouteListScreen
        '/driver_route_list' : (context) => DriverRouteListScreen(),//Route for DriverRouteSelectionScreen
        '/active_route_screen' : (context) => ResidentActiveRoutesScreen(),//Route for ActiveRouteScreen
        
        
    

        
       
      },
    );
  }
}
