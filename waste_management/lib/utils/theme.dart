import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      // Base theme color
      scaffoldBackgroundColor: const Color(0xFFF8F8F8),
      primaryColor: const Color(0xFF4CAF50), // Green color from your nav bar
      
      // AppBar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF8F8F8),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      
      // Bottom Navigation Bar theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: Color(0xFF4CAF50),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}