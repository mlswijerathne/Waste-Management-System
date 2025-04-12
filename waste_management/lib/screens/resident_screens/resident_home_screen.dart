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
  int _currentIndex = 0;
  final AuthService _authService = AuthService();
  UserModel? _currentUser;
  bool _isLoading = true;
  String _errorMessage = '';

  // Default location (Sri Lanka center)
  LatLng _userLocation = const LatLng(7.8731, 80.7718);
  Set<Marker> _markers = {};
  GoogleMapController? _mapController;

  final List<Widget> _pages = [
    const Center(child: Text('Home Page')),
    const Center(child: Text('Report Page')),
    const Center(child: Text('Notification Page')),
    const Center(child: Text('Profile Page')),
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserLocation();
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
    _fetchUserLocation();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // This will get called when you navigate back from another screen
    // Using a flag to prevent multiple fetches
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchUserLocation();
      }
    });
  }

  Future<void> _fetchUserLocation() async {
    if (!mounted) return;
    
    try {
      setState(() => _isLoading = true);
      
      // Get fresh user data from the database
      _currentUser = await _authService.getCurrentUser();

      print('Current user data: ${_currentUser?.toMap()}');
      print('Latitude: ${_currentUser?.latitude}, Longitude: ${_currentUser?.longitude}');

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
      _fetchUserLocation();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Waste Management System'),
        backgroundColor: const Color(0xFF59A867),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Home Page
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Map Widget
                Container(
                  margin: const EdgeInsets.all(16.0),
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF59A867)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
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
                              child: CircularProgressIndicator(),
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
                                onTap: _fetchUserLocation,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
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
                                    color: Color(0xFF59A867),
                                    size: 24,
                                  ),
                                ),
                              ),
                              // Edit location button
                              InkWell(
                                onTap: () {
                                  Navigator.pushNamed(context, '/resident_location_picker_screen')
                                      .then((_) {
                                        // Force refresh when returning from location picker
                                        _fetchUserLocation();
                                      });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
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
                                    color: Color(0xFF59A867),
                                    size: 24,
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
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
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
                        title: 'Active Routes',
                        description: 'Track waste collection in real-time',
                        onTap: () => Navigator.pushNamed(context, '/active_route_screen'),
                        color: const Color(0xFF59A867),
                      ),
                      _ActionCard(
                        icon: Icons.report_problem,
                        title: 'Report Issue',
                        description: 'Report cleanliness issues in your area',
                        onTap: () => Navigator.pushNamed(context, '/report_cleanliness_issue'),
                        color: Colors.orange,
                      ),
                      _ActionCard(
                        icon: Icons.history,
                        title: 'Recent Reports',
                        description: 'Check your recent report status',
                        onTap: () => Navigator.pushNamed(context, '/recent_report_and_request'),
                        color: Colors.blue,
                      ),
                      _ActionCard(
                        icon: Icons.info,
                        title: 'Request Special Garbage',
                        description: 'Learn about waste types and disposal',
                        onTap: () => Navigator.pushNamed(context, '/resident_special_garbage_request_screen'),
                        color: Colors.purple,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Tips Section
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Waste Management Tips',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF59A867).withOpacity(0.5)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF59A867).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.eco, color: Color(0xFF59A867), size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Tip of the Day',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF59A867),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Reduce plastic waste by carrying a reusable water bottle instead of buying single-use plastic bottles.',
                                style: TextStyle(color: Colors.grey[700], fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
          // Other tabs
          const Center(child: Text('Report Page')),
          const Center(child: Text('Notification Page')),
          const Center(child: Text('Profile Page')),
        ],
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}