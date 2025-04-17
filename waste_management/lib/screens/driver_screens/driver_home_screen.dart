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

  @override
  void initState() {
    super.initState();
    _fetchDriverProfileData();
  }

  Future<void> _fetchDriverProfileData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          setState(() {
            _profilePhotoUrl = doc.data()?['profileImage']; // Assuming 'profileImage' is the field name
            _driverName = doc.data()?['name']; // Added to fetch driver name
          });
        }
      }
    } catch (e) {
      print('Error fetching profile data: $e');
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _navigateWithoutBackOption(BuildContext context, String routeName) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => getRouteWidget(routeName)),
      (route) => false, // This prevents going back
    );
  }

  Widget getRouteWidget(String routeName) {
    // This is a placeholder function - you would need to implement
    // logic to return the correct widget based on the route name
    switch (routeName) {
      case '/driver_route_list':
        // Return your route list widget
        return Container(); // Replace with actual widget
      case '/driver_cleanliness_issue_list':
        // Return your cleanliness issues widget
        return Container(); // Replace with actual widget
      // Add other cases as needed
      default:
        return const DriverHome();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Interface'),
        backgroundColor: const Color(0xFF59A867),
        automaticallyImplyLeading: false, // Remove back button
        actions: [
          GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, '/driver_profile');
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundImage: _profilePhotoUrl != null
                        ? MemoryImage(base64Decode(_profilePhotoUrl!))
                        : const AssetImage('assets/default_profile.png') as ImageProvider,
                    radius: 20,
                    child: _profilePhotoUrl == null
                        ? const Icon(Icons.person, size: 20) // Placeholder icon
                        : null,
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Home Page with Quick Actions
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Actions Title
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Action Cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _ActionCard(
                        icon: Icons.map,
                        title: 'Select Route',
                        description: 'Select your route for the day',
                        onTap: () {
                          Navigator.pushNamed(context, '/driver_route_list');
                        },
                        color: const Color(0xFF59A867),
                      ),
                      _ActionCard(
                        icon: Icons.info,
                        title: 'Cleanliness Issues',
                        description: 'Cleanliness issues in your area',
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/driver_cleanliness_issue_list',
                          );
                        },
                        color: Colors.orange,
                      ),
                      _ActionCard(
                        icon: Icons.folder_special,
                        title: 'Special Requests',
                        description: 'View special requests from citizens',
                        onTap: () {
                          Navigator.pushNamed(context, '/driver_special_garbage_screen');
                        },
                        color: Colors.blue,
                      ),
                      _ActionCard(
                        icon: Icons.build,
                        title: 'Report Breakdown',
                        description: 'Report vehicle breakdowns',
                        onTap: () {
                          Navigator.pushNamed(context, '/breakdown_screen');
                        },
                        color: Colors.purple,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Center(child: Text('Tasks Page')), // This should not be visible anymore
          const Center(child: Text('Notification Page')), // This should not be visible anymore
          const Center(child: Text('Profile Page')), // This should not be visible anymore
        ],
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
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: color),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}