import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:waste_management/screens/resident_screens/resident_home.dart';
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
      initialRoute: '/resident_home', // Set initial route to HomeScreen
      routes: {
        '/resident_home': (context) => const ResidentHome(), // Route for HomeScreen
        // '/resident_profile': (context) => const ResidentProfileScreen(), // Route for ProfileScreen
      },
    );
  }
}