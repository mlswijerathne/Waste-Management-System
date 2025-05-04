import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:waste_management/models/routeModel.dart';
import 'package:waste_management/service/route_service.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

class DriverRouteDetailScreen extends StatefulWidget {
  final RouteModel route;

  const DriverRouteDetailScreen({Key? key, required this.route})
    : super(key: key);

  @override
  _DriverRouteDetailScreenState createState() =>
      _DriverRouteDetailScreenState();
}

class _DriverRouteDetailScreenState extends State<DriverRouteDetailScreen> {
  final RouteService _routeService = RouteService();
  late RouteModel _route;
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  LatLng? _currentPosition;
  bool _isLoading = true;
  bool _isMapReady = false;
  bool _locationPermissionGranted = false;
  Timer? _animationTimer;
  int _currentPathIndex = 0;
  bool _animationActive = false;
  BitmapDescriptor? _truckIcon;
  final Color primaryColor = const Color(0xFF59A867);

  @override
  void initState() {
    super.initState();
    _route = widget.route;

    // Initialize current position to route start point
    _currentPosition = LatLng(_route.startLat, _route.startLng);

    _loadTruckIcon();
    _checkLocationPermission();
    _initializeMapData();
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
        _truckIcon = BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueBlue,
        );
        print('Using default blue marker as fallback');
      }
    }

    // If we already have a position, update the truck marker with the icon
    if (_currentPosition != null && mounted) {
      setState(() {
        _updateTruckMarker(_currentPosition!);
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

  Future<void> _checkLocationPermission() async {
    // Check if location permission is granted
    final status = await Permission.location.status;
    setState(() {
      _locationPermissionGranted = status.isGranted;
    });

    // If not granted, request it
    if (!status.isGranted) {
      final result = await Permission.location.request();
      setState(() {
        _locationPermissionGranted = result.isGranted;
      });
    }

    // Setup route progress listener after checking permissions
    _setupRouteProgressListener();
  }

  void _initializeMapData() {
    // Add start and end markers
    final startPoint = LatLng(_route.startLat, _route.startLng);
    final endPoint = LatLng(_route.endLat, _route.endLng);

    print('Start Point: ${_route.startLat}, ${_route.startLng}');

    // Set current position to start point if not already set
    if (_currentPosition == null ||
        (_currentPosition!.latitude == 0 && _currentPosition!.longitude == 0)) {
      _currentPosition = startPoint;
    }

    _markers.add(
      Marker(
        markerId: const MarkerId('start'),
        position: startPoint,
        infoWindow: const InfoWindow(title: 'Start Point'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
    );

    _markers.add(
      Marker(
        markerId: const MarkerId('end'),
        position: endPoint,
        infoWindow: const InfoWindow(title: 'End Point'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );

    // Add truck marker if route is active
    if (_route.isActive) {
      _updateTruckMarker(startPoint);
    }

    // Add route polyline if available
    if (_route.actualDirectionPath.isNotEmpty) {
      final polylinePoints =
          _route.actualDirectionPath
              .map((point) => LatLng(point['lat']!, point['lng']!))
              .toList();

      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: polylinePoints,
          color: primaryColor,
          width: 5,
        ),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _setupRouteProgressListener() {
    if (_route.isActive && _locationPermissionGranted) {
      _routeService.getRouteProgress(_route.id).listen((position) {
        if (position != null && mounted) {
          // Filter out invalid zero coordinates
          if (position.latitude == 0.0 && position.longitude == 0.0) {
            print('Ignoring zero coordinates from route progress');
            return;
          }

          setState(() {
            _currentPosition = position;
            // Update truck marker position
            _updateTruckMarker(position);
          });

          // Move camera to follow the current position only if map is ready
          if (_isMapReady && _mapController != null) {
            _mapController?.animateCamera(CameraUpdate.newLatLng(position));
          }
        } else if (_currentPosition == null && mounted) {
          // If no position received but route is active, use start point
          LatLng startPoint = LatLng(_route.startLat, _route.startLng);
          setState(() {
            _currentPosition = startPoint;
            _updateTruckMarker(startPoint);
          });
        }
      });
    } else if (_route.isActive) {
      // If route is active but we don't have location permission,
      // use animation along the predefined route

      // Make sure we have a valid position before starting animation
      if (_currentPosition == null ||
          (_currentPosition!.latitude == 0 &&
              _currentPosition!.longitude == 0)) {
        _currentPosition = LatLng(_route.startLat, _route.startLng);
        _updateTruckMarker(_currentPosition!);
      }

      if (!_route.isPaused) {
        _startRouteAnimation();
      }
    }
  }

  void _updateTruckMarker(LatLng position) {
    // Never use zero coordinates
    if (position.latitude == 0.0 && position.longitude == 0.0) {
      print('Preventing truck marker at zero coordinates');
      position = LatLng(_route.startLat, _route.startLng);
    }

    print(
      'Added truck marker at position: ${position.latitude}, ${position.longitude}',
    );

    // Calculate rotation angle based on direction of movement
    double rotation = 0.0;

    if (_currentPathIndex > 0 &&
        _route.actualDirectionPath.length > _currentPathIndex) {
      final previousPoint = LatLng(
        _route.actualDirectionPath[_currentPathIndex - 1]['lat']!,
        _route.actualDirectionPath[_currentPathIndex - 1]['lng']!,
      );

      // Calculate bearing between previous and current point
      rotation = _getBearing(previousPoint, position);
    }

    // Remove old marker and add new one with rotation
    _markers.removeWhere((marker) => marker.markerId.value == 'truck');
    _markers.add(
      Marker(
        markerId: const MarkerId('truck'),
        position: position,
        infoWindow: const InfoWindow(title: 'Truck Location'),
        icon:
            _truckIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        rotation: rotation,
        anchor: const Offset(0.5, 0.5),
        zIndex: 2, // Higher z-index to ensure visibility
      ),
    );
  }

  void _startRouteAnimation() {
    // Stop any existing animation
    if (_animationTimer != null && _animationTimer!.isActive) {
      _animationTimer!.cancel();
    }

    // Reset position to start
    _currentPathIndex = 0;
    _animationActive = true;

    // Only start animation if we have route points
    if (_route.actualDirectionPath.isEmpty) {
      print('Cannot start animation: route path is empty');
      return;
    }

    // Always start from the route's defined start point
    final initialPosition = LatLng(_route.startLat, _route.startLng);

    // Set current position and update truck marker
    _currentPosition = initialPosition;
    _updateTruckMarker(initialPosition);

    // Start animation timer
    _animationTimer = Timer.periodic(const Duration(milliseconds: 300), (
      timer,
    ) {
      if (!_animationActive || !mounted) {
        timer.cancel();
        return;
      }

      // Increment the path index
      _currentPathIndex++;

      // If we reached the end of the path, reset or stop
      if (_currentPathIndex >= _route.actualDirectionPath.length) {
        timer.cancel();
        _animationActive = false;
        return;
      }

      // Get current point
      final currentPoint = LatLng(
        _route.actualDirectionPath[_currentPathIndex]['lat']!,
        _route.actualDirectionPath[_currentPathIndex]['lng']!,
      );

      // Update truck marker
      setState(() {
        _currentPosition = currentPoint;
        _updateTruckMarker(currentPoint);

        // Update progress percentage based on path progress
        final progressPercentage =
            (_currentPathIndex * 100) / _route.actualDirectionPath.length;
        _route = _route.copyWith(currentProgressPercentage: progressPercentage);
      });

      // Move camera to follow the animated marker if map is ready
      if (_isMapReady && _mapController != null) {
        _mapController?.animateCamera(CameraUpdate.newLatLng(currentPoint));
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

  Future<void> _startRoute() async {
    try {
      if (!_locationPermissionGranted) {
        // Show alert asking for location permission
        bool shouldRequest = await showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Location Permission Required'),
                content: const Text(
                  'This app needs location permission to track your route progress. Without this permission, we\'ll use a simulated route.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Use Simulation'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Settings'),
                  ),
                ],
              ),
        );

        if (shouldRequest == true) {
          await openAppSettings();
          return;
        } else {
          // Continue with simulation
        }
      }

      if (_route.completedAt != null) {
        await _routeService.restartCompletedRoute(_route.id);
      } else {
        await _routeService.startRoute(_route.id);
      }

      // Set the driver's location to the route's start point
      final startPoint = LatLng(_route.startLat, _route.startLng);

      print(
        'Starting route at: ${startPoint.latitude}, ${startPoint.longitude}',
      );

      setState(() {
        _currentPosition = startPoint;

        // Explicitly update truck marker at start point
        _updateTruckMarker(startPoint);

        _route = _route.copyWith(
          isActive: true,
          isPaused: false,
          startedAt: DateTime.now(),
          completedAt: null,
          currentProgressPercentage: 0.0,
        );
      });

      // Move the camera to the start position
      if (_isMapReady && _mapController != null) {
        print('Animating camera to: ${_route.startLat}, ${_route.startLng}');
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(startPoint, 14),
        );
      } else {
        Future.delayed(const Duration(milliseconds: 500), () {
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(startPoint, 14),
          );
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _route.completedAt != null
                ? 'Route restarted successfully'
                : 'Route started successfully',
          ),
        ),
      );

      _setupRouteProgressListener();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error starting route: $e')));
    }
  }

  Future<void> _resumeRoute() async {
    try {
      await _routeService.resumeRoute(_route.id);

      // If no current position or at zero coordinates, use the route start point
      if (_currentPosition == null ||
          (_currentPosition!.latitude == 0 &&
              _currentPosition!.longitude == 0)) {
        _currentPosition = LatLng(_route.startLat, _route.startLng);
        _updateTruckMarker(_currentPosition!);
      }

      setState(() {
        _route = _route.copyWith(isPaused: false, resumedAt: DateTime.now());
        if (!_locationPermissionGranted) {
          _animationActive = true;
          _startRouteAnimation();
        }
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Route resumed')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error resuming route: $e')));
    }
  }

  Future<void> _pauseRoute() async {
    try {
      await _routeService.pauseRoute(_route.id);
      setState(() {
        _route = _route.copyWith(isPaused: true, pausedAt: DateTime.now());
        if (!_locationPermissionGranted) {
          _animationActive = false;
          if (_animationTimer != null && _animationTimer!.isActive) {
            _animationTimer!.cancel();
          }
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Route paused')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error pausing route: $e')));
    }
  }

  @override
  void dispose() {
    // Cancel animation timer
    if (_animationTimer != null && _animationTimer!.isActive) {
      _animationTimer!.cancel();
    }
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _completeRoute() async {
    try {
      await _routeService.completeRoute(_route.id);
      setState(() {
        _route = _route.copyWith(
          isActive: false,
          isPaused: false,
          completedAt: DateTime.now(),
          currentProgressPercentage: 100.0,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Route completed successfully')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error completing route: $e')));
    }
  }

  Future<void> _cancelRoute() async {
    bool confirm = await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Cancellation'),
            content: const Text('Are you sure you want to cancel this route?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await _routeService.cancelRoute(_route.id);
        setState(() {
          _route = _route.copyWith(
            isActive: false,
            isPaused: false,
            isCancelled: true,
            cancelledAt: DateTime.now(),
          );
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Route cancelled')));
        Navigator.pop(
          context,
          true,
        ); // Return true to indicate route cancellation
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error cancelling route: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF59A867)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _route.name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildStatusBar(),
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                GoogleMap(
                  onMapCreated: (controller) {
                    _mapController = controller;
                    setState(() {
                      _isMapReady = true;
                    });

                    // Move the camera to the start position
                    controller.animateCamera(
                      CameraUpdate.newLatLngZoom(
                        LatLng(_route.startLat, _route.startLng),
                        14,
                      ),
                    );

                    // If route is active, ensure truck marker is showing at valid position
                    if (_route.isActive) {
                      LatLng position;
                      if (_currentPosition == null ||
                          (_currentPosition!.latitude == 0 &&
                              _currentPosition!.longitude == 0)) {
                        position = LatLng(_route.startLat, _route.startLng);
                      } else {
                        position = _currentPosition!;
                      }

                      // Use slight delay to make sure the marker gets added after map is ready
                      Future.delayed(Duration(milliseconds: 500), () {
                        if (mounted) {
                          setState(() {
                            _updateTruckMarker(position);
                          });
                        }
                      });
                    }
                  },
                  initialCameraPosition: CameraPosition(
                    target: LatLng(_route.startLat, _route.startLng),
                    zoom: 14,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: _locationPermissionGranted,
                  myLocationButtonEnabled: _locationPermissionGranted,
                  mapToolbarEnabled: true,
                  compassEnabled: true,
                  zoomControlsEnabled: false,
                  mapType: MapType.normal,
                  tiltGesturesEnabled: true,
                  rotateGesturesEnabled: true,
                ),

                // Map controls
                Positioned(
                  top: 16,
                  right: 16,
                  child: Column(
                    children: [
                      _buildMapControlButton(
                        icon: Icons.my_location,
                        onPressed: () {
                          if (_currentPosition != null) {
                            _mapController?.animateCamera(
                              CameraUpdate.newLatLngZoom(_currentPosition!, 15),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildMapControlButton(
                        icon: Icons.zoom_in,
                        onPressed: () {
                          _mapController?.animateCamera(CameraUpdate.zoomIn());
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildMapControlButton(
                        icon: Icons.zoom_out,
                        onPressed: () {
                          _mapController?.animateCamera(CameraUpdate.zoomOut());
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(flex: 3, child: _buildRouteInfoSection()),
        ],
      ),
      bottomNavigationBar: _buildActionButtons(),
    );
  }

  Widget _buildMapControlButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 18),
        color: primaryColor,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      color: _getStatusColor(),
      padding: const EdgeInsets.symmetric(vertical: 10),
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_getStatusIcon(), color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Text(
            _getStatusText().toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon() {
    if (_route.isPaused) return Icons.pause_circle_filled;
    if (_route.completedAt != null) return Icons.check_circle;
    if (_route.cancelledAt != null) return Icons.cancel;
    if (_route.isActive) return Icons.directions_car;
    return Icons.schedule;
  }

  Widget _buildRouteInfoSection() {
    // Get waste category info
    Color categoryColor =
        _route.wasteCategory == 'organic' ? Colors.green.shade800 : Colors.blue;

    String categoryText =
        _route.wasteCategory == 'organic' ? 'ORGANIC WASTE' : 'INORGANIC WASTE';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _route.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: categoryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: categoryColor.withOpacity(0.5),
                          ),
                        ),
                        child: Text(
                          categoryText,
                          style: TextStyle(
                            color: categoryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_route.isActive) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Progress',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: primaryColor, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.2),
                              spreadRadius: 1,
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '${(_route.currentProgressPercentage ?? 0).toInt()}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            if (_route.isActive) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (_route.currentProgressPercentage ?? 0.0) / 100,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Route info
            _buildInfoRow(
              Icons.route,
              'Distance',
              '${_route.distance.toStringAsFixed(1)} km',
            ),
            _buildInfoRow(
              Icons.access_time,
              'Schedule',
              '${_formatTime(_route.scheduleStartTime)} - ${_formatTime(_route.scheduleEndTime)}',
            ),
            _buildInfoRow(
              Icons.calendar_today,
              'Start Date',
              _formatDateTime(_route.startedAt ?? _route.createdAt),
            ),

            // Location permission warning
            if (!_locationPermissionGranted) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[300]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_off,
                      color: Colors.orange[700],
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Enable location for accurate tracking',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange[800],
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await openAppSettings();
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(60, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: Colors.orange[700],
                      ),
                      child: const Text(
                        'ENABLE',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: primaryColor),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!_route.isActive && !_route.isCancelled)
            _buildCircleActionButton(
              icon:
                  _route.completedAt != null ? Icons.refresh : Icons.play_arrow,
              color: primaryColor,
              onPressed: (_isMapReady) ? _startRoute : null,
              label: _route.completedAt != null ? 'RESTART' : 'START',
            ),
          if (_route.isActive && !_route.isPaused)
            _buildCircleActionButton(
              icon: Icons.pause,
              color: Colors.orange,
              onPressed: _pauseRoute,
              label: 'PAUSE',
            ),
          if (_route.isActive && _route.isPaused)
            _buildCircleActionButton(
              icon: Icons.play_arrow,
              color: primaryColor,
              onPressed: _resumeRoute,
              label: 'RESUME',
            ),
          if (_route.isActive)
            _buildCircleActionButton(
              icon: Icons.check,
              color: Colors.blue[700]!,
              onPressed: _completeRoute,
              label: 'COMPLETE',
            ),
          if (!_route.isCancelled && _route.completedAt == null)
            _buildCircleActionButton(
              icon: Icons.cancel,
              color: Colors.red[700]!,
              onPressed: _cancelRoute,
              label: 'CANCEL',
            ),
        ],
      ),
    );
  }

  Widget _buildCircleActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    required String label,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: color,
            shape: const CircleBorder(),
            elevation: 2,
            child: InkWell(
              onTap: onPressed,
              customBorder: const CircleBorder(),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText() {
    if (_route.isPaused) return 'Route Paused';
    if (_route.completedAt != null) return 'Route Completed';
    if (_route.cancelledAt != null) return 'Route Cancelled';
    if (_route.isActive) return 'Route Active';
    return 'Ready to Start';
  }

  Color _getStatusColor() {
    if (_route.isPaused) return Colors.orange[700]!;
    if (_route.completedAt != null) return Colors.grey[700]!;
    if (_route.cancelledAt != null) return Colors.red[700]!;
    if (_route.isActive) return primaryColor;
    return Colors.blue[700]!;
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM d, HH:mm').format(dateTime);
  }

  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('h:mm a').format(dt);
  }
}
