import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:waste_management/service/route_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

class AdminActiveDriversScreen extends StatefulWidget {
  const AdminActiveDriversScreen({Key? key}) : super(key: key);

  @override
  State<AdminActiveDriversScreen> createState() => _AdminActiveDriversScreenState();
}

class _AdminActiveDriversScreenState extends State<AdminActiveDriversScreen> with TickerProviderStateMixin {
  final RouteService _routeService = RouteService();
  final Completer<GoogleMapController> _controller = Completer();
  final Color primaryColor = const Color(0xFF59A867);
  bool _mapCreated = false;

  Set<Marker> _markers = {};
  Map<String, LatLng> _lastPositions = {};
  Map<String, AnimationController> _animationControllers = {};
  Map<String, Animation<LatLng>> _animations = {};
  BitmapDescriptor? _truckIcon;

  int _activeDriverCount = 0;
  List<Map<String, dynamic>> _allRoutes = [];
  Map<String, dynamic>? _selectedDriver;

  CameraPosition _initialCameraPosition = const CameraPosition(
    target: LatLng(6.9271, 79.8612), // Default coordinates for Colombo, Sri Lanka
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
    _loadTruckIcon();
    _subscribeToRoutes();
  }

  Future<void> _loadTruckIcon() async {
    _truckIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/icons/truck_icon.png',
    );
  }

  void _subscribeToRoutes() {
    _routeService.getActiveRoutesWithDriverInfo().listen((routes) {
      setState(() {
        _allRoutes = routes;
        _updateMarkers();
      });
    });
  }

  void _updateMarkers() {
    Set<Marker> markers = {};
    int count = 0;

    for (var routeData in _allRoutes) {
      final route = routeData['route'];
      final LatLng? newPos = routeData['currentPosition'];

      if (newPos == null) continue;

      final id = route.id;
      final lastPos = _lastPositions[id];

      if (lastPos != null && lastPos != newPos) {
        _animateMarker(id, lastPos, newPos);
      }

      _lastPositions[id] = newPos;

      final marker = Marker(
        markerId: MarkerId(id),
        position: newPos,
        icon: _truckIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(title: route.driverName ?? 'Unnamed', snippet: 'Truck: ${route.truckId}'),
        onTap: () => _selectDriver(routeData),
      );

      markers.add(marker);
      count++;
    }

    setState(() {
      _markers = markers;
      _activeDriverCount = count;
      
      // Update selected driver position if needed
      if (_selectedDriver != null) {
        final updatedDriverData = _allRoutes.firstWhere(
          (data) => data['route'].id == _selectedDriver!['route'].id,
          orElse: () => _selectedDriver!,
        );
        _selectedDriver = updatedDriverData;
      }
    });
  }

  void _animateMarker(String id, LatLng from, LatLng to) {
    _animationControllers[id]?.dispose();

    final controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    final animation = Tween<LatLng>(begin: from, end: to).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
    animation.addListener(() {
      setState(() {
        _lastPositions[id] = animation.value;
      });
    });

    _animationControllers[id] = controller;
    _animations[id] = animation;

    controller.forward();
  }

  void _selectDriver(Map<String, dynamic> driverData) {
    setState(() {
      _selectedDriver = driverData;
    });

    final route = driverData['route'];
    final pos = driverData['currentPosition'];

    if (pos != null && _mapCreated) {
      _controller.future.then((controller) {
        controller.animateCamera(CameraUpdate.newLatLng(pos));
      });
    }
  }

  void _contactDriver() async {
    if (_selectedDriver == null) return;
    
    final contact = _selectedDriver!['route'].driverContact;
    if (contact == null || contact.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver contact unavailable'))
      );
      return;
    }

    final Uri phoneUri = Uri.parse('tel:$contact');
    if (await url_launcher.canLaunchUrl(phoneUri)) {
      await url_launcher.launchUrl(phoneUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch phone app for: $contact')),
      );
    }
  }

  String _formatTimeOfDay(TimeOfDay? time) {
    if (time == null) return 'N/A';
    
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Active Drivers (${_activeDriverCount})'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Map section
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: _initialCameraPosition,
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                  onMapCreated: (GoogleMapController controller) {
                    if (!_controller.isCompleted) {
                      _controller.complete(controller);
                      setState(() {
                        _mapCreated = true;
                      });
                    }
                  },
                ),
                // Add a loading indicator for the map
                if (!_mapCreated)
                  const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  ),
                // Driver count display
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.directions_car, color: primaryColor, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '$_activeDriverCount active',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Driver details section
          Expanded(
            flex: 4,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, -3),
                  ),
                ],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: _selectedDriver == null
                  ? _buildNoDriverSelectedView()
                  : _buildDriverDetailsView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDriverSelectedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.touch_app,
            size: 60,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Tap a driver on the map to view details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Active drivers are displayed with truck markers',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverDetailsView() {
    final route = _selectedDriver!['route'];
    final position = _selectedDriver!['currentPosition'];
    final completionPercentage = _selectedDriver!['completionPercentage'] ?? 0.0;
    final estimatedCompletionTime = _selectedDriver!['estimatedCompletionTime'];
    final remainingTimeMinutes = _selectedDriver!['remainingTimeMinutes'] ?? 0;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Driver name and status
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  route.driverName ?? 'Unnamed Driver',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'ACTIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Progress section
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: primaryColor.withOpacity(0.3), width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ROUTE PROGRESS', 
                    style: TextStyle(
                      fontSize: 16, 
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: completionPercentage / 100,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  const SizedBox(height: 12),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${completionPercentage.toStringAsFixed(1)}% complete',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      
                      if (estimatedCompletionTime != null)
                        Row(
                          children: [
                            const Icon(Icons.access_time, 
                              color: Colors.grey, 
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'ETA: ${DateFormat('HH:mm').format(
                                estimatedCompletionTime is DateTime 
                                    ? estimatedCompletionTime 
                                    : DateTime.now()
                              )}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  
                  if (remainingTimeMinutes > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      '$remainingTimeMinutes minutes remaining',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Driver info section
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DRIVER INFORMATION', 
                    style: TextStyle(
                      fontSize: 16, 
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildInfoRow(
                    Icons.person,
                    'Name:',
                    route.driverName ?? 'Not assigned',
                  ),
                  
                  const Divider(height: 24),
                  
                  _buildInfoRow(
                    Icons.local_shipping,
                    'Truck ID:',
                    route.truckId ?? 'N/A',
                  ),
                  
                  const Divider(height: 24),
                  
                  _buildInfoRow(
                    Icons.phone,
                    'Contact:',
                    route.driverContact ?? 'N/A',
                  ),
                  
                  const SizedBox(height: 16),
                  
                  if (route.driverContact != null && route.driverContact!.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _contactDriver,
                        icon: const Icon(Icons.phone, size: 18),
                        label: const Text('CONTACT DRIVER'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Route details
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ROUTE DETAILS', 
                    style: TextStyle(
                      fontSize: 16, 
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildInfoRow(
                    Icons.route,
                    'Route:',
                    route.name ?? 'N/A',
                  ),
                  
                  const Divider(height: 24),
                  
                  _buildInfoRow(
                    Icons.delete,
                    'Waste Type:',
                    route.wasteCategory?.toUpperCase() ?? 'N/A',
                  ),
                  
                  const Divider(height: 24),
                  
                  _buildInfoRow(
                    Icons.route,
                    'Distance:',
                    '${route.distance?.toStringAsFixed(1) ?? 'N/A'} km',
                  ),
                  
                  const Divider(height: 24),
                  
                  _buildInfoRow(
                    Icons.access_time,
                    'Schedule:',
                    '${_formatTimeOfDay(route.scheduleStartTime)} - ${_formatTimeOfDay(route.scheduleEndTime)}',
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    for (var controller in _animationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}