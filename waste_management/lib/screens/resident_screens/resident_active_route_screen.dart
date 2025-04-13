import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:waste_management/models/routeModel.dart';
import 'package:waste_management/screens/resident_screens/resident_route_details_screen.dart';
import 'package:waste_management/service/route_service.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart' as permission;
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:flutter/animation.dart';
import 'package:intl/intl.dart';

class _LatLngTween extends Tween<LatLng> {
  _LatLngTween({required LatLng begin, required LatLng end}) : super(begin: begin, end: end);

  @override
  LatLng lerp(double t) {
    return LatLng(
      begin!.latitude + (end!.latitude - begin!.latitude) * t,
      begin!.longitude + (end!.longitude - begin!.longitude) * t,
    );
  }
}

class ResidentActiveRoutesScreen extends StatefulWidget {
  const ResidentActiveRoutesScreen({Key? key}) : super(key: key);

  @override
  State<ResidentActiveRoutesScreen> createState() => _ResidentActiveRoutesScreenState();
}

class _ResidentActiveRoutesScreenState extends State<ResidentActiveRoutesScreen> with TickerProviderStateMixin {
  final RouteService _routeService = RouteService();
  final Completer<GoogleMapController> _controller = Completer();
  final Location _location = Location();
  
  // Define primary color to match other screens
  final Color primaryColor = const Color(0xFF59A867);
  
  CameraPosition _initialCameraPosition = const CameraPosition(
    target: LatLng(6.9271, 79.8612),
    zoom: 12,
  );
  
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _mapLoaded = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _activeRoutes = [];
  Map<String, BitmapDescriptor> _markerIcons = {};
  LatLng? _currentUserLocation;
  LatLng? _lastUserLocation;
  bool _locationInitialized = false;
  
