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
import 'package:geolocator/geolocator.dart';

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
  StreamSubscription<Position>? _positionStreamSubscription;

  @override
  void initState() {
    super.initState();
    _route = widget.route;

    _currentPosition = LatLng(_route.startLat, _route.startLng);

    // Load truck icon first to ensure it's ready when we need it
    _loadTruckIcon().then((_) {
      _checkLocationPermission();
      _initializeMapData();
    });
  }

  Future<void> _loadTruckIcon() async {
    try {
      // First attempt: Load from asset and convert to bytes
      final Uint8List markerIcon = await getBytesFromAsset(
        'assets/icons/truck_icon.png',
        80,
      );
      _truckIcon = BitmapDescriptor.fromBytes(markerIcon);
      print('Truck icon loaded successfully from bytes');

      if (_currentPosition != null && mounted) {
        setState(() {
          _updateTruckMarker(_currentPosition!);
        });
      }
      return;
    } catch (e) {
      print('Error loading truck icon from bytes: $e');
    }

    try {
      // Second attempt: Use BitmapDescriptor.fromAssetImage
      _truckIcon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(80, 80)),
        'assets/icons/truck_icon.png',
      );
      print('Loaded truck icon from asset image');

      if (_currentPosition != null && mounted) {
        setState(() {
          _updateTruckMarker(_currentPosition!);
        });
      }
      return;
    } catch (e) {
      print('Error loading truck icon from asset image: $e');
    }

    // Fallback to default marker
    _truckIcon = BitmapDescriptor.defaultMarkerWithHue(
      BitmapDescriptor.hueBlue,
    );
    print('Using default blue marker as fallback');

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
    LocationPermission permission = await Geolocator.checkPermission();
    setState(() {
      _locationPermissionGranted =
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    });

    if (!_locationPermissionGranted) {
      permission = await Geolocator.requestPermission();
      setState(() {
        _locationPermissionGranted =
            permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse;
      });
    }

    _setupRouteProgressListener();
  }

  void _initializeMapData() {
    final startPoint = LatLng(_route.startLat, _route.startLng);
    final endPoint = LatLng(_route.endLat, _route.endLng);

    print('Start Point: ${_route.startLat}, ${_route.startLng}');

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

    if (_route.isActive) {
      _updateTruckMarker(startPoint);
    }

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
    _positionStreamSubscription?.cancel();

    if (_route.isActive && _locationPermissionGranted) {
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen(
        (Position position) {
          if (mounted) {
            final newPosition = LatLng(position.latitude, position.longitude);

            if (position.latitude == 0.0 && position.longitude == 0.0) {
              print('Ignoring zero coordinates from live position');
              return;
            }

            print(
              'Live position update: ${position.latitude}, ${position.longitude}',
            );

            // Always update the UI with new position
            setState(() {
              _currentPosition = newPosition;
              _updateTruckMarker(newPosition);
            });

            // Check if the position has changed enough to warrant a Firestore update
            // Only filter positions for Firestore updates, always update local UI
            bool shouldUpdateFirestore = true;

            if (_lastReportedPosition != null) {
              final distance = Geolocator.distanceBetween(
                _lastReportedPosition!.latitude,
                _lastReportedPosition!.longitude,
                newPosition.latitude,
                newPosition.longitude,
              );

              // Only update Firestore if moved more than 10 meters or every 15 seconds
              final locationUpdateThreshold = 10.0; // meters
              final timeSinceLastUpdate =
                  _lastLocationUpdateTime != null
                      ? DateTime.now().difference(_lastLocationUpdateTime!)
                      : Duration(seconds: 16);

              if (distance < locationUpdateThreshold &&
                  timeSinceLastUpdate.inSeconds < 15) {
                shouldUpdateFirestore = false;
                print(
                  'Skipping Firestore update (distance: ${distance.toStringAsFixed(1)}m, '
                  'time since last: ${timeSinceLastUpdate.inSeconds}s)',
                );
              }
            }

            // Update Firestore only if needed
            if (shouldUpdateFirestore) {
              _updateRouteProgress(newPosition);
              _lastLocationUpdateTime = DateTime.now();

              print('Updating Firestore with new position');
            }

            // Always update map camera to follow truck
            if (_isMapReady && _mapController != null) {
              _mapController?.animateCamera(
                CameraUpdate.newLatLng(newPosition),
              );
            }
          }
        },
        onError: (e) {
          print('Error getting position updates: $e');

          if (_route.isActive && !_route.isPaused && !_animationActive) {
            _startRouteAnimation();
          }
        },
      );
    } else if (_route.isActive) {
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

  void _updateRouteProgress(LatLng position) {
    if (!_route.isActive || _route.isPaused) return;

    // Validate position data - skip invalid coordinates
    if (position.latitude == 0.0 && position.longitude == 0.0) {
      print('Warning: Ignoring invalid coordinates (0,0) for position update');
      return;
    }

    print(
      'Updating route progress with position: ${position.latitude}, ${position.longitude}',
    );

    double minDistance = double.infinity;
    int closestPointIndex = 0;

    for (int i = 0; i < _route.actualDirectionPath.length; i++) {
      final pathPoint = LatLng(
        _route.actualDirectionPath[i]['lat']!,
        _route.actualDirectionPath[i]['lng']!,
      );

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        pathPoint.latitude,
        pathPoint.longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        closestPointIndex = i;
      }
    }

    double completionPercentage =
        (closestPointIndex * 100) / _route.actualDirectionPath.length;
    completionPercentage = min(completionPercentage, 100.0);

    // Create a list of recently covered points
    List<LatLng> recentCoveredPoints = [];
    if (_lastReportedPosition != null) {
      recentCoveredPoints.add(_lastReportedPosition!);
    }
    recentCoveredPoints.add(position);

    // Store this position as the last reported position
    _lastReportedPosition = position;

    print(
      'Sending location update to Firebase with completion: ${completionPercentage.toStringAsFixed(2)}%',
    );

    // Include the route start time for better time estimations
    _routeService.updateRouteProgress(
      _route.id,
      position,
      coveredPoints: recentCoveredPoints,
      completionPercentage: completionPercentage,
      startTime:
          _route.startedAt, // Include route start time for better estimations
    );

    setState(() {
      _route = _route.copyWith(currentProgressPercentage: completionPercentage);
    });
  }

  // Track last reported position and update time for route progress
  LatLng? _lastReportedPosition;
  DateTime? _lastLocationUpdateTime;

  void _updateTruckMarker(LatLng position) {
    if (position.latitude == 0.0 && position.longitude == 0.0) {
      print('Preventing truck marker at zero coordinates');
      position = LatLng(_route.startLat, _route.startLng);
    }

    print(
      'Added truck marker at position: ${position.latitude}, ${position.longitude}',
    );

    double rotation = 0.0;

    if (_currentPathIndex > 0 &&
        _route.actualDirectionPath.length > _currentPathIndex) {
      final previousPoint = LatLng(
        _route.actualDirectionPath[_currentPathIndex - 1]['lat']!,
        _route.actualDirectionPath[_currentPathIndex - 1]['lng']!,
      );

      rotation = _getBearing(previousPoint, position);
    }

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
        zIndex: 2,
      ),
    );
  }

  void _startRouteAnimation() {
    if (_animationTimer != null && _animationTimer!.isActive) {
      _animationTimer!.cancel();
    }

    _currentPathIndex = 0;
    _animationActive = true;

    if (_route.actualDirectionPath.isEmpty) {
      print('Cannot start animation: route path is empty');
      return;
    }

    final initialPosition = LatLng(_route.startLat, _route.startLng);

    _currentPosition = initialPosition;
    _updateTruckMarker(initialPosition);

    _animationTimer = Timer.periodic(const Duration(milliseconds: 300), (
      timer,
    ) {
      if (!_animationActive || !mounted) {
        timer.cancel();
        return;
      }

      _currentPathIndex++;

      if (_currentPathIndex >= _route.actualDirectionPath.length) {
        timer.cancel();
        _animationActive = false;
        return;
      }

      final currentPoint = LatLng(
        _route.actualDirectionPath[_currentPathIndex]['lat']!,
        _route.actualDirectionPath[_currentPathIndex]['lng']!,
      );

      setState(() {
        _currentPosition = currentPoint;
        _updateTruckMarker(currentPoint);

        final progressPercentage =
            (_currentPathIndex * 100) / _route.actualDirectionPath.length;
        _route = _route.copyWith(currentProgressPercentage: progressPercentage);

        _routeService.updateRouteProgress(
          _route.id,
          currentPoint,
          completionPercentage: progressPercentage,
        );
      });

      if (_isMapReady && _mapController != null) {
        _mapController?.animateCamera(CameraUpdate.newLatLng(currentPoint));
      }
    });
  }

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

    final bearingDegrees = bearing * (180 / pi);
    return (bearingDegrees + 360) % 360;
  }

  Future<void> _startRoute() async {
    try {
      if (!_locationPermissionGranted) {
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
        }
      }

      if (_route.completedAt != null) {
        await _routeService.restartCompletedRoute(_route.id);
      } else {
        await _routeService.startRoute(_route.id);
      }

      final startPoint = LatLng(_route.startLat, _route.startLng);

      print(
        'Starting route at: ${startPoint.latitude}, ${startPoint.longitude}',
      );

      setState(() {
        _currentPosition = startPoint;

        _updateTruckMarker(startPoint);

        _route = _route.copyWith(
          isActive: true,
          isPaused: false,
          startedAt: DateTime.now(),
          completedAt: null,
          currentProgressPercentage: 0.0,
        );
      });

      await _routeService.updateRouteProgress(
        _route.id,
        startPoint,
        completionPercentage: 0.0,
      );

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
        } else {
          _setupRouteProgressListener();
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

        _positionStreamSubscription?.cancel();

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
    if (_animationTimer != null && _animationTimer!.isActive) {
      _animationTimer!.cancel();
    }

    _positionStreamSubscription?.cancel();

    _mapController?.dispose();
    super.dispose();
  }

  // Status bar showing the current route status
  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      color: _getStatusColor().withOpacity(0.15),
      child: Row(
        children: [
          Icon(_getStatusIcon(), color: _getStatusColor(), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getStatusText(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _getStatusColor(),
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Info row used in route information section
  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$title: ',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // Map control button
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
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 18),
        onPressed: onPressed,
      ),
    );
  }

  // Action buttons at bottom of screen
  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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

  IconData _getStatusIcon() {
    if (_route.isPaused) return Icons.pause_circle_filled;
    if (_route.completedAt != null) return Icons.check_circle;
    if (_route.cancelledAt != null) return Icons.cancel;
    if (_route.isActive) return Icons.directions_car;
    return Icons.schedule;
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM d, yyyy - h:mm a').format(dateTime);
  }

  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('h:mm a').format(dt);
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
        Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error cancelling route: $e')));
      }
    }
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
                      child: Text(
                        'SETTINGS',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[900],
                          fontWeight: FontWeight.bold,
                        ),
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
}
