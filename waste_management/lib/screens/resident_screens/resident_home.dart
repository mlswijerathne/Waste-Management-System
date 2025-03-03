import 'package:flutter/material.dart';
import 'package:waste_management/widgets/resident_navbar.dart';

class ResidentHome extends StatefulWidget {
  const ResidentHome({super.key});

  @override
  State<ResidentHome> createState() => _ResidentHomeState(); // Fixed to use the proper State generic type
}

class _ResidentHomeState extends State<ResidentHome> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const Center(child: Text('Home Page')),
    const Center(child: Text('Report Page')),
    const Center(child: Text('Notification Page')),
    const Center(child: Text('Profile Page')),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Waste Management System'),
        backgroundColor: const Color(0xFFFFFF),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ), // Use IndexedStack to preserve state
      bottomNavigationBar: ResidentNavbar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}