  // Animation controllers
  AnimationController? _animationController;
  Animation<LatLng>? _locationAnimation;
  
  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
    _initializeLocation();
  }
  
  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }
  
  Future<void> _initializeLocation() async {
    try {
      final status = await permission.Permission.location.request();
      if (status != permission.PermissionStatus.granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission is required to show your position')),
        );
        return;
      }
      
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled')),
          );
          return;
        }
      }
      
      final locationData = await _location.getLocation();
      setState(() {
        _currentUserLocation = LatLng(locationData.latitude!, locationData.longitude!);
        _initialCameraPosition = CameraPosition(
          target: _currentUserLocation!,
          zoom: 15,
        );
        _locationInitialized = true;
      });
      
      if (_mapLoaded) {
        final controller = await _controller.future;
        controller.animateCamera(CameraUpdate.newLatLngZoom(_currentUserLocation!, 15));
      }
      
      _location.onLocationChanged.listen((LocationData locationData) {
        setState(() {
          _lastUserLocation = _currentUserLocation;
          _currentUserLocation = LatLng(locationData.latitude!, locationData.longitude!);
          _animateLocationMarker();
        });
      });
      
    } catch (e) {
      print('Error initializing location: $e');
    }
  }
  
  void _animateLocationMarker() {
    if (_lastUserLocation == null || !_mapLoaded) {
      _updateMapWithUserLocation();
      return;
    }
    
    _animationController?.dispose();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    _locationAnimation = _LatLngTween(
      begin: _lastUserLocation!,
      end: _currentUserLocation!,
    ).animate(CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeInOut,
    ))
      ..addListener(() {
        _updateUserLocationMarker(_locationAnimation!.value);
      });
    
    _animationController!.forward();
  }
  
  void _updateUserLocationMarker(LatLng position) {
    if (mounted) {
      setState(() {
        _markers = Set.from(_markers.where((m) => m.markerId.value != 'user_location'))..add(
          Marker(
            markerId: const MarkerId('user_location'),
            position: position,
            icon: _markerIcons['user'] ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            infoWindow: const InfoWindow(title: 'Your Location'),
          ),
        );
      });
    }
  }
  
  Future<void> _loadMarkerIcons() async {
    try {
      _markerIcons['user'] = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/images/user_location.png',
      );
      
      _markerIcons['truck'] = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/images/truck_location.png',
      );
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading marker icons: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _updateMapWithUserLocation() async {
    if (!_mapLoaded) return;
    
    Set<Marker> markers = {};
    
    if (_currentUserLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: _currentUserLocation!,
          icon: _markerIcons['user'] ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      );
    }
    
    setState(() {
      _markers = markers;
    });
  }
  
  void _centerOnUserLocation() async {
    if (_currentUserLocation != null && _mapLoaded) {
      final controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newLatLngZoom(_currentUserLocation!, 15));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to get your current location')),
      );
    }
  }

  void _navigateToRouteDetails(RouteModel route) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RouteDetailsScreen(routeId: route.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Waste Collection'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _centerOnUserLocation,
          ),
        ],
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _routeService.getActiveRoutesWithDriverInfo(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return Center(child: CircularProgressIndicator(color: primaryColor));
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                
                final activeRoutes = snapshot.data ?? [];
                
                if (activeRoutes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 24),
                        const Text(
                          'No active waste collection routes',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Check back later for updates',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return Column(
                  children: [
                    // Map showing only user's location and active routes
                    Expanded(
                      flex: 2,
                      child: Stack(
                        children: [
                          GoogleMap(
                            mapType: MapType.normal,
                            initialCameraPosition: _initialCameraPosition,
                            markers: _markers,
                            polylines: _polylines,
                            myLocationEnabled: true,
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: true,
                            mapToolbarEnabled: false,
                            compassEnabled: true,
                            onMapCreated: (GoogleMapController controller) {
                              _controller.complete(controller);
                              setState(() => _mapLoaded = true);
                              _updateMapWithUserLocation();
                            },
                          ),
                          if (!_mapLoaded)
                            const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                              ),
                            ),
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: FloatingActionButton(
                              onPressed: _centerOnUserLocation,
                              backgroundColor: Colors.white,
                              foregroundColor: primaryColor,
                              elevation: 4,
                              mini: true,
                              child: const Icon(Icons.my_location),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Active routes cards
                    Expanded(
                      flex: 3,
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Row(
                                children: [
                                  Icon(Icons.local_shipping, color: primaryColor, size: 24),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Active Collection Routes',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${activeRoutes.length}',
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: activeRoutes.length,
                                itemBuilder: (context, index) {
                                  final routeData = activeRoutes[index];
                                  final RouteModel route = routeData['route'] as RouteModel;
                                  final completionPercentage = routeData['completionPercentage'] as double? ?? 0.0;
                                  final remainingTimeMinutes = routeData['remainingTimeMinutes'] as int? ?? 0;
                                  final estimatedCompletionTime = routeData['estimatedCompletionTime'] as DateTime? ?? DateTime.now().add(Duration(minutes: remainingTimeMinutes));
                                  
                                  // Get the current time
                                  final now = DateTime.now();
                                  
                                  // Determine ETA status color based on estimated completion time
                                  Color etaColor = primaryColor;
                                  if (estimatedCompletionTime.isBefore(now)) {
                                    etaColor = Colors.red;
                                  } else if (estimatedCompletionTime.difference(now).inMinutes <= 30) {
                                    etaColor = Colors.orange;
                                  }
                                  
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: InkWell(
                                      onTap: () => _navigateToRouteDetails(route),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        padding: const EdgeInsets.all(8),
                                                        decoration: BoxDecoration(
                                                          color: primaryColor.withOpacity(0.1),
                                                          shape: BoxShape.circle,
                                                        ),
                                                        child: Icon(
                                                          Icons.local_shipping,
                                                          color: primaryColor,
                                                          size: 22,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Text(
                                                          route.name,
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 18,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: primaryColor.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(20),
                                                    border: Border.all(color: primaryColor),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.route,
                                                        color: primaryColor,
                                                        size: 16,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'ACTIVE',
                                                        style: TextStyle(
                                                          color: primaryColor,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      _buildInfoRow(
                                                        Icons.person,
                                                        'Driver:',
                                                        route.driverName ?? 'Not assigned',
                                                      ),
                                                      const SizedBox(height: 8),
                                                      _buildInfoRow(
                                                        Icons.recycling,
                                                        'Waste Type:',
                                                        route.wasteCategory.toUpperCase(),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      _buildInfoRow(
                                                        Icons.local_shipping,
                                                        'Truck ID:',
                                                        route.truckId ?? 'N/A',
                                                      ),
                                                      const SizedBox(height: 8),
                                                      _buildInfoRow(
                                                        Icons.straighten,
                                                        'Distance:',
                                                        '${route.distance.toStringAsFixed(1)} km',
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.access_time,
                                                  size: 16,
                                                  color: etaColor,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'ETA: ${DateFormat('h:mm a').format(estimatedCompletionTime)}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: etaColor,
                                                  ),
                                                ),
                                                Text(
                                                  ' (${remainingTimeMinutes} min remaining)',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            const Text(
                                              'Route Progress:',
                                              style: TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 8),
                                            Stack(
                                              children: [
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: LinearProgressIndicator(
                                                    value: completionPercentage / 100,
                                                    backgroundColor: Colors.grey[200],
                                                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                                                    minHeight: 10,
                                                  ),
                                                ),
                                                if (completionPercentage > 10)
                                                  Positioned.fill(
                                                    child: Align(
                                                      alignment: Alignment.centerLeft,
                                                      child: Padding(
                                                        padding: EdgeInsets.only(left: MediaQuery.of(context).size.width * (completionPercentage / 100) * 0.7 - 15),
                                                        child: Icon(
                                                          Icons.local_shipping,
                                                          color: Colors.white,
                                                          size: 15,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              '${completionPercentage.toStringAsFixed(1)}% complete',
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                            const SizedBox(height: 16),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                OutlinedButton.icon(
                                                  onPressed: () {
                                                    if (route.driverContact != null) {
                                                      final url = 'tel:${route.driverContact}';
                                                      url_launcher.launchUrl(Uri.parse(url));
                                                    } else {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(content: Text('Driver contact not available')),
                                                      );
                                                    }
                                                  },
                                                  icon: const Icon(Icons.phone, size: 16),
                                                  label: const Text('Contact'),
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: primaryColor,
                                                    side: BorderSide(color: primaryColor),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                  ),
                                                ),
                                                ElevatedButton.icon(
                                                  onPressed: () => _navigateToRouteDetails(route),
                                                  icon: const Icon(Icons.arrow_forward, size: 16),
                                                  label: const Text('View Details'),
                                                  style: ElevatedButton.styleFrom(
                                                    foregroundColor: Colors.white,
                                                    backgroundColor: primaryColor,
                                                    elevation: 0,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
  
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}