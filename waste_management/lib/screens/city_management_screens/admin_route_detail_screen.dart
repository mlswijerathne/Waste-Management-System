import 'package:flutter/material.dart';
import 'package:waste_management/models/routeModel.dart';
import 'package:waste_management/service/route_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

class RouteDetailScreen extends StatefulWidget {
  final String routeId;

  const RouteDetailScreen({Key? key, required this.routeId}) : super(key: key);

  @override
  _RouteDetailScreenState createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  final RouteService _routeService = RouteService();
  RouteModel? _route;
  bool _isLoading = true;
  String? _errorMessage;
  GoogleMapController? _mapController;
  bool _isMapReady = false;
  Map<String, dynamic>? _timeEstimation;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  List<Map<String, dynamic>> _routeHistory = [];

  @override
  void initState() {
    super.initState();
    _loadRouteDetails();
  }

  Future<void> _loadRouteDetails() async {
    try {
      final route = await _routeService.getRoute(widget.routeId);
      if (route == null) {
        throw Exception('Route not found');
      }

      final timeEstimation = await _routeService.getRouteTimeEstimation(widget.routeId);
      await _prepareMapData(route);

      setState(() {
        _route = route;
        _timeEstimation = timeEstimation;
        _isLoading = false;
      });
      
      _routeService.getRouteHistory(widget.routeId).listen((historyData) {
        setState(() {
          _routeHistory = historyData;
        });
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _prepareMapData(RouteModel route) async {
    // Clear existing markers and polylines
    _markers = {};
    _polylines = {};

    // Add start marker
    _markers.add(
      Marker(
        markerId: const MarkerId('start'),
        position: LatLng(route.startLat, route.startLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Start Point'),
      ),
    );

    // Add end marker
    _markers.add(
      Marker(
        markerId: const MarkerId('end'),
        position: LatLng(route.endLat, route.endLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'End Point'),
      ),
    );

    // Add current position marker if route is active
    if (route.isActive) {
      final currentPosition = await _routeService.getRouteProgress(widget.routeId).first;
      if (currentPosition != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('current'),
            position: currentPosition,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: const InfoWindow(title: 'Current Position'),
          ),
        );
      }
    }

    // Add polyline for the route
    if (route.actualDirectionPath.isNotEmpty) {
      List<LatLng> polylinePoints = route.actualDirectionPath
          .map((point) => LatLng(point['lat'] ?? 0.0, point['lng'] ?? 0.0))
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
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _isMapReady = true;
    _fitMapToRoute();
  }

  void _fitMapToRoute() {
    if (_mapController != null && _route != null && _route!.actualDirectionPath.isNotEmpty) {
      // Get all points
      List<LatLng> points = _route!.actualDirectionPath
          .map((point) => LatLng(point['lat'] ?? 0.0, point['lng'] ?? 0.0))
          .toList();

      // Find bounds
      double minLat = double.infinity;
      double maxLat = -double.infinity;
      double minLng = double.infinity;
      double maxLng = -double.infinity;

      for (var point in points) {
        minLat = point.latitude < minLat ? point.latitude : minLat;
        maxLat = point.latitude > maxLat ? point.latitude : maxLat;
        minLng = point.longitude < minLng ? point.longitude : minLng;
        maxLng = point.longitude > maxLng ? point.longitude : maxLng;
      }

      // Create bounds with padding
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(minLat - 0.01, minLng - 0.01),
        northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
      );

      // Animate camera to bounds
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_route?.name ?? 'Route Details'),
        actions: [
          if (_route != null)
            PopupMenuButton<String>(
              onSelected: (value) => _handleMenuAction(value),
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: Text('Edit Route'),
                ),
                const PopupMenuItem<String>(
                  value: 'assign',
                  child: Text('Assign Driver'),
                ),
                if (_route!.isActive)
                  const PopupMenuItem<String>(
                    value: 'cancel',
                    child: Text('Cancel Route'),
                  ),
                if (_route!.completedAt != null)
                  const PopupMenuItem<String>(
                    value: 'restart',
                    child: Text('Restart Route'),
                  ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('Delete Route', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage'))
              : _buildRouteDetailsContent(),
    );
  }

  Widget _buildRouteDetailsContent() {
    if (_route == null) {
      return const Center(child: Text('Route not found'));
    }

    final dateFormat = DateFormat('MMM dd, yyyy - hh:mm a');

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Map Section
          SizedBox(
            height: 300,
            child: _buildMap(),
          ),
          
          // Route Details Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusSection(),
                const SizedBox(height: 16),

                // Basic Route Information
                _buildInfoSection(
                  title: 'Route Information',
                  content: [
                    _buildInfoRow('Name', _route!.name),
                    _buildInfoRow('Description', _route!.description),
                    _buildInfoRow('Distance', '${_route!.distance.toStringAsFixed(1)} km'),
                    _buildInfoRow('Created', dateFormat.format(_route!.createdAt)),
                  ],
                ),
                const SizedBox(height: 16),

                // Driver Assignment Section
                if (_route!.assignedDriverId != null) ...[
                  _buildInfoSection(
                    title: 'Driver Assignment',
                    content: [
                      _buildInfoRow('Driver', _route!.driverName ?? 'Not specified'),
                      _buildInfoRow('Contact', _route!.driverContact ?? 'Not specified'),
                      _buildInfoRow('Truck ID', _route!.truckId ?? 'Not specified'),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Time Estimation Section
                if (_timeEstimation != null && _route!.isActive) ...[
                  _buildInfoSection(
                    title: 'Time Estimation',
                    content: [
                      _buildInfoRow('Total Time', 
                        '${(_timeEstimation!['totalEstimatedTimeMinutes'] / 60).toStringAsFixed(1)} hours'),
                      _buildInfoRow('Remaining Time', 
                        '${(_timeEstimation!['remainingTimeMinutes'] / 60).toStringAsFixed(1)} hours'),
                      _buildInfoRow('Completion',
                        '${_timeEstimation!['completionPercentage'].toStringAsFixed(1)}%'),
                      if (_timeEstimation!['estimatedCompletionTime'] != null)
                        _buildInfoRow('Expected Completion', 
                          dateFormat.format(_timeEstimation!['estimatedCompletionTime'])),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Route History Section
                if (_routeHistory.isNotEmpty) ...[
                  _buildHistorySection(),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    if (_route == null) {
      return const Center(child: Text('No route data available'));
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(_route!.startLat, _route!.startLng),
        zoom: 13.0,
      ),
      markers: _markers,
      polylines: _polylines,
      onMapCreated: _onMapCreated,
      mapType: MapType.normal,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: true,
      compassEnabled: true,
    );
  }

  Widget _buildStatusSection() {
    Color statusColor = Colors.grey;
    String statusText = 'Inactive';
    IconData statusIcon = Icons.circle;
    
    if (_route!.isCancelled) {
      statusColor = Colors.red;
      statusText = 'Cancelled';
      statusIcon = Icons.cancel;
    } else if (_route!.completedAt != null) {
      statusColor = Colors.green;
      statusText = 'Completed';
      statusIcon = Icons.check_circle;
    } else if (_route!.isActive) {
      if (_route!.isPaused) {
        statusColor = Colors.amber;
        statusText = 'Paused';
        statusIcon = Icons.pause_circle;
      } else {
        statusColor = Colors.blue;
        statusText = 'Active';
        statusIcon = Icons.directions_car;
      }
    } else if (_route!.assignedDriverId != null) {
      statusColor = Colors.purple;
      statusText = 'Assigned';
      statusIcon = Icons.person;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor),
          const SizedBox(width: 8),
          Text(
            'Status: $statusText',
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_route!.isActive && _route!.currentProgressPercentage != null) ...[
            const Spacer(),
            Text(
              '${_route!.currentProgressPercentage!.toStringAsFixed(1)}%',
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoSection({required String title, required List<Widget> content}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            ...content,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHistorySection() {
    final dateFormat = DateFormat('MMM dd, yyyy - hh:mm a');
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Route History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _routeHistory.length,
              itemBuilder: (context, index) {
                final history = _routeHistory[index];
                
                IconData actionIcon;
                Color actionColor;
                String actionText;
                
                switch (history['action']) {
                  case 'start':
                    actionIcon = Icons.play_arrow;
                    actionColor = Colors.green;
                    actionText = 'Route Started';
                    break;
                  case 'pause':
                    actionIcon = Icons.pause;
                    actionColor = Colors.amber;
                    actionText = 'Route Paused';
                    break;
                  case 'resume':
                    actionIcon = Icons.play_arrow;
                    actionColor = Colors.blue;
                    actionText = 'Route Resumed';
                    break;
                  case 'complete':
                    actionIcon = Icons.check_circle;
                    actionColor = Colors.green;
                    actionText = 'Route Completed';
                    break;
                  case 'cancel':
                    actionIcon = Icons.cancel;
                    actionColor = Colors.red;
                    actionText = 'Route Cancelled';
                    break;
                  case 'assign_driver':
                    actionIcon = Icons.person;
                    actionColor = Colors.purple;
                    actionText = 'Driver Assigned: ${history['driverName'] ?? 'Unknown'}';
                    break;
                  default:
                    actionIcon = Icons.info;
                    actionColor = Colors.grey;
                    actionText = 'Unknown Action';
                }
                
                return ListTile(
                  leading: Icon(actionIcon, color: actionColor),
                  title: Text(actionText),
                  subtitle: history['timestamp'] != null
                    ? Text(dateFormat.format(history['timestamp']))
                    : null,
                  dense: true,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleMenuAction(String action) async {
    try {
      switch (action) {
        case 'edit':
          // Navigate to edit route screen
          break;
        case 'assign':
          // Navigate to assign driver screen
          break;
        case 'cancel':
          _confirmCancelRoute();
          break;
        case 'restart':
          _confirmRestartRoute();
          break;
        case 'delete':
          _confirmDeleteRoute();
          break;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _confirmRestartRoute() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Restart Route'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to restart this completed route?'),
                Text('The progress will be reset to 0%.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Restart'),
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await _routeService.restartCompletedRoute(_route!.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Route restarted successfully')),
                  );
                  _loadRouteDetails(); // Reload route details
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmCancelRoute() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Route'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to cancel this route?'),
                Text('This action cannot be undone.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Yes, Cancel Route'),
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await _routeService.cancelRoute(_route!.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Route cancelled successfully')),
                  );
                  _loadRouteDetails(); // Reload route details
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteRoute() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Route'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to delete this route?'),
                Text('This action cannot be undone.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Yes, Delete'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await _routeService.deleteRoute(_route!.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Route deleted successfully')),
                  );
                  Navigator.of(context).pop(); // Return to routes list
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}