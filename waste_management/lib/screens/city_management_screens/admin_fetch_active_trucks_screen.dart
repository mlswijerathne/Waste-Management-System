import 'dart:async';
import 'dart:math' as Math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:waste_management/service/route_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:waste_management/widgets/admin_navbar.dart';

class AdminActiveDriversScreen extends StatefulWidget {
  const AdminActiveDriversScreen({Key? key}) : super(key: key);

  @override
  State<AdminActiveDriversScreen> createState() =>
      _AdminActiveDriversScreenState();
}

class _AdminActiveDriversScreenState extends State<AdminActiveDriversScreen>
    with TickerProviderStateMixin {  final RouteService _routeService = RouteService();
  final Completer<GoogleMapController> _controller = Completer();  final Color primaryColor = const Color(0xFF59A867);
  bool _mapCreated = false;
  Timer? _locationUpdateTimer;

  Set<Marker> _markers = {};
  Map<String, LatLng> _lastPositions = {};
  Map<String, AnimationController> _animationControllers = {};
  Map<String, Animation<LatLng>> _animations = {};
  BitmapDescriptor? _truckIcon;
  BitmapDescriptor? _activeTruckIcon;
  int _activeDriverCount = 0;
  List<Map<String, dynamic>> _allRoutes = [];
  Map<String, dynamic>? _selectedDriver;
  bool _followSelectedTruck = false;

  // Real-time location updates interval (in seconds)
  final int _updateIntervalSeconds = 3;

  CameraPosition _initialCameraPosition = const CameraPosition(
    target: LatLng(
      6.9271,
      79.8612,
    ), // Default coordinates for Colombo, Sri Lanka
    zoom: 12,
  );
  @override
  void initState() {
    super.initState();
    print('Initializing AdminActiveDriversScreen');
    _loadCustomIcons();

    // First, subscribe to routes
    _subscribeToRoutes();

    // Perform multiple location refreshes at startup to ensure we get the latest data
    // Immediate refresh
    Future.delayed(const Duration(milliseconds: 500), () {
      print('Initial location data refresh (500ms)');
      _refreshLocationData();
    });

    // Second refresh after 2 seconds
    Future.delayed(const Duration(milliseconds: 2000), () {
      print('Secondary location data refresh (2s)');
      _refreshLocationData();
    });

    // Third refresh after 5 seconds
    Future.delayed(const Duration(milliseconds: 5000), () {
      print('Final startup location data refresh (5s)');
      _refreshLocationData();
    });

    // Start periodic updates
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();

    // Cancel all route progress listeners
    for (var subscription in _progressListeners.values) {
      subscription.cancel();
    }
    _progressListeners.clear();

    for (var controller in _animationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _updateRouteWithRealTimeData(
    String routeId,
    Map<String, dynamic> progressData,
  ) {
    if (!mounted) return;

    // Find the route in our list
    final routeIndex = _allRoutes.indexWhere(
      (data) => data['route'].id == routeId,
    );
    if (routeIndex < 0) {
      print('Route $routeId not found in active routes list');
      return;
    }

    // Get the new position
    final lat = (progressData['currentLat'] as num).toDouble();
    final lng = (progressData['currentLng'] as num).toDouble();
    final newPosition = LatLng(lat, lng);

    print('Updating route $routeId with real-time position: $lat, $lng');

    // Update the route data in our list
    setState(() {
      final updatedRouteData = Map<String, dynamic>.from(
        _allRoutes[routeIndex],
      );
      updatedRouteData['currentPosition'] = newPosition;

      // Update completion percentage if available
      if (progressData['completionPercentage'] != null) {
        updatedRouteData['completionPercentage'] =
            progressData['completionPercentage'];
      }

      // Update remaining time if available
      if (progressData['remainingTimeMinutes'] != null) {
        updatedRouteData['remainingTimeMinutes'] =
            progressData['remainingTimeMinutes'];
      }

      // Update estimated completion time if available
      if (progressData['estimatedCompletionTime'] != null) {
        updatedRouteData['estimatedCompletionTime'] =
            progressData['estimatedCompletionTime'];
      }

      _allRoutes[routeIndex] = updatedRouteData;
    });

    // Update markers with the new position
    _updateMarkers();

    // If we're following this truck, update the camera position
    if (_followSelectedTruck &&
        _selectedDriver != null &&
        _selectedDriver!['route'].id == routeId) {
      _updateCameraIfFollowing();
    }
  }

  Future<void> _loadCustomIcons() async {
    try {
      // Load custom truck icon with explicit size parameters
      final Uint8List truckIconBytes = await _getBytesFromAsset(
        'assets/icons/truck_icon.png',
        110, // Larger size for better visibility
      );
      _truckIcon = BitmapDescriptor.fromBytes(truckIconBytes);

      // Load active truck icon (slightly larger for emphasis)
      final Uint8List activeTruckIconBytes = await _getBytesFromAsset(
        'assets/icons/truck_icon.png',
        140, // Larger size for the selected truck
      );
      _activeTruckIcon = BitmapDescriptor.fromBytes(activeTruckIconBytes);

      print('Custom truck icons loaded successfully with custom sizes');
    } catch (e) {
      print('Error loading custom truck icons: $e');

      // Fallback: try standard asset loading
      try {
        _truckIcon = await BitmapDescriptor.fromAssetImage(
          const ImageConfiguration(size: Size(48, 48)),
          'assets/icons/truck_icon.png',
        );

        _activeTruckIcon = await BitmapDescriptor.fromAssetImage(
          const ImageConfiguration(size: Size(64, 64)),
          'assets/icons/truck_icon.png',
        );

        print('Custom truck icons loaded with standard method');
      } catch (e) {
        print('Fallback icon loading failed: $e');

        // Final fallback: use default markers with different hues
        _truckIcon = BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueAzure,
        );
        _activeTruckIcon = BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueBlue,
        );
      }
    }
  }

  Future<Uint8List> _getBytesFromAsset(String path, int width) async {
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

  void _subscribeToRoutes() {
    // Listen for active routes with driver information
    _routeService.getActiveRoutesWithDriverInfo().listen((routes) {
      if (mounted) {
        setState(() {
          _allRoutes = routes;
          _updateMarkers();

          // Set up real-time listeners for each route's location
          _setupRouteProgressListeners(routes);
        });
      }
    });
  }

  // Map to store active progress listeners
  Map<String, StreamSubscription> _progressListeners = {};

  void _setupRouteProgressListeners(List<Map<String, dynamic>> routes) {
    // First, cancel any listeners for routes that are no longer active
    final activeRouteIds = routes.map((r) => r['route'].id).toSet();
    _progressListeners.keys.toList().forEach((routeId) {
      if (!activeRouteIds.contains(routeId)) {
        print('Cancelling listener for inactive route $routeId');
        _progressListeners[routeId]?.cancel();
        _progressListeners.remove(routeId);
      }
    });

    // Now set up listeners for all active routes
    for (var routeData in routes) {
      final routeId = routeData['route'].id;

      // Skip if we already have a listener for this route
      if (_progressListeners.containsKey(routeId)) continue;

      print('Setting up real-time listener for route $routeId');

      // Create a real-time listener for this route's progress
      final listener = _routeService.listenToRouteProgress(routeId).listen((
        progressData,
      ) {
        if (progressData != null && mounted) {
          // Update the route data with real-time position
          _updateRouteWithRealTimeData(routeId, progressData);
        }
      });

      _progressListeners[routeId] = listener;
    }
  }

  void _startLocationUpdates() {
    // Set up a timer to periodically refresh location data as a fallback
    _locationUpdateTimer = Timer.periodic(
      Duration(seconds: _updateIntervalSeconds),
      (_) {
        // Force a location refresh in case the real-time listeners missed any updates
        _refreshLocationData();

        // Log a debug message every update interval
        print('Periodic location refresh triggered (fallback mechanism)');

        // Check if markers need updating
        print(
          'Active route count: ${_allRoutes.length}, Marker count: ${_markers.length}',
        );

        // Every 30 seconds, check for stale position data
        final now = DateTime.now();
        if (now.second % 30 == 0) {
          _checkForStalePositionData();
        }
      },
    );
  }

  void _checkForStalePositionData() {
    print('Checking for stale position data at ${DateTime.now()}');

    for (var routeData in _allRoutes) {
      final route = routeData['route'];
      final routeId = route.id;

      // Check if we have a real-time listener for this route
      if (!_progressListeners.containsKey(routeId)) {
        print('Warning: No real-time listener for active route $routeId');
      }
    }
  }

  Future<void> _refreshLocationData() async {
    // Manually refresh the location data for each active route
    if (_allRoutes.isEmpty) {
      print('No active routes to refresh');
      return;
    }

    print('Refreshing location data for ${_allRoutes.length} active routes');
    List<Map<String, dynamic>> refreshedRoutes = [];

    for (var routeData in _allRoutes) {
      final route = routeData['route'];
      print('Refreshing route ${route.id} (${route.name})');
      try {
        // Get the latest position data for this route
        final progressDoc = await _routeService.getRouteProgressState(route.id);

        // Debug the progress document
        if (progressDoc != null) {
          print('Route ${route.id} progress: $progressDoc');

          // Check for data freshness by examining timestamp
          String? timestampStr = progressDoc['lastUpdated'] as String?;
          if (timestampStr != null) {
            try {
              final timestamp = DateTime.parse(timestampStr);
              final now = DateTime.now();
              final difference = now.difference(timestamp);

              print(
                'Route ${route.id} data is ${difference.inSeconds} seconds old',
              );

              // Flag stale data but still use it if it's the best we have
              if (difference.inMinutes > 10) {
                print(
                  'WARNING: Route ${route.id} data is more than 10 minutes old',
                );
              }
            } catch (e) {
              print('Error parsing timestamp: $e');
            }
          } else {
            print('No timestamp in route ${route.id} progress data');
          }
        } else {
          print('No progress data found for route ${route.id}');
        }

        // Check if we have valid position data
        if (progressDoc != null &&
            progressDoc['currentLat'] != null &&
            progressDoc['currentLng'] != null) {
          final lat = (progressDoc['currentLat'] as num).toDouble();
          final lng = (progressDoc['currentLng'] as num).toDouble();

          // Validate coordinates (skip obviously invalid values like 0,0)
          if (lat == 0.0 && lng == 0.0) {
            print('Ignoring invalid coordinates (0,0) for route ${route.id}');
            // Keep existing position data
            refreshedRoutes.add(routeData);
            continue;
          }

          // Also check for other obviously invalid coordinates
          if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
            print(
              'Ignoring invalid coordinates ($lat,$lng) for route ${route.id}',
            );
            // Keep existing position data
            refreshedRoutes.add(routeData);
            continue;
          }

          final newPosition = LatLng(lat, lng);
          print('Updated position for route ${route.id}: $lat, $lng');

          // Get route time estimation for more accurate completion data
          final timeEstimation = await _routeService.getRouteTimeEstimation(
            route.id,
          );

          refreshedRoutes.add({
            'route': route,
            'currentPosition': newPosition,
            'completionPercentage':
                progressDoc['completionPercentage'] ??
                timeEstimation['completionPercentage'] ??
                0.0,
            'estimatedCompletionTime':
                timeEstimation['estimatedCompletionTime'],
            'remainingTimeMinutes': timeEstimation['remainingTimeMinutes'],
          });
        } else {
          print(
            'No valid position data for route ${route.id}, using existing data',
          );
          // Keep existing position data if we couldn't get new data
          refreshedRoutes.add(routeData);
        }
      } catch (e) {
        print('Error refreshing location for route ${route.id}: $e');
        // Keep existing data in case of error
        refreshedRoutes.add(routeData);
      }
    }

    if (mounted) {
      print('Updating UI with ${refreshedRoutes.length} routes');
      setState(() {
        _allRoutes = refreshedRoutes;
        _updateMarkers();
      });

      // If following a truck, update the camera position
      if (_followSelectedTruck && _selectedDriver != null) {
        _updateCameraIfFollowing();
      }
    }
  }

  void _updateCameraIfFollowing() {
    if (_selectedDriver != null && _followSelectedTruck) {
      final routeId = _selectedDriver!['route'].id;

      print('Trying to follow truck for route $routeId');

      // Find the route we're currently following
      final routeData = _allRoutes.firstWhere(
        (data) => data['route'].id == routeId,
        orElse:
            () => Map<String, dynamic>(), // Return empty map instead of null
      );

      // If we found the route and it has a current position, update the camera
      if (routeData.isNotEmpty && routeData['currentPosition'] != null) {
        final position = routeData['currentPosition'] as LatLng;

        // Validate position - don't follow obviously invalid coordinates
        if (position.latitude == 0.0 && position.longitude == 0.0) {
          print('Cannot follow truck: invalid coordinates (0,0)');
          return;
        }

        print(
          'Following truck at position: ${position.latitude}, ${position.longitude}',
        );

        // Calculate bearing based on previous position if available
        final String routeId = _selectedDriver!['route'].id;
        final LatLng? previousPosition = _lastPositions[routeId];
        final double bearing =
            previousPosition != null
                ? _calculateBearing(previousPosition, position)
                : 0.0;

        _controller.future
            .then((controller) {
              // Use a smoother camera animation for better UX
              controller.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: position,
                    zoom: 16.5, // Slightly higher zoom for better visibility
                    bearing: bearing, // Orient map in direction of travel
                    tilt: 45.0, // Add some tilt for a better perspective
                  ),
                ),
              );
            })
            .catchError((error) {
              print('Error animating camera: $error');
            });
      } else {
        print('Cannot follow truck: position data not available');
      }
    }
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
      final isSelected =
          _selectedDriver != null && _selectedDriver!['route'].id == id;

      // Store the new position regardless of whether animation is needed
      _lastPositions[id] = newPos;

      // Only animate if there's a previous position that's different
      if (lastPos != null && lastPos != newPos) {
        _animateMarker(id, lastPos, newPos);
      }

      final marker = Marker(
        markerId: MarkerId(id),
        position: newPos,
        // Use the active icon for selected truck, regular icon for others
        icon:
            isSelected
                ? (_activeTruckIcon ??
                    BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueBlue,
                    ))
                : (_truckIcon ??
                    BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueAzure,
                    )),
        infoWindow: InfoWindow(
          title:
              '${route.driverName ?? 'Driver'} (${route.truckId ?? 'Unnamed'})',
          snippet:
              '${routeData['completionPercentage']?.toStringAsFixed(1) ?? '0'}% complete',
        ),
        onTap: () => _selectDriver(routeData),
        // Add rotation based on bearing if available
        rotation: _calculateBearing(lastPos, newPos),
        // Make the marker flat against the map
        flat: true,
        // Add a zIndex to ensure selected truck appears on top
        zIndex: isSelected ? 2 : 1,
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

  double _calculateBearing(LatLng? from, LatLng? to) {
    if (from == null || to == null) return 0;

    // No change in position, maintain current bearing
    if (from.latitude == to.latitude && from.longitude == to.longitude) {
      return 0;
    }

    // Calculate bearing/heading
    double lat1 = from.latitude * (3.14159 / 180);
    double lon1 = from.longitude * (3.14159 / 180);
    double lat2 = to.latitude * (3.14159 / 180);
    double lon2 = to.longitude * (3.14159 / 180);

    double dLon = lon2 - lon1;

    double y = Math.sin(dLon) * Math.cos(lat2);
    double x =
        Math.cos(lat1) * Math.sin(lat2) -
        Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLon);

    double bearing = Math.atan2(y, x) * (180 / 3.14159);
    return bearing.toDouble();
  }

  void _animateMarker(String id, LatLng from, LatLng to) {
    _animationControllers[id]?.dispose();

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    final animation = Tween<LatLng>(
      begin: from,
      end: to,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
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

    final pos = driverData['currentPosition'];

    if (pos != null && _mapCreated) {
      _controller.future.then((controller) {
        controller.animateCamera(CameraUpdate.newLatLng(pos));
        // Zoom in a bit when selecting a driver
        controller.animateCamera(CameraUpdate.zoomTo(15));
      });
    }
  }

  void _toggleFollowTruck() {
    setState(() {
      _followSelectedTruck = !_followSelectedTruck;
    });

    if (_followSelectedTruck && _selectedDriver != null) {
      _updateCameraIfFollowing();
    }
  }

  void _contactDriver() async {
    if (_selectedDriver == null) return;

    final contact = _selectedDriver!['route'].driverContact;
    if (contact == null || contact.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver contact unavailable')),
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
  Widget build(BuildContext context) {    return Scaffold(
      appBar: AppBar(
        title: Text('Active Drivers (${_activeDriverCount})'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshLocationData,
            tooltip: 'Refresh Locations',
          ),
        ],
      ),      bottomNavigationBar: AdminNavbar(
        currentIndex: 1, // Always 1 for this screen
        onTap: (index) {
          if (index != 1) {
            // Only navigate if not already on this tab
            if (index == 0) {
              Navigator.pushReplacementNamed(context, '/admin_home');
            } else if (index == 2) {
              Navigator.pushReplacementNamed(context, '/admin_cleanliness_issue_list');
            } else if (index == 3) {
              Navigator.pushReplacementNamed(context, '/admin_breakdown');
            }
          }
        },
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
                  mapToolbarEnabled: true,
                  compassEnabled: true,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
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
                        Icon(
                          Icons.directions_car,
                          color: primaryColor,
                          size: 20,
                        ),
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
                // Follow truck toggle button (only shown when a truck is selected)
                if (_selectedDriver != null)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          _followSelectedTruck
                              ? Icons.gps_fixed
                              : Icons.gps_not_fixed,
                          color:
                              _followSelectedTruck ? primaryColor : Colors.grey,
                        ),
                        onPressed: _toggleFollowTruck,
                        tooltip:
                            _followSelectedTruck
                                ? 'Stop Following'
                                : 'Follow Truck',
                      ),
                    ),
                  ),
                // Update timer indicator
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.update, color: primaryColor, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Updates every $_updateIntervalSeconds sec',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[800],
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
              child:
                  _selectedDriver == null
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
          Icon(Icons.touch_app, size: 60, color: Colors.grey[400]),
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
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverDetailsView() {
    final route = _selectedDriver!['route'];
    final position = _selectedDriver!['currentPosition'];
    final completionPercentage =
        _selectedDriver!['completionPercentage'] ?? 0.0;
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
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

          if (position != null) ...[
            const SizedBox(height: 8),
            Text(
              'Current Location: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontFamily: 'Monospace',
              ),
            ),
          ],

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
                            const Icon(
                              Icons.access_time,
                              color: Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'ETA: ${DateFormat('HH:mm').format(estimatedCompletionTime is DateTime ? estimatedCompletionTime : DateTime.now())}',
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
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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

                  if (route.driverContact != null &&
                      route.driverContact!.isNotEmpty)
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

                  _buildInfoRow(Icons.route, 'Route:', route.name ?? 'N/A'),

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
          ),          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
