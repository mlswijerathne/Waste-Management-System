import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:waste_management/widgets/driver_navbar.dart';

class DriverHome extends StatefulWidget {
  const DriverHome({super.key});

  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome> {
  int _currentIndex = 0;
  String? _profilePhotoUrl;
  String? _driverName;
  bool _isLoading = true;

  String _getDayWish() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Morning';
    } else if (hour < 17) {
      return 'Afternoon';
    } else {
      return 'Evening';
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchDriverProfileData();
  }

  Future<void> _fetchDriverProfileData() async {
    try {
      setState(() => _isLoading = true);
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
        if (doc.exists) {
          setState(() {
            _profilePhotoUrl = doc.data()?['profileImage'];
            _driverName = doc.data()?['name'];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error fetching profile data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });

    // Refresh data when returning to home tab
    if (index == 0) {
      _fetchDriverProfileData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/driver_profile');
              },
              child: CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage:
                    _profilePhotoUrl != null
                        ? MemoryImage(base64Decode(_profilePhotoUrl!))
                        : null,
                child:
                    _profilePhotoUrl == null
                        ? const Icon(Icons.person, color: Color(0xFF59A867))
                        : null,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good ${_getDayWish()}',
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
                Text(
                  '${_driverName ?? 'Driver'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {
              // Handle notifications
            },
          ),
        ],
        elevation: 0,
        backgroundColor: const Color(0xFF59A867),
        automaticallyImplyLeading: false, // Remove back button
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Green curved background extension
            Container(
              width: double.infinity,
              height: 20,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF59A867),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
            ),

            // Status Card - Could display driver status, current route, etc.
            Container(
              margin: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              height: 110, // Slightly reduced height
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF59A867),
                        ),
                      )
                      : Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF59A867).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Icon(
                                Icons.directions_bus,
                                color: Color(0xFF59A867),
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize:
                                    MainAxisSize.min, // Prevent overflow
                                children: [
                                  const Text(
                                    'Current Status',
                                    style: TextStyle(
                                      fontSize:
                                          15, // Slightly reduced font size
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF59A867),
                                    ),
                                  ),
                                  const SizedBox(height: 4), // Reduced spacing
                                  Text(
                                    'No active route selected',
                                    style: TextStyle(
                                      fontSize: 13, // Reduced font size
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 6), // Reduced spacing
                                  SizedBox(
                                    height: 28, // Fixed height for button
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.pushNamed(
                                          context,
                                          '/driver_route_list',
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF59A867,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 0,
                                        ), // Reduced padding
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Start Route',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ), // Reduced font size
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
            ),

            // Quick Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio:
                    0.95,
                children: [
                  _ActionCard(
                    icon: Icons.map,
                    title: 'Select Route',
                    description: 'Select your route for the day',
                    onTap:
                        () =>
                            Navigator.pushNamed(context, '/driver_route_list'),
                    color: const Color(0xFF59A867),
                  ),
                  _ActionCard(
                    icon: Icons.info,
                    title: 'Cleanliness Issues',
                    description: 'Cleanliness issues in your area',
                    onTap:
                        () => Navigator.pushNamed(
                          context,
                          '/driver_cleanliness_issue_list',
                        ),
                    color: Colors.orange[700]!,
                  ),
                  _ActionCard(
                    icon: Icons.folder_special,
                    title: 'Special Requests',
                    description: 'View special requests from citizens',
                    onTap:
                        () => Navigator.pushNamed(
                          context,
                          '/driver_special_garbage_screen',
                        ),
                    color: Colors.blue[600]!,
                  ),
                  _ActionCard(
                    icon: Icons.build,
                    title: 'Report Breakdown',
                    description: 'Report vehicle breakdowns',
                    onTap:
                        () => Navigator.pushNamed(context, '/breakdown_screen'),
                    color: Colors.purple[700]!,
                  ),
                ],
              ),
            ),

            // Tips Section
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Text(
                'Daily Tips',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ),

            // Scrollable tips cards
            SizedBox(
              height: 180,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _TipCard(
                    icon: Icons.schedule,
                    title: 'Efficient Routing',
                    description:
                        'Plan your collection route to minimize fuel usage and save time.',
                    color: const Color(0xFF59A867),
                  ),
                  _TipCard(
                    icon: Icons.local_gas_station,
                    title: 'Fuel Conservation',
                    description:
                        'Avoid idling the vehicle for long periods to save fuel and reduce emissions.',
                    color: Colors.blue[600]!,
                  ),
                  _TipCard(
                    icon: Icons.health_and_safety,
                    title: 'Safety First',
                    description:
                        'Always wear proper safety equipment when handling waste materials.',
                    color: Colors.amber[800]!,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: DriversNavbar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final Color color;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    required this.color,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start, // Align content to start
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 12), // Increased spacing
            Text(
              title,
              style: TextStyle(
                fontSize: 16, // Slightly increased font size
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(
              height: 6,
            ), // More space between title and description
            Expanded(
              // Using Expanded instead of Flexible for better space utilization
              child: Text(
                description,
                style: TextStyle(
                  fontSize: 13, // Increased font size for better readability
                  color: Colors.grey[600],
                ),
                // Removed maxLines and overflow to allow text to use available space
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _TipCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(left: 4, right: 8, bottom: 8, top: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Added to prevent overflow
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 6), // Reduced spacing
                Flexible(
                  // Added Flexible to prevent overflow
                  child: Text(
                    description,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
