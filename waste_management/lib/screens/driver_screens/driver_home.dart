import 'package:flutter/material.dart';
import 'package:waste_management/widgets/driver_navbar.dart';


class DriverHome extends StatefulWidget {
  const DriverHome({super.key});

  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome> {
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
        title: const Text('Driver Interface'),
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