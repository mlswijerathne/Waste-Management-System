import 'package:flutter/material.dart';
import 'package:waste_management/widgets/resident_navbar.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh location data when screen is focused
    _fetchUserLocation();
  }

  // Separate function to fetch user location
  Future<void> _fetchUserLocation() async {
    try {
      setState(() => _isLoading = true);
      
      // Get current user
      _currentUser = await _authService.getCurrentUser();
      
      // Add debugging print statements
      print('Current user data: ${_currentUser?.toMap()}');
      print('Latitude: ${_currentUser?.latitude}, Longitude: ${_currentUser?.longitude}');
      
      if (_currentUser != null && 
          _currentUser!.latitude != null && 
          _currentUser!.longitude != null) {
        
        // Set user location
        _userLocation = LatLng(
          _currentUser!.latitude!,
          _currentUser!.longitude!
        );
        
        // Add marker
        _markers = {
          Marker(
            markerId: const MarkerId('userLocation'),
            position: _userLocation,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(
              title: 'Your Location',
              snippet: _currentUser!.address ?? 'Home',
            ),
          ),
        };
        
        setState(() {
          _isLoading = false;
          _errorMessage = '';
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No location found. Please set your location.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading location: $e';
      });
      print('Error fetching location: $e');
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _showWasteInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Waste Information'),
        content: const Text('Learn about different types of waste and proper disposal methods.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
          // Home Page with Quick Actions and Map Widget
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Simple Map Widget
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
                        // Map Widget
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
                            // Map is created
                          },
                        ),
                        
                        // Loading indicator
                        if (_isLoading)
                          Container(
                            color: Colors.white.withOpacity(0.7),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        
                        // Error message
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
                          
                        // Edit location button
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: InkWell(
                            onTap: () {
                              Navigator.pushNamed(context, '/resident_location_picker_screen')
                                .then((_) => _fetchUserLocation());
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
                                Icons.edit,
                                color: Color(0xFF59A867),
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

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
                        title: 'Active Routes',
                        description: 'Track waste collection in real-time',
                        onTap: () {
                          Navigator.pushNamed(context, '/active_route_screen');
                        },
                        color: const Color(0xFF59A867),
                      ),
                      _ActionCard(
                        icon: Icons.report_problem,
                        title: 'Report Issue',
                        description: 'Report cleanliness issues in your area',
                        onTap: () {
                          Navigator.pushNamed(context, '/report_cleanliness_issue');
                        },
                        color: Colors.orange,
                      ),
                      _ActionCard(
                        icon: Icons.history,
                        title: 'Recent Reports',
                        description: 'Check your recent report status',
                        onTap: () {
                          Navigator.pushNamed(context, '/recent_report_and_request');
                        },
                        color: Colors.blue,
                      ),
                      _ActionCard(
                        icon: Icons.info,
                        title: 'Waste Info',
                        description: 'Learn about waste types and disposal',
                        onTap: () {
                          _showWasteInfoDialog(context);
                        },
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

                // Tip Card
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
                          child: const Icon(
                            Icons.eco,
                            color: Color(0xFF59A867),
                            size: 28,
                          ),
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
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 14,
                                ),
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
          // Other Pages
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