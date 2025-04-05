import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:waste_management/models/routeModel.dart';
import 'package:waste_management/service/route_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

class RouteDetailsScreen extends StatefulWidget {
  final String routeId;
  
  const RouteDetailsScreen({
    Key? key,
    required this.routeId,
  }) : super(key: key);

  @override
  State<RouteDetailsScreen> createState() => _RouteDetailsScreenState();
}

class _RouteDetailsScreenState extends State<RouteDetailsScreen> {
  final RouteService _routeService = RouteService();
  final Completer<GoogleMapController> _controller = Completer();
  
  late CameraPosition _initialCameraPosition;
  RouteModel? _route;
  LatLng? _currentTruckPosition;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  double _completionPercentage = 0.0;
  BitmapDescriptor? _truckIcon;
  Map<String, dynamic>? _timeEstimation;
  bool _isLoading = true;
  Timer? _refreshTimer;
  StreamSubscription? _progressSubscription;
  
  @override
  void initState() {
    super.initState();
    _loadTruckIcon();
    _initialCameraPosition = const CameraPosition(
      target: LatLng(6.9271, 79.8612),
      zoom: 12,
    );
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    _progressSubscription?.cancel();
    super.dispose();
  }
  
  Future<void> _loadTruckIcon() async {
    _truckIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/images/truck_icon.png',
    );
    _loadRouteData();
  }
  
  Future<void> _loadRouteData() async {
    try {
      final route = await _routeService.getRoute(widget.routeId);
      if (route == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Route not found')),
        );
        Navigator.pop(context);
        return;
      }
      
      final timeEstimation = await _routeService.getRouteTimeEstimation(widget.routeId);
      
      _progressSubscription = _routeService.getRouteProgress(widget.routeId).listen((position) {
        if (position != null && mounted) {
          setState(() {
            _currentTruckPosition = position;
            _updateMarkers();
          });
          
          _controller.future.then((controller) {
            controller.animateCamera(CameraUpdate.newLatLng(position));
          });
        }
      });
      
      List<LatLng> routePath = [];
      if (route.actualDirectionPath.isNotEmpty) {
        routePath = route.actualDirectionPath
            .map((point) => LatLng(point['lat']!, point['lng']!))
            .toList();
      } else if (route.coveragePoints.isNotEmpty) {
        routePath = route.coveragePoints
            .map((point) => LatLng(point['lat']!, point['lng']!))
            .toList();
      }
      
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route_path'),
          points: routePath,
          color: Colors.blue,
          width: 5,
        ),
      );
      
      _markers.add(
        Marker(
          markerId: const MarkerId('start'),
          position: LatLng(route.startLat, route.startLng),
          infoWindow: const InfoWindow(title: 'Start Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
      
      _markers.add(
        Marker(
          markerId: const MarkerId('end'),
          position: LatLng(route.endLat, route.endLng),
          infoWindow: const InfoWindow(title: 'End Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
      
      if (routePath.isNotEmpty) {
        _initialCameraPosition = CameraPosition(
          target: routePath[0],
          zoom: 13,
        );
      }
      
      _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
        if (mounted) {
          final newEstimation = await _routeService.getRouteTimeEstimation(widget.routeId);
          setState(() {
            _timeEstimation = newEstimation;
            _completionPercentage = newEstimation['completionPercentage'];
          });
        }
      });
      
      setState(() {
        _route = route;
        _timeEstimation = timeEstimation;
        _completionPercentage = timeEstimation['completionPercentage'];
        _isLoading = false;
      });
      
    } catch (e) {
      print('Error loading route data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _updateMarkers() {
    if (_currentTruckPosition != null && _truckIcon != null) {
      _markers.removeWhere((marker) => marker.markerId.value == 'truck');
      
      _markers.add(
        Marker(
          markerId: const MarkerId('truck'),
          position: _currentTruckPosition!,
          icon: _truckIcon!,
          infoWindow: InfoWindow(
            title: 'Collection Truck',
            snippet: _route?.driverName ?? 'Driver information unavailable',
          ),
        ),
      );
    }
  }
  
  void _contactDriver() async {
    if (_route?.driverContact == null || _route!.driverContact!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver contact information not available')),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Driver'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone),
              title: const Text('Call'),
              onTap: () async {
                Navigator.pop(context);
                final url = 'tel:${_route!.driverContact}';
                if (await url_launcher.canLaunchUrl(Uri.parse(url))) {
                  await url_launcher.launchUrl(Uri.parse(url));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.message),
              title: const Text('Send SMS'),
              onTap: () async {
                Navigator.pop(context);
                final url = 'sms:${_route!.driverContact}';
                if (await url_launcher.canLaunchUrl(Uri.parse(url))) {
                  await url_launcher.launchUrl(Uri.parse(url));
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_route?.name ?? 'Route Details'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  flex: 3,
                  child: GoogleMap(
                    mapType: MapType.normal,
                    initialCameraPosition: _initialCameraPosition,
                    markers: _markers,
                    polylines: _polylines,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: true,
                    onMapCreated: (GoogleMapController controller) {
                      _controller.complete(controller);
                    },
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Route Progress',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: _completionPercentage / 100,
                            backgroundColor: Colors.grey[300],
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                            minHeight: 10,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_completionPercentage.toStringAsFixed(1)}% complete',
                            style: const TextStyle(fontSize: 16),
                          ),
                          
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          
                          if (_timeEstimation != null) ...[
                            const Text(
                              'Estimated Completion Time',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.access_time, color: Colors.green),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('HH:mm').format(_timeEstimation!['estimatedCompletionTime']),
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '(${(_timeEstimation!['remainingTimeMinutes'] as double).toInt()} minutes remaining)',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                          
                          Card(
                            elevation: 3,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Driver Information',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildInfoRow('Name:', _route?.driverName ?? 'Not assigned'),
                                  const SizedBox(height: 4),
                                  _buildInfoRow('Truck ID:', _route?.truckId ?? 'N/A'),
                                  const SizedBox(height: 4),
                                  _buildInfoRow('Contact:', _route?.driverContact ?? 'N/A'),
                                  const SizedBox(height: 8),
                                  if (_route?.driverContact != null && _route!.driverContact!.isNotEmpty)
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: _contactDriver,
                                        icon: const Icon(Icons.phone),
                                        label: const Text('Contact Driver'),
                                        style: ElevatedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          backgroundColor: Colors.green,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          Card(
                            elevation: 3,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Route Details',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildInfoRow('Distance:', '${_route?.distance.toStringAsFixed(2)} km'),
                                  const SizedBox(height: 4),
                                  _buildInfoRow('Started:', _route?.startedAt != null 
                                    ? DateFormat('dd/MM/yyyy HH:mm').format(_route!.startedAt!)
                                    : 'Not started'),
                                  if (_route?.isPaused == true) ...[
                                    const SizedBox(height: 4),
                                    _buildInfoRow(
                                      'Status:',
                                      'PAUSED',
                                      valueStyle: const TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
  
  Widget _buildInfoRow(String label, String value, {TextStyle? valueStyle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: valueStyle ?? const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }
}