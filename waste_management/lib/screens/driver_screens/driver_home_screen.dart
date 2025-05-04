import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:waste_management/widgets/driver_navbar.dart';
import 'package:intl/intl.dart';

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

  // New variables for route status
  String? _currentRouteId;
  String? _currentRouteName;
  String? _currentRouteStatus;
  String? _vehicleNumber;
  int _completedStops = 0;
  int _totalStops = 0;
  Timestamp? _startTime;

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
    _loadAllData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when navigating back to this screen
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);

    try {
      // Run fetches in parallel for better performance
      await Future.wait([_fetchDriverProfileData(), _fetchDriverRouteStatus()]);
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      // Ensure loading is set to false even if there's an error
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onRefresh() async {
    print('Manually refreshing data...');
    await _loadAllData();
    return Future.value();
  }

  Future<void> _fetchDriverProfileData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

        if (doc.exists && mounted) {
          setState(() {
            _profilePhotoUrl = doc.data()?['profileImage'];
            _driverName = doc.data()?['name'];
          });
          print('Profile fetched: $_driverName');
        }
      }
    } catch (e) {
      print('Error fetching profile data: $e');
    }
  }

  Future<void> _fetchDriverRouteStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final activeRouteQuery =
          await FirebaseFirestore.instance
              .collection('active_routes')
              .where('driverId', isEqualTo: user.uid)
              .where('status', whereIn: ['active', 'in_progress', 'paused'])
              .limit(1)
              .get();

      if (activeRouteQuery.docs.isEmpty) {
        if (mounted && _currentRouteId != null) {
          setState(() {
            _currentRouteId = null;
            _currentRouteName = null;
            _currentRouteStatus = null;
            _vehicleNumber = null;
            _completedStops = 0;
            _totalStops = 0;
            _startTime = null;
          });
        }
        return;
      }

      // We have an active route - update quickly
      final routeData = activeRouteQuery.docs.first.data();
      final String? routeId = routeData['routeId'] as String?;
      if (routeId == null) return;

      // Get only the essential data we need
      final routeDoc =
          await FirebaseFirestore.instance
              .collection('routes')
              .doc(routeId)
              .get();

      if (!routeDoc.exists) return;
      final routeData2 = routeDoc.data();
      if (routeData2 == null) return;

      // Get stops count
      final completedStopsQuery =
          await FirebaseFirestore.instance
              .collection('routes')
              .doc(routeId)
              .collection('collection_points')
              .where('completed', isEqualTo: true)
              .get();

      final stopsQuery =
          await FirebaseFirestore.instance
              .collection('routes')
              .doc(routeId)
              .collection('collection_points')
              .get();

      // Update UI
      if (mounted) {
        setState(() {
          _currentRouteId = routeId;
          _currentRouteName = routeData2['name'] as String? ?? 'Current Route';
          _currentRouteStatus = routeData['status'] as String? ?? 'active';
          _totalStops = stopsQuery.docs.length;
          _completedStops = completedStopsQuery.docs.length;
          _startTime = routeData['startTime'] as Timestamp?;
        });
      }
    } catch (e) {
      // Silent error handling to avoid UI disruption
    }
  }

  void _onTabTapped(int index) {
    // Set state immediately without any delays
    setState(() {
      _currentIndex = index;
    });

    // For home tab, optimize refresh by only updating necessary parts
    if (index == 0 && _currentIndex == 0) {
      // Quick refresh without state changes that might cause UI rebuilds
      _fetchDriverRouteStatus();
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
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: const Color(0xFF59A867),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Green curved background extension
              Container(
                width: double.infinity,
                height: 20,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
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

              // Status Card - Modern design with real data
              Container(
                margin: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      spreadRadius: 1,
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child:
                    _isLoading
                        ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: CircularProgressIndicator(
                              color: Color(0xFF59A867),
                            ),
                          ),
                        )
                        : ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Card header with route name and status
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _currentRouteId != null
                                          ? const Color(
                                            0xFF59A867,
                                          ).withOpacity(0.1)
                                          : Colors.grey[100],
                                  border: Border(
                                    left: BorderSide(
                                      color:
                                          _currentRouteId != null
                                              ? const Color(0xFF59A867)
                                              : Colors.grey[400]!,
                                      width: 4,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _currentRouteId != null
                                          ? Icons.route
                                          : Icons.not_listed_location,
                                      color:
                                          _currentRouteId != null
                                              ? const Color(0xFF59A867)
                                              : Colors.grey[600],
                                      size: 26,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _currentRouteId != null
                                                ? _currentRouteName ??
                                                    'Active Route'
                                                : 'No Active Route',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey[800],
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Container(
                                                height: 8,
                                                width: 8,
                                                decoration: BoxDecoration(
                                                  color:
                                                      _currentRouteId != null
                                                          ? const Color(
                                                            0xFF59A867,
                                                          )
                                                          : Colors.grey[400],
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                _currentRouteId != null
                                                    ? _currentRouteStatus
                                                            ?.toUpperCase() ??
                                                        'ACTIVE'
                                                    : 'INACTIVE',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color:
                                                      _currentRouteId != null
                                                          ? const Color(
                                                            0xFF59A867,
                                                          )
                                                          : Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Card content with vehicle info and progress
                              if (_currentRouteId != null)
                                Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Vehicle info
                                      if (_vehicleNumber != null)
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.local_shipping_outlined,
                                              color: Colors.grey[700],
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Vehicle: $_vehicleNumber',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[800],
                                              ),
                                            ),
                                          ],
                                        ),

                                      if (_vehicleNumber != null)
                                        const SizedBox(height: 12),

                                      // Time info
                                      if (_startTime != null)
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.access_time,
                                              color: Colors.grey[700],
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Started: ${DateFormat('hh:mm a').format(_startTime!.toDate())}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[800],
                                              ),
                                            ),
                                          ],
                                        ),

                                      const SizedBox(height: 16),

                                      // Progress
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      'Collection Progress',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: Colors.grey[700],
                                                      ),
                                                    ),
                                                    Text(
                                                      '$_completedStops/$_totalStops stops',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: const Color(
                                                          0xFF59A867,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  child: LinearProgressIndicator(
                                                    value:
                                                        _totalStops > 0
                                                            ? _completedStops /
                                                                _totalStops
                                                            : 0.0,
                                                    backgroundColor:
                                                        Colors.grey[200],
                                                    valueColor:
                                                        const AlwaysStoppedAnimation<
                                                          Color
                                                        >(Color(0xFF59A867)),
                                                    minHeight: 8,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                              // Action button
                              Padding(
                                padding: EdgeInsets.only(
                                  left: 20,
                                  right: 20,
                                  bottom: 20,
                                  top: _currentRouteId == null ? 20 : 0,
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.pushNamed(
                                        context,
                                        _currentRouteId != null
                                            ? '/driver_route_details'
                                            : '/driver_route_list',
                                        arguments: _currentRouteId,
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF59A867),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: Text(
                                      _currentRouteId != null
                                          ? 'View Route Details'
                                          : 'Select a Route',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
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
                  childAspectRatio: 0.95,
                  children: [
                    _ActionCard(
                      icon: Icons.map,
                      title: 'Select Route',
                      description: 'Select your route for the day',
                      onTap:
                          () => Navigator.pushNamed(
                            context,
                            '/driver_route_list',
                          ),
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
                          () =>
                              Navigator.pushNamed(context, '/breakdown_screen'),
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
