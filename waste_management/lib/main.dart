import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:waste_management/screens/auth/forget_password_screen.dart';
import 'package:waste_management/screens/auth/loading_screen.dart';
import 'package:waste_management/screens/auth/sign_in_screen.dart';
import 'package:waste_management/screens/auth/sign_up_screen.dart';
import 'package:waste_management/screens/city_management_screens/admin_home_screen.dart';
import 'package:waste_management/screens/driver_screens/breakdown_screen.dart';
import 'package:waste_management/screens/driver_screens/driver_home.dart';
import 'package:waste_management/screens/resident_screens/reprt_cleaanless_issue.dart';
import 'package:waste_management/screens/resident_screens/request_special_garbage_location_screen.dart';
import 'package:waste_management/screens/resident_screens/resent_repeort_and_request.dart';
import 'package:waste_management/screens/resident_screens/resident-detailtwo.dart';
import 'package:waste_management/screens/resident_screens/resident_detail.dart';
import 'package:waste_management/screens/resident_screens/resident_home.dart';
import 'package:waste_management/screens/resident_screens/resident_profile.dart';
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
      initialRoute: '/resident_profile', // Set initial route to HomeScreen
      routes: {
        '/breakdown_screen' :(context) => BreakdownReportScreen(),//Route for BreakdownReportScreen
        '/driver_home' : (context) => const DriverHome(), // Route for DriverHomeScreen
        '/forget_passowrd' : (context) => ForgotPasswordScreen(), //Route for ForgotPasswordScreen
        '/sign_in_page' : (context) => const SignInPage(), //Route for SignInPage
        '/sign_up_page' : (context) => const SignupScreen(),//signin page screen
        '/loading_screen' : (context) => LoadingScreen(),//Route for LoadingScreen
        '/admin_home' : (context) => const AdminHome(),//Route for AdminHome
        '/resident_home': (context) => const ResidentHome(), // Route for ResidentHomeScreen
        '/resident_detail':(context)=>  DetailPage(),//Route for DetailPage
        '/resident_detailtwo' : (context)=> DetailTwoScreen(),//Route for DetailTwoScreen
        '/resident_profile' : (context) => ProfileScreen(), //route resident profile
        '/cleanless_issue' : (context) => ReportCleanlinessIssuePage(),//Route for ReportCleanlinessIssuePage
        '/request_garbage' : (context) => RequestSpecialGarbageLocationScreen(),//route for RequestSpecialGarbageLocationScreen
        '/recent_report' : (context) => RecentReportsScreen(),//Route for RecentReportsScreen
        

        
       
      },
    );
  }
}