import 'dart:math';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:waste_management/models/routeModel.dart';
import 'package:waste_management/models/userModel.dart';
import 'package:waste_management/screens/resident_screens/resident_route_details_screen.dart';
import 'package:waste_management/service/route_service.dart';
import 'package:waste_management/service/auth_service.dart';
import 'package:intl/intl.dart';

class ResidentActiveRoutesScreen extends StatefulWidget {
  const ResidentActiveRoutesScreen({Key? key}) : super(key: key);

  @override
  _ResidentActiveRoutesScreenState createState() => _ResidentActiveRoutesScreenState();
}

class _ResidentActiveRoutesScreenState extends State<ResidentActiveRoutesScreen> {
  final RouteService _routeService = RouteService();
  final AuthService _authService = AuthService();
  final Color primaryColor = Color(0xFF59A867);
  
  bool _isLoading = true;
  UserModel? _currentUser;
  List<Map<String, dynamic>> _nearbyActiveRoutes = [];
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  BitmapDescriptor? _truckIcon;
  Map<String, StreamSubscription> _routeSubscriptions = {};
  
  // Selected route state
  String? _selectedRouteId;
  
  // Default map position (will be updated with resident's location)
  static final LatLng _defaultPosition = LatLng(6.9271, 79.8612); // Colombo, Sri Lanka
  
  // Distance threshold in km for considering a route near resident
  static const double _nearbyThreshold = 0.5;
  
  @override
  void initState() {
    super.initState();
    _loadTruckIcon();
    _loadUserAndRoutes();
  }
  
  @override
  void dispose() {
    // Cancel all route progress subscriptions
    _routeSubscriptions.forEach((_, subscription) => subscription.cancel());
    _mapController?.dispose();
    super.dispose();
  }
  
