import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:waste_management/models/routeModel.dart';
import 'package:waste_management/service/route_service.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart'; // Add this import

class DriverRouteDetailScreen extends StatefulWidget {
  final RouteModel route;

  const DriverRouteDetailScreen({Key? key, required this.route}) : super(key: key);

  @override
  _DriverRouteDetailScreenState createState() => _DriverRouteDetailScreenState();
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

  @override
  void initState() {
    super.initState();
    _route = widget.route;
    _checkLocationPermission();
    _initializeMapData();
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

    // Add route polyline if available
    if (_route.actualDirectionPath.isNotEmpty) {
      final polylinePoints = _route.actualDirectionPath
          .map((point) => LatLng(point['lat']!, point['lng']!))
          .toList();

      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: polylinePoints,
          color: Colors.blue,
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
          setState(() {
            _currentPosition = position;
            // Update or add current position marker
            _markers.removeWhere((marker) => marker.markerId.value == 'current');
            _markers.add(
              Marker(
                markerId: const MarkerId('current'),
                position: position,
                infoWindow: const InfoWindow(title: 'Your Location'),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
              ),
            );
          });

          // Move camera to follow the current position only if map is ready
          if (_isMapReady && _mapController != null) {
            _mapController?.animateCamera(
              CameraUpdate.newLatLng(position),
            );
          }
        }
      });
    }
  }

  Future<void> _startRoute() async {
    try {
      if (!_locationPermissionGranted) {
        // Show alert asking for location permission
        bool shouldRequest = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Location Permission Required'),
            content: const Text('This app needs location permission to track your route progress.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
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
          return;
        }
      }

      if (_route.completedAt != null) {
        await _routeService.restartCompletedRoute(_route.id);
      } else {
        await _routeService.startRoute(_route.id);
      }

      setState(() {
        _route = _route.copyWith(
          isActive: true,
          isPaused: false,
          startedAt: DateTime.now(),
          completedAt: null,
          currentProgressPercentage: 0.0,
        );
      });

      // Only move the camera if the map is ready
      if (_isMapReady && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(
            LatLng(_route.startLat, _route.startLng),
          ),
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_route.completedAt != null 
          ? 'Route restarted successfully' 
          : 'Route started successfully')),
      );

      _setupRouteProgressListener();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting route: $e')),
      );
    }
  }

  Future<void> _pauseRoute() async {
    try {
      await _routeService.pauseRoute(_route.id);
      setState(() {
        _route = _route.copyWith(
          isPaused: true,
          pausedAt: DateTime.now(),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Route paused')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error pausing route: $e')),
      );
    }
  }

  Future<void> _resumeRoute() async {
    try {
      await _routeService.resumeRoute(_route.id);
      setState(() {
        _route = _route.copyWith(
          isPaused: false,
          resumedAt: DateTime.now(),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Route resumed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error resuming route: $e')),
      );
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error completing route: $e')),
      );
    }
  }

  Future<void> _cancelRoute() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Route cancelled')),
        );
        Navigator.pop(context, true); // Return true to indicate route cancellation
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cancelling route: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_route.name),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              onMapCreated: (controller) {
                _mapController = controller;
                // Set a flag to indicate that the map is ready
                setState(() {
                  _isMapReady = true;
                });
                
                // If the route is active, move to the starting position
                if (_route.isActive && _currentPosition != null) {
                  controller.animateCamera(
                    CameraUpdate.newLatLng(_currentPosition!),
                  );
                } else {
                  controller.animateCamera(
                    CameraUpdate.newLatLng(LatLng(_route.startLat, _route.startLng)),
                  );
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
              zoomControlsEnabled: true,
            ),
          ),
          _buildRouteInfoSection(),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildRouteInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _route.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getStatusText(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.route, size: 16),
              const SizedBox(width: 4),
              Text('Distance: ${_route.distance.toStringAsFixed(1)} km'),
              const Spacer(),
              const Icon(Icons.access_time, size: 16),
              const SizedBox(width: 4),
              Text(_formatDateTime(_route.startedAt ?? _route.createdAt)),
            ],
          ),
          const SizedBox(height: 8),
          if (_route.isActive) ...[
            Row(
              children: [
                const Icon(Icons.trending_up, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Progress: ${_route.currentProgressPercentage?.toStringAsFixed(1) ?? '0.0'}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (_route.currentProgressPercentage ?? 0.0) / 100,
              backgroundColor: Colors.grey[200],
              color: Colors.green,
            ),
          ],
          if (!_locationPermissionGranted) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.yellow[100],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: const Text(
                      'Location permission is required to track your position during the route.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await openAppSettings();
                    },
                    child: const Text('SETTINGS'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.grey[100],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (!_route.isActive && !_route.isCancelled)
            _buildActionButton(
              icon: _route.completedAt != null ? Icons.refresh : Icons.play_arrow,
              label: _route.completedAt != null ? 'Restart' : 'Start',
              color: Colors.green,
              onPressed: (_isMapReady) ? _startRoute : null,
            ),
          if (_route.isActive && !_route.isPaused)
            _buildActionButton(
              icon: Icons.pause,
              label: 'Pause',
              color: Colors.orange,
              onPressed: _pauseRoute,
            ),
          if (_route.isActive && _route.isPaused)
            _buildActionButton(
              icon: Icons.play_arrow,
              label: 'Resume',
              color: Colors.green,
              onPressed: _resumeRoute,
            ),
          if (_route.isActive)
            _buildActionButton(
              icon: Icons.check,
              label: 'Complete',
              color: Colors.blue,
              onPressed: _completeRoute,
            ),
          if (!_route.isCancelled && _route.completedAt == null)
            _buildActionButton(
              icon: Icons.cancel,
              label: 'Cancel',
              color: Colors.red,
              onPressed: _cancelRoute,
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        disabledBackgroundColor: Colors.grey,
      ),
    );
  }

  String _getStatusText() {
    if (_route.isPaused) return 'Paused';
    if (_route.completedAt != null) return 'Completed';
    if (_route.cancelledAt != null) return 'Cancelled';
    if (_route.isActive) return 'Active';
    return 'Not Started';
  }

  Color _getStatusColor() {
    if (_route.isPaused) return Colors.orange;
    if (_route.completedAt != null) return Colors.grey;
    if (_route.cancelledAt != null) return Colors.red;
    if (_route.isActive) return Colors.green;
    return Colors.blue;
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM d, HH:mm').format(dateTime);
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}