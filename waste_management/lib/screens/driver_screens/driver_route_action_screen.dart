import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:waste_management/models/routeModel.dart';
import 'package:waste_management/service/route_service.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

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
        title: Text(
          _route.name,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green[700],
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildStatusBar(),
          Expanded(
            flex: 5,
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
          Expanded(
            flex: 4,
            child: _buildRouteInfoSection(),
          ),
        ],
      ),
      bottomNavigationBar: _buildActionButtons(),
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
          Icon(
            _getStatusIcon(),
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            _getStatusText().toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
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
    Color categoryColor = _route.wasteCategory == 'organic' ? Colors.brown : Colors.blue;
    String categoryText = _route.wasteCategory == 'organic' ? 'ORGANIC WASTE' : 'INORGANIC WASTE';
    
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _route.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            // Waste category badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: categoryColor),
              ),
              child: Text(
                categoryText,
                style: TextStyle(
                  color: categoryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.route, 'Distance', '${_route.distance.toStringAsFixed(1)} km'),
            _buildInfoRow(
              Icons.access_time, 
              'Schedule', 
              '${_formatTime(_route.scheduleStartTime)} - ${_formatTime(_route.scheduleEndTime)}'
            ),
            _buildInfoRow(
              Icons.calendar_today, 
              'Start Date', 
              _formatDateTime(_route.startedAt ?? _route.createdAt)
            ),
            const SizedBox(height: 16),
            if (_route.isActive) ...[
              Row(
                children: [
                  const Icon(Icons.trending_up, size: 22, color: Colors.green),
                  const SizedBox(width: 10),
                  Text(
                    'Progress: ${_route.currentProgressPercentage?.toStringAsFixed(1) ?? '0.0'}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (_route.currentProgressPercentage ?? 0.0) / 100,
                  backgroundColor: Colors.grey[200],
                  color: Colors.green,
                  minHeight: 15,
                ),
              ),
            ],
            if (!_locationPermissionGranted) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.yellow[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Location Permission Required',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Your location is needed to track route progress.',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () async {
                              await openAppSettings();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: const Text('ENABLE LOCATION'),
                          ),
                        ],
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Colors.grey[700]),
          const SizedBox(width: 10),
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[800],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (!_route.isActive && !_route.isCancelled)
            _buildActionButton(
              icon: _route.completedAt != null ? Icons.refresh : Icons.play_arrow,
              label: _route.completedAt != null ? 'RESTART' : 'START',
              color: Colors.green[700]!,
              onPressed: (_isMapReady) ? _startRoute : null,
              size: 1,
            ),
          if (_route.isActive && !_route.isPaused)
            _buildActionButton(
              icon: Icons.pause,
              label: 'PAUSE',
              color: Colors.orange[700]!,
              onPressed: _pauseRoute,
              size: 1,
            ),
          if (_route.isActive && _route.isPaused)
            _buildActionButton(
              icon: Icons.play_arrow,
              label: 'RESUME',
              color: Colors.green[700]!,
              onPressed: _resumeRoute,
              size: 1,
            ),
          if (_route.isActive)
            _buildActionButton(
              icon: Icons.check_circle,
              label: 'COMPLETE',
              color: Colors.blue[700]!,
              onPressed: _completeRoute,
              size: 1,
            ),
          if (!_route.isCancelled && _route.completedAt == null)
            _buildActionButton(
              icon: Icons.cancel,
              label: 'CANCEL',
              color: Colors.red[700]!,
              onPressed: _cancelRoute,
              size: _route.isActive ? 1 : 1,
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
    required int size,
  }) {
    return Expanded(
      flex: size,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 24),
          label: Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            disabledBackgroundColor: Colors.grey,
          ),
        ),
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
    if (_route.isActive) return Colors.green[700]!;
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

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}