  Future<void> _loadTruckIcon() async {
    try {
      final Uint8List markerIcon = await getBytesFromAsset(
        'assets/icons/truck_icon.png',
        80,
      );
      _truckIcon = BitmapDescriptor.fromBytes(markerIcon);
      print('Truck icon loaded successfully');
    } catch (e) {
      print('Error loading truck icon from bytes: $e');
      
      try {
        // If custom icon loading fails, use a default truck icon
        // ignore: deprecated_member_use
        _truckIcon = await BitmapDescriptor.fromAssetImage(
          const ImageConfiguration(size: Size(80, 80)),
          'assets/icons/truck_icon.png',
        );
        print('Loaded truck icon from asset image');
      } catch (e) {
        print('Error loading truck icon from asset image: $e');
        _truckIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
        print('Using default blue marker as fallback');
      }
    }
    
    // If we already have markers, update them with the new truck icon
    if (_markers.isNotEmpty && mounted) {
      setState(() {
        _prepareMapData();
      });
    }
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
    );
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
  }
  
  Future<void> _loadUserAndRoutes() async {
    try {
      // Get current user data
      final user = await _authService.getCurrentUser();
      
      if (user == null) {
        _showSnackBar('User not found. Please login again.');
        setState(() => _isLoading = false);
        return;
      }
      
      // Check if user has location saved
      if (user.latitude == null || user.longitude == null) {
        _showSnackBar('Please set your location first');
        setState(() { 
          _isLoading = false;
          _currentUser = user;
        });
        return;
      }
      
      setState(() => _currentUser = user);
      
      // Fetch active routes
      await _fetchNearbyActiveRoutes();
      
    } catch (e) {
      print('Error loading user and routes: $e');
      _showSnackBar('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchNearbyActiveRoutes() async {
    try {
      if (_currentUser?.latitude == null || _currentUser?.longitude == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      // Cancel any existing subscriptions
      _routeSubscriptions.forEach((_, subscription) => subscription.cancel());
      _routeSubscriptions.clear();
      
      // Get active routes with driver info
      final activeRoutesStream = _routeService.getActiveRoutesWithDriverInfo();
      
      // Wait for first event from stream
      final activeRoutes = await activeRoutesStream.first;
      
      List<Map<String, dynamic>> nearbyRoutes = [];
      
      // Filter routes by checking if resident is near route path
      for (var routeData in activeRoutes) {
        final route = routeData['route'] as RouteModel;
        final currentPosition = routeData['currentPosition'] as LatLng?;
        final completionPercentage = routeData['completionPercentage'] as double?;
        
        if (route.actualDirectionPath.isEmpty) continue;
        
        // Check if resident's location is on or near this route's path
        final isNearRoute = _isResidentNearRoutePath(
          LatLng(_currentUser!.latitude!, _currentUser!.longitude!),
          route.actualDirectionPath
        );
        
        if (isNearRoute) {
          nearbyRoutes.add({
            'route': route,
            'currentPosition': currentPosition ?? LatLng(route.startLat, route.startLng),
            'completionPercentage': completionPercentage ?? 0.0,
            'distanceToResident': _calculateDistanceToResident(route, _currentUser!),
          });
          
          // Setup real-time tracking for this route
          _setupRouteProgressListener(route.id);
        }
      }
      
      // Sort by distance to resident
      nearbyRoutes.sort((a, b) => 
        (a['distanceToResident'] as double).compareTo(b['distanceToResident'] as double)
      );
      
      setState(() {
        _nearbyActiveRoutes = nearbyRoutes;
        _isLoading = false;
        
        // If there was a selected route and it's no longer available, clear selection
        if (_selectedRouteId != null) {
          bool routeStillExists = nearbyRoutes.any(
            (r) => (r['route'] as RouteModel).id == _selectedRouteId
          );
          
          if (!routeStillExists) {
            _selectedRouteId = null;
          }
        }
      });
      
      // Prepare map data
      _prepareMapData();
      
    } catch (e) {
      print('Error fetching nearby active routes: $e');
      _showSnackBar('Error fetching routes: $e');
      setState(() => _isLoading = false);
    }
  }
  
  void _setupRouteProgressListener(String routeId) {
    // Cancel existing subscription for this route if exists
    _routeSubscriptions[routeId]?.cancel();
    
    // Create new subscription
    _routeSubscriptions[routeId] = _routeService.getRouteProgress(routeId).listen((position) {
      if (position != null && mounted) {
        // Filter out invalid zero coordinates
        if (position.latitude == 0.0 && position.longitude == 0.0) {
          print('Ignoring zero coordinates from route progress');
          return;
        }
        
        // Find the route in our list
        int routeIndex = _nearbyActiveRoutes.indexWhere(
          (r) => (r['route'] as RouteModel).id == routeId
        );
        
        if (routeIndex != -1) {
          setState(() {
            // Update current position for this route
            _nearbyActiveRoutes[routeIndex]['currentPosition'] = position;
            
            // Only update the marker if this is the currently selected route
            if (_selectedRouteId == routeId) {
              _updateTruckMarker(
                position,
                routeId,
                _nearbyActiveRoutes[routeIndex]['route'] as RouteModel
              );
            }
          });
        }
      }
    });
  }
  
  // Calculate bearing between two points (for truck rotation)
  double _getBearing(LatLng start, LatLng end) {
    final startLat = start.latitude * (pi / 180);
    final startLng = start.longitude * (pi / 180);
    final endLat = end.latitude * (pi / 180);
    final endLng = end.longitude * (pi / 180);

    final dLon = endLng - startLng;

    final y = sin(dLon) * cos(endLat);
    final x =
        cos(startLat) * sin(endLat) - sin(startLat) * cos(endLat) * cos(dLon);

    final bearing = atan2(y, x);

    // Convert to degrees
    final bearingDegrees = bearing * (180 / pi);
    return (bearingDegrees + 360) % 360;
  }
  
  void _updateTruckMarker(LatLng position, String routeId, RouteModel route) {
    // Never use zero coordinates
    if (position.latitude == 0.0 && position.longitude == 0.0) {
      print('Preventing truck marker at zero coordinates');
      position = LatLng(route.startLat, route.startLng);
    }
    
    print('Updated truck marker for route $routeId at: ${position.latitude}, ${position.longitude}');
    
    // Calculate rotation angle based on direction of movement
    double rotation = 0.0;
    
    // Find current position in the route path
    int pathIndex = -1;
    double minDistance = double.infinity;
    
    for (int i = 0; i < route.actualDirectionPath.length; i++) {
      final pathPoint = LatLng(
        route.actualDirectionPath[i]['lat']!,
        route.actualDirectionPath[i]['lng']!
      );
      
      final distance = _calculateHaversineDistance(
        position.latitude,
        position.longitude,
        pathPoint.latitude,
        pathPoint.longitude
      );
      
      if (distance < minDistance) {
        minDistance = distance;
        pathIndex = i;
      }
    }
    
    // Calculate rotation based on previous and next points if possible
    if (pathIndex > 0 && pathIndex < route.actualDirectionPath.length - 1) {
      final previousPoint = LatLng(
        route.actualDirectionPath[pathIndex - 1]['lat']!,
        route.actualDirectionPath[pathIndex - 1]['lng']!
      );
      
      rotation = _getBearing(previousPoint, position);
    }
    
    // Only update the truck marker if this is the selected route
    if (_selectedRouteId == routeId) {
      // Remove old truck marker
      _markers.removeWhere((marker) => marker.markerId.value == 'truck_$routeId');
      
      // Add new truck marker
      _markers.add(
        Marker(
          markerId: MarkerId('truck_$routeId'),
          position: position,
          infoWindow: InfoWindow(
            title: 'Truck: ${route.name}',
            snippet: 'Driver: ${route.driverName ?? "Unknown"}'
          ),
          icon: _truckIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          rotation: rotation,
          anchor: const Offset(0.5, 0.5),
          zIndex: 2,
        )
      );
    }
  }
  
  // Check if resident is near any point on the route path
  bool _isResidentNearRoutePath(LatLng residentLocation, List<Map<String, double>> routePath) {
    for (var pathPoint in routePath) {
      final pointLatLng = LatLng(pathPoint['lat']!, pathPoint['lng']!);
      
      // Calculate distance between resident and this point on the route
      final distance = _calculateHaversineDistance(
        residentLocation.latitude,
        residentLocation.longitude,
        pointLatLng.latitude,
        pointLatLng.longitude
      );
      
      // If resident is within threshold distance of any point on route, return true
      if (distance <= _nearbyThreshold) {
        return true;
      }
    }
    
    return false;
  }
  
  // Calculate distance between resident and route's current position
  double _calculateDistanceToResident(RouteModel route, UserModel resident) {
    if (resident.latitude == null || resident.longitude == null) return double.infinity;
    
    // Find minimum distance to any point on the route
    double minDistance = double.infinity;
    
    for (var pathPoint in route.actualDirectionPath) {
      final distance = _calculateHaversineDistance(
        resident.latitude!,
        resident.longitude!,
        pathPoint['lat']!,
        pathPoint['lng']!
      );
      
      if (distance < minDistance) {
        minDistance = distance;
      }
    }
    
    return minDistance;
  }
  
  // Haversine formula to calculate distance between two points on Earth
  double _calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // in kilometers
    
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    
    double a = 
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * 
        sin(dLon / 2) * sin(dLon / 2);
        
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double distance = earthRadius * c;
    
    return distance;
  }
  
  // Convert degrees to radians
  double _toRadians(double degree) {
    return degree * (pi / 180);
  }
  
  void _prepareMapData() {
    _markers.clear();
    _polylines.clear();
    
    // Always add resident's location marker
    if (_currentUser?.latitude != null && _currentUser?.longitude != null) {
      _markers.add(
        Marker(
          markerId: MarkerId('resident'),
          position: LatLng(_currentUser!.latitude!, _currentUser!.longitude!),
          infoWindow: InfoWindow(title: 'Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        )
      );
    }
    
    // If no route is selected, only show resident's location
    if (_selectedRouteId == null) {
      return;
    }
    
    // Find the selected route data
    final selectedRouteData = _nearbyActiveRoutes.firstWhere(
      (data) => (data['route'] as RouteModel).id == _selectedRouteId,
      orElse: () => _nearbyActiveRoutes.first,
    );
    
    final route = selectedRouteData['route'] as RouteModel;
    final currentPosition = selectedRouteData['currentPosition'] as LatLng;
    
    // Add start point marker
    _markers.add(
      Marker(
        markerId: MarkerId('start_${route.id}'),
        position: LatLng(route.startLat, route.startLng),
        infoWindow: InfoWindow(title: 'Start: ${route.name}'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      )
    );
      
      // Add end point marker
    _markers.add(
      Marker(
        markerId: MarkerId('end_${route.id}'),
        position: LatLng(route.endLat, route.endLng),
        infoWindow: InfoWindow(title: 'End: ${route.name}'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      )
    );
      
      // Add truck position marker
      _updateTruckMarker(currentPosition, route.id, route);
      
      // Add route polyline
    if (route.actualDirectionPath.isNotEmpty) {
      List<LatLng> polylinePoints = route.actualDirectionPath
          .map((point) => LatLng(point['lat']!, point['lng']!))
          .toList();
          
      _polylines.add(
        Polyline(
          polylineId: PolylineId('route_${route.id}'),
          points: polylinePoints,
          color: primaryColor,
          width: 5,
        )
      );
    }
  }
  
  // Select a specific route to display on map
  // Update the _selectRoute method in ResidentActiveRoutesScreen
void _selectRoute(String routeId) {
  // First check if we're selecting a new route or deselecting current route
  final bool isSelectingNew = _selectedRouteId != routeId;
  
  setState(() {
    // Toggle selection
    if (_selectedRouteId == routeId) {
      _selectedRouteId = null;
      _prepareMapData();
      _focusOnResidentLocation();
    } else {
      _selectedRouteId = routeId;
      _prepareMapData();
      
      // Find current truck position for the selected route
      try {
        final routeData = _nearbyActiveRoutes.firstWhere(
          (data) => (data['route'] as RouteModel).id == routeId,
        );
        
        final truckPosition = routeData['currentPosition'] as LatLng;
        
        // Prevent focusing on invalid coordinates
        if (truckPosition.latitude != 0.0 || truckPosition.longitude != 0.0) {
          // Use Future.delayed to ensure setState has completed
          Future.delayed(Duration.zero, () {
            _mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(
                truckPosition,
                16, // Higher zoom level for truck focus
              ),
            );
          });
        } else {
          // Fall back to route overview if truck position is invalid
          Future.delayed(Duration.zero, () {
            _focusOnSelectedRoute();
          });
        }
      } catch (e) {
        print('Error focusing on truck: $e');
        // Fall back to route overview
        Future.delayed(Duration.zero, () {
          _focusOnSelectedRoute();
        });
      }
    }
  });
}
  
  // Focus map on the selected route
  void _focusOnSelectedRoute() {
    if (_mapController != null && _selectedRouteId != null) {
      // Find the selected route data
      final routeData = _nearbyActiveRoutes.firstWhere(
        (data) => (data['route'] as RouteModel).id == _selectedRouteId,
        orElse: () => _nearbyActiveRoutes.first,
      );
      
      final route = routeData['route'] as RouteModel;
      final truckPosition = routeData['currentPosition'] as LatLng;
      
      // Calculate bounds that include the truck, start and end points
      List<LatLng> points = [
        truckPosition,
        LatLng(route.startLat, route.startLng),
        LatLng(route.endLat, route.endLng),
      ];
      
      // Also include resident's location
      if (_currentUser?.latitude != null && _currentUser?.longitude != null) {
        points.add(LatLng(_currentUser!.latitude!, _currentUser!.longitude!));
      }
      
      // Get bounds
      double minLat = double.infinity;
      double maxLat = -double.infinity;
      double minLng = double.infinity;
      double maxLng = -double.infinity;
      
      for (var point in points) {
        minLat = min(minLat, point.latitude);
        maxLat = max(maxLat, point.latitude);
        minLng = min(minLng, point.longitude);
        maxLng = max(maxLng, point.longitude);
      }
      
      // Add padding
      final padding = 0.01; // ~1km
      minLat -= padding;
      maxLat += padding;
      minLng -= padding;
      maxLng += padding;
      
      // Move camera to show all points
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          50, // padding in pixels
        ),
      );
    }
  }
  
  // Focus map on resident's location
  void _focusOnResidentLocation() {
    if (_mapController != null && _currentUser?.latitude != null && _currentUser?.longitude != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentUser!.latitude!, _currentUser!.longitude!),
          15, // Slightly higher zoom level for better visibility
        ),
      );
    }
  }
  
  // Get different colors for different routes
  Color _getRouteColor(int index) {
    List<Color> colors = [
      Colors.blue,
      Colors.purple,
      Colors.red,
      Colors.orange,
      Colors.teal,
    ];
    
    return colors[index % colors.length];
  }
  
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message))
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM d, HH:mm').format(dateTime);
  }

  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('h:mm a').format(dt);
  }

  String _formatEstimatedArrival(RouteModel route, double completionPercentage) {
    // If not started yet or already completed, return N/A
    if (!route.isActive || completionPercentage >= 100) {
      return 'N/A';
    }
    
    // Calculate estimated arrival time based on progress and route schedule
    DateTime now = DateTime.now();
    
    // If completion percentage is 0, use schedule start time
    if (completionPercentage <= 0) {
      return _formatTime(route.scheduleStartTime);
    }
    
    // Calculate remaining percentage
    double remainingPercentage = 100 - completionPercentage;
    
    // Calculate schedule duration in minutes
    int scheduleDurationMinutes = (route.scheduleEndTime.hour * 60 + route.scheduleEndTime.minute) - 
                                 (route.scheduleStartTime.hour * 60 + route.scheduleStartTime.minute);
    if (scheduleDurationMinutes <= 0) {
      scheduleDurationMinutes += 24 * 60; // Add 24 hours if end time is next day
    }
    
    // Calculate remaining minutes based on percentage
    int remainingMinutes = (scheduleDurationMinutes * remainingPercentage / 100).round();
    
    // Calculate estimated arrival time
    DateTime estimatedArrival = now.add(Duration(minutes: remainingMinutes));
    
    return DateFormat('h:mm a').format(estimatedArrival);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedRouteId != null ? 'Selected Route' : 'Nearby Active Routes'),
        backgroundColor: primaryColor,
        actions: [
          // Location focus button
          IconButton(
            icon: Icon(Icons.my_location),
            tooltip: 'Focus on your location',
            onPressed: _focusOnResidentLocation,
          ),
          // Toggle view button (when a route is selected)
          if (_selectedRouteId != null)
            IconButton(
              icon: Icon(Icons.layers),
              tooltip: 'Show All Routes',
              onPressed: () {
                setState(() {
                  _selectedRouteId = null;
                  _prepareMapData();
                  _focusOnResidentLocation();
                });
              },
            ),
          // Refresh button
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadUserAndRoutes();
            },
          ),
        ],
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: primaryColor))
        : _buildContent(),
    );
  }
  
  Widget _buildContent() {
    // If user location not set, show message
    if (_currentUser?.latitude == null || _currentUser?.longitude == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Location Not Set',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Please set your location to see nearby routes',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              icon: Icon(Icons.location_on),
              label: Text('Set Your Location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/resident_location_picker');
              },
            ),
          ],
        ),
      );
    }
    
    // If no nearby routes found, show message
    if (_nearbyActiveRoutes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No Nearby Routes',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'There are no active waste collection routes in your area',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              icon: Icon(Icons.refresh),
              label: Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                setState(() => _isLoading = true);
                _loadUserAndRoutes();
              },
            ),
          ],
        ),
      );
    }
    
    // Show map and route list
    return Column(
      children: [
        // Map view
        Expanded(
          flex: 1,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentUser?.latitude != null && _currentUser?.longitude != null
                ? LatLng(_currentUser!.latitude!, _currentUser!.longitude!)
                : _defaultPosition,
              zoom: 14,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            mapToolbarEnabled: true,
            compassEnabled: true,
            zoomControlsEnabled: true,
            onMapCreated: (controller) {
              _mapController = controller;
              
              // Focus on resident's location or selected route if any
              if (_selectedRouteId != null) {
                _focusOnSelectedRoute();
              } else if (_currentUser?.latitude != null && _currentUser?.longitude != null) {
                controller.animateCamera(
                  CameraUpdate.newLatLngZoom(
                    LatLng(_currentUser!.latitude!, _currentUser!.longitude!),
                    14,
                  ),
                );
              }
            },
          ),
        ),
        // Route list 
        Expanded(
          flex: 1,
          child: Container(
            color: Colors.white,
            child: ListView.builder(
              padding: EdgeInsets.only(bottom: 16),
              itemCount: _nearbyActiveRoutes.length,
              itemBuilder: (context, index) {
                final routeData = _nearbyActiveRoutes[index];
                final route = routeData['route'] as RouteModel;
                final completionPercentage = routeData['completionPercentage'] as double;
                final distanceToResident = routeData['distanceToResident'] as double;
                
                return _buildRouteCard(route, completionPercentage, distanceToResident, index, routeData);
              },
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildRouteCard(RouteModel route, double completionPercentage, double distanceToResident, int index, Map<String, dynamic> routeData) {
  // Get waste category info
  Color categoryColor = route.wasteCategory == 'organic' ? Colors.brown : Colors.blue;
  String categoryText = route.wasteCategory.toUpperCase();
  
  // Check if this route is currently selected
  bool isSelected = _selectedRouteId == route.id;
  
  return Card(
    margin: EdgeInsets.fromLTRB(16, index == 0 ? 16 : 8, 16, 8),
    elevation: isSelected ? 6 : 3,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: isSelected 
        ? BorderSide(color: primaryColor, width: 2) 
        : BorderSide.none,
    ),
    child: InkWell(
      onTap: () {
        _selectRoute(route.id);
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Waste category icon
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected 
                      ? primaryColor.withOpacity(0.2) 
                      : categoryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    route.wasteCategory == 'organic' ? Icons.eco : Icons.delete,
                    color: isSelected ? primaryColor : categoryColor,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? primaryColor : Colors.black,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        route.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Selected indicator
                if (isSelected)
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
              ],
            ),
            SizedBox(height: 16),
            
            // Route details
            Row(
              children: [
                _buildDetailItem(Icons.category, categoryText, isSelected ? primaryColor : categoryColor),
                SizedBox(width: 16),
                _buildDetailItem(
                  Icons.location_on, 
                  '${distanceToResident.toStringAsFixed(2)} km away',
                  isSelected ? primaryColor : Colors.red[700]!
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                _buildDetailItem(
                  Icons.person, 
                  'Driver: ${route.driverName ?? "Not assigned"}',
                  isSelected ? primaryColor : Colors.grey[700]!
                ),
              ],
            ),
            if (route.driverContact != null) SizedBox(height: 8),
            if (route.driverContact != null)
              Row(
                children: [
                  _buildDetailItem(
                    Icons.phone, 
                    route.driverContact!,
                    isSelected ? primaryColor : Colors.grey[700]!
                  ),
                ],
              ),
            
            // Estimated arrival time
            SizedBox(height: 8),
            Row(
              children: [
                _buildDetailItem(
                  Icons.access_time, 
                  'Est. Arrival: ${_formatEstimatedArrival(route, completionPercentage)}',
                  isSelected ? primaryColor : Colors.green[700]!
                ),
              ],
            ),
            
            SizedBox(height: 16),
            // Progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ROUTE PROGRESS: ${completionPercentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? primaryColor : Colors.grey[800],
                  ),
                ),
                SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: completionPercentage / 100,
                    backgroundColor: Colors.grey[200],
                    color: isSelected ? primaryColor : _getRouteColor(index),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            Row(
              children: [
                // View route button 
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(isSelected ? Icons.visibility_off : Icons.visibility),
                    label: Text(isSelected ? 'HIDE ROUTE' : 'VIEW DETAILS'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected ? Colors.grey[300] : _getRouteColor(index),
                      foregroundColor: isSelected ? Colors.black87 : Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      if (isSelected) {
                        // If already selected, deselect it
                        _selectRoute(route.id);
                      } else {
                        // If not selected, navigate to route details screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RouteDetailsScreen(routeId: route.id),
                          ),
                        );
                      }
                    },
                  ),
                ),
                SizedBox(width: 8),
                // Track truck button
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: primaryColor),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.my_location, color: primaryColor),
                    tooltip: 'Track Truck',
                    onPressed: () {
                      // Focus map on truck's current position
                      if (_mapController != null) {
                        LatLng truckPosition = routeData['currentPosition'] as LatLng;
                        
                        // First select this route
                        if (_selectedRouteId != route.id) {
                          _selectRoute(route.id);
                        }
                        
                        // Then zoom to truck position
                        _mapController!.animateCamera(
                          CameraUpdate.newLatLngZoom(truckPosition, 16),
                        );
                      }
                    },
                  ),
                ),
                SizedBox(width: 8),
                // Call driver button (if driver contact is available)
                if (route.driverContact != null)
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.phone, color: Colors.green),
                      tooltip: 'Call Driver',
                      onPressed: () {
                        // Implement call functionality here
                        // This would typically use url_launcher package
                        _showSnackBar('Calling driver: ${route.driverContact}');
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
  
  Widget _buildDetailItem(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}