import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:waste_management/widgets/resident_navbar.dart';
import 'package:waste_management/service/auth_service.dart';
import 'package:waste_management/models/userModel.dart';

class ResidentHome extends StatefulWidget {
  const ResidentHome({super.key});

  @override
  State<ResidentHome> createState() => _ResidentHomeState();
}

class _ResidentHomeState extends State<ResidentHome> {
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
  int _currentIndex = 0;
  final AuthService _authService = AuthService();
  UserModel? _currentUser;
  bool _isLoading = true;
  String _errorMessage = '';
  String? base64Image;

  // Default location (Sri Lanka center)
  LatLng _userLocation = const LatLng(7.8731, 80.7718);
  Set<Marker> _markers = {};
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _fetchUserDataAndLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ResidentHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh location when widget updates
    _fetchUserDataAndLocation();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // This will get called when you navigate back from another screen
    // Using a flag to prevent multiple fetches
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchUserDataAndLocation();
      }
    });
  }

  Future<void> _fetchUserDataAndLocation() async {
    if (!mounted) return;
    
    try {
      setState(() => _isLoading = true);
      
      // Get fresh user data from the database
      _currentUser = await _authService.getCurrentUser();

      print('Current user data: ${_currentUser?.toMap()}');
      print('Latitude: ${_currentUser?.latitude}, Longitude: ${_currentUser?.longitude}');

      // Fetch profile image if user exists
      if (_currentUser != null && _currentUser!.uid.isNotEmpty) {
        await _getProfileImage(_currentUser!.uid);
      }

      if (_currentUser != null &&
          _currentUser!.latitude != null &&
          _currentUser!.longitude != null) {
        // If we have location in the database, use it
        setState(() {
          _userLocation = LatLng(
            _currentUser!.latitude!,
            _currentUser!.longitude!,
          );

          _markers = {
            Marker(
              markerId: const MarkerId('userLocation'),
              position: _userLocation,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              infoWindow: InfoWindow(
                title: 'Your Location',
                snippet: _currentUser!.address ?? 'Home',
              ),
            ),
          };

          _isLoading = false;
          _errorMessage = '';
        });

        // Move camera to the user location if map is already initialized
        _moveCameraToUserLocation();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No location found. Please set your location.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error loading location: $e';
        });
      }
      print('Error fetching location: $e');
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    
    // Refresh location when returning to home tab
    if (index == 0) {
      _fetchUserDataAndLocation();
    }
  }

  void _moveCameraToUserLocation() {
    if (_mapController != null && 
        _currentUser?.latitude != null && 
        _currentUser?.longitude != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(_currentUser!.latitude!, _currentUser!.longitude!),
            zoom: 15,
          ),
        ),
      );
      print("Camera moved to user location");
    } else {
      print("MapController not ready or location is null");
    }
  }

  Future<void> _getProfileImage(String uid) async {
  try {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists && doc.data()!.containsKey('profileImage')) {
      if (mounted) {
        setState(() {
          base64Image = doc.data()!['profileImage'] as String;
        });
        print('Profile image loaded successfully: ${base64Image?.substring(0, 20)}...');
      }
    } else {
      print('No profile image found for user: $uid');
    }
  } catch (e) {
    print('Error getting profile image: $e');
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white,
              backgroundImage: base64Image != null
                ? MemoryImage(base64Decode(base64Image!))
                : null,
              child: base64Image == null
                ? const Icon(
                    Icons.person,
                    color: Color(0xFF3DAE58),
                  )
                : null,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good ${_getDayWish()}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  '${_currentUser?.name ?? 'Resident'}',
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
        backgroundColor: const Color(0xFF3DAE58),
        automaticallyImplyLeading: false, // Remove back button
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Container(
              width: double.infinity,
              height: 20,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
              color: const Color(0xFF3DAE58),
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

            // Map Widget
            Container(
              margin: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _userLocation,
                        zoom: 15,
                      ),
                      markers: _markers,
                      myLocationEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      compassEnabled: false,
                      onMapCreated: (controller) {
                        setState(() {
                          _mapController = controller;
                          // Move camera once map is created
                          _moveCameraToUserLocation();
                        });
                      },
                    ),
                    if (_isLoading)
                      Container(
                        color: Colors.white.withOpacity(0.7),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF3DAE58),
                          ),
                        ),
                      ),
                    if (_errorMessage.isNotEmpty)
                      Container(
                        color: Colors.white.withOpacity(0.7),
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Row(
                        children: [
                          // Refresh location button
                          InkWell(
                            onTap: _fetchUserDataAndLocation,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 5,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.refresh,
                                color: Color(0xFF3DAE58),
                                size: 20,
                              ),
                            ),
                          ),
                          // Edit location button
                          InkWell(
                            onTap: () {
                              Navigator.pushNamed(context, '/resident_location_picker_screen')
                                  .then((_) {
                                    // Force refresh when returning from location picker
                                    _fetchUserDataAndLocation();
                                  });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 5,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.edit_location,
                                color: Color(0xFF3DAE58),
                                size: 20,
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
                  TextButton(
                    onPressed: () {
                      // Navigate to see all actions
                    },
                    child: const Text(
                      'See All',
                      style: TextStyle(
                        color: Color(0xFF3DAE58),
                        fontWeight: FontWeight.w600,
                      ),
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
                childAspectRatio: 1.1,
                children: [
                  _ActionCard(
                    icon: Icons.map,
                    title: 'Active Routes',
                    description: 'Track waste collection in real-time',
                    onTap: () => Navigator.pushNamed(context, '/active_route_screen'),
                    color: const Color(0xFF3DAE58),
                  ),
                  _ActionCard(
                    icon: Icons.report_problem_outlined,
                    title: 'Report Issue',
                    description: 'Report cleanliness issues in your area',
                    onTap: () => Navigator.pushNamed(context, '/report_cleanliness_issue'),
                    color: Colors.orange[700]!,
                  ),
                  _ActionCard(
                    icon: Icons.history,
                    title: 'Recent Reports',
                    description: 'Check your recent report status',
                    onTap: () => Navigator.pushNamed(context, '/recent_report_and_request'),
                    color: Colors.blue[600]!,
                  ),
                  _ActionCard(
                    icon: Icons.recycling_rounded,
                    title: 'Special Pickup',
                    description: 'Request pickup for special waste',
                    onTap: () => Navigator.pushNamed(context, '/resident_special_garbage_request_screen'),
                    color: Colors.purple[700]!,
                  ),
                ],
              ),
            ),

            // Tips Section
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Text(
                'Waste Management Tips',
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
                    icon: Icons.eco,
                    title: 'Reduce Plastic',
                    description: 'Carry a reusable water bottle instead of buying single-use plastic bottles.',
                    color: const Color(0xFF3DAE58),
                  ),
                  _TipCard(
                    icon: Icons.recycling,
                    title: 'Segregate Waste',
                    description: 'Separate recyclables from general waste to improve recycling efficiency.',
                    color: Colors.blue[600]!,
                  ),
                  _TipCard(
                    icon: Icons.compost,
                    title: 'Compost Organics',
                    description: 'Turn kitchen scraps into nutrient-rich soil for your garden.',
                    color: Colors.amber[800]!,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: ResidentNavbar(
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
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 24,
                color: color,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}