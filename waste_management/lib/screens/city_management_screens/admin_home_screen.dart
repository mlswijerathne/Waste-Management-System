import 'package:flutter/material.dart';
import 'package:waste_management/widgets/driver_navbar.dart';


class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const Center(child: Text('Home Page')),
    const Center(child: Text('Tasks Page')),
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
        title: const Text('Admin Interface'),
        backgroundColor: const Color(0x00ffffff),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ), // Use IndexedStack to preserve state
      bottomNavigationBar: DriversNavbar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}