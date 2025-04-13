import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:waste_management/models/routeModel.dart';
import 'package:waste_management/service/route_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:flutter/animation.dart';

class RouteDetailsScreen extends StatefulWidget {
  final String routeId;

  const RouteDetailsScreen({Key? key, required this.routeId}) : super(key: key);

  @override
  State<RouteDetailsScreen> createState() => _RouteDetailsScreenState();
}

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

class _RouteDetailsScreenState extends State<RouteDetailsScreen> with TickerProviderStateMixin {
  final RouteService _routeService = RouteService();
  final Completer<GoogleMapController> _controller = Completer();
  bool _mapCreated = false;

  CameraPosition _initialCameraPosition = const CameraPosition(
    target: LatLng(6.9271, 79.8612), // Default coordinates for Colombo, Sri Lanka
    zoom: 12,
  );

  RouteModel? _route;
  LatLng? _currentTruckPosition;
  LatLng? _lastTruckPosition;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  double _completionPercentage = 0.0;
  Map<String, dynamic>? _timeEstimation;
  bool _isLoading = true;
  Timer? _refreshTimer;
  StreamSubscription? _progressSubscription;
  AnimationController? _animationController;
  Animation<LatLng>? _truckAnimation;

  // Define primary color to match other screens
  final Color primaryColor = const Color(0xFF59A867);

  @override
  void initState() {
    super.initState();
    _loadRouteData();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _progressSubscription?.cancel();
    _animationController?.dispose();
    super.dispose();
  }

  Future<void> _loadRouteData() async {
    try {
      final route = await _routeService.getRoute(widget.routeId);
      if (route == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Route not found')),
          );
          Navigator.pop(context);
        }
        return;
      }

      final timeEstimation = await _routeService.getRouteTimeEstimation(widget.routeId);

      _progressSubscription = _routeService.getRouteProgress(widget.routeId).listen((position) {
        if (position != null && mounted) {
          setState(() {
            _currentTruckPosition = position;
          });
          _animateTruckMarker(position);
          _controller.future.then((controller) {
            controller.animateCamera(CameraUpdate.newLatLng(position));
          }).catchError((error) {
            print('Error moving camera: $error');
          });
        }
      });

      List<LatLng> routePath = [];
      
      // Safely handle the route path conversion
      if (route.actualDirectionPath != null && route.actualDirectionPath.isNotEmpty) {
        routePath = route.actualDirectionPath.map((point) {
          double? lat = point['lat'] is double ? point['lat'] : 0.0;
          double? lng = point['lng'] is double ? point['lng'] : 0.0;
          return LatLng(lat!, lng!);
        }).toList();
      }

      if (routePath.isNotEmpty) {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route_path'),
            points: routePath,
            color: primaryColor,
            width: 5,
          )
        };

        _initialCameraPosition = CameraPosition(
          target: routePath[0],
          zoom: 13,
        );
      }

      Set<Marker> newMarkers = {};
      
      // Add start marker
      newMarkers.add(
        Marker(
          markerId: const MarkerId('start'),
          position: LatLng(route.startLat, route.startLng),
          infoWindow: const InfoWindow(title: 'Start'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        )
      );
      
      // Add end marker
      newMarkers.add(
        Marker(
          markerId: const MarkerId('end'),
          position: LatLng(route.endLat, route.endLng),
          infoWindow: const InfoWindow(title: 'End'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        )
      );

      if (mounted) {
        setState(() {
          _route = route;
          _timeEstimation = timeEstimation;
          _completionPercentage = timeEstimation['completionPercentage'] ?? 0.0;
          _markers = newMarkers;
          _isLoading = false;
        });

        // If the map is created, update the camera position
        if (_mapCreated) {
          _controller.future.then((controller) {
            controller.animateCamera(CameraUpdate.newCameraPosition(_initialCameraPosition));
          }).catchError((error) {
            print('Error moving camera: $error');
          });
        }
      }

      _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
        final newEstimation = await _routeService.getRouteTimeEstimation(widget.routeId);
        if (mounted) {
          setState(() {
            _timeEstimation = newEstimation;
            _completionPercentage = newEstimation['completionPercentage'] ?? 0.0;
          });
        }
      });
    } catch (e) {
      print('Error loading route data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  void _animateTruckMarker(LatLng newPosition) {
    if (_lastTruckPosition == null) {
      setState(() {
        _markers = Set.from(_markers)..add(
          Marker(
            markerId: const MarkerId('truck'),
            position: newPosition,
            infoWindow: const InfoWindow(title: 'Truck'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          ),
        );
      });
      _lastTruckPosition = newPosition;
      return;
    }

    _animationController?.dispose();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _truckAnimation = _LatLngTween(
      begin: _lastTruckPosition!,
      end: newPosition,
    ).animate(CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeInOut,
    ))
      ..addListener(() {
        _updateTruckMarker(_truckAnimation!.value);
      });

    _animationController!.forward();
    _lastTruckPosition = newPosition;
  }

  void _updateTruckMarker(LatLng position) {
    if (mounted) {
      setState(() {
        _markers = Set.from(_markers.where((m) => m.markerId.value != 'truck'))..add(
          Marker(
            markerId: const MarkerId('truck'),
            position: position,
            infoWindow: const InfoWindow(title: 'Truck'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          ),
        );
      });
    }
  }

  void _contactDriver() async {
    final contact = _route?.driverContact;
    if (contact == null || contact.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Driver contact unavailable')));
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

  String _getScheduleFrequencyText() {
    if (_route == null) return 'N/A';
    
    switch(_route!.scheduleFrequency.toLowerCase()) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      default:
        return _route!.scheduleFrequency;
    }
  }

  String _getScheduleDaysText() {
    if (_route == null || _route!.scheduleDays.isEmpty) return 'N/A';
    
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return _route!.scheduleDays.map((dayIndex) => days[dayIndex]).join(', ');
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
        title: Text(_route?.name ?? 'Route Details'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : Column(
              children: [
                // Map section
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      GoogleMap(
                        mapType: MapType.normal,
                        initialCameraPosition: _initialCameraPosition,
                        markers: _markers,
                        polylines: _polylines,
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
                    ],
                  ),
                ),
                
                // Details section
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
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Route name and status
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  _route?.name ?? 'Route Details',
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
                                    value: _completionPercentage / 100,
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
                                        '${_completionPercentage.toStringAsFixed(1)}% complete',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      
                                      if (_timeEstimation != null)
                                        Row(
                                          children: [
                                            const Icon(Icons.access_time, 
                                              color: Colors.grey, 
                                              size: 20,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'ETA: ${DateFormat('HH:mm').format(
                                                _timeEstimation!['estimatedCompletionTime'] is DateTime 
                                                    ? _timeEstimation!['estimatedCompletionTime'] 
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
                                  
                                  if (_timeEstimation != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      '${(_timeEstimation!['remainingTimeMinutes'] as num).toInt()} minutes remaining',
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
                                    _route?.driverName ?? 'Not assigned',
                                  ),
                                  
                                  const Divider(height: 24),
                                  
                                  _buildInfoRow(
                                    Icons.local_shipping,
                                    'Truck ID:',
                                    _route?.truckId ?? 'N/A',
                                  ),
                                  
                                  const Divider(height: 24),
                                  
                                  _buildInfoRow(
                                    Icons.phone,
                                    'Contact:',
                                    _route?.driverContact ?? 'N/A',
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  
                                  if (_route?.driverContact != null && _route!.driverContact!.isNotEmpty)
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
                          
                          // Route schedule details
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
                                  
                                  // Waste category
                                  _buildInfoRow(
                                    Icons.delete,
                                    'Waste Type:',
                                    _route?.wasteCategory.toUpperCase() ?? 'N/A',
                                  ),
                                  
                                  const Divider(height: 24),
                                  
                                  // Distance
                                  _buildInfoRow(
                                    Icons.route,
                                    'Distance:',
                                    '${_route?.distance.toStringAsFixed(1) ?? 'N/A'} km',
                                  ),
                                  
                                  const Divider(height: 24),
                                  
                                  // Schedule frequency
                                  _buildInfoRow(
                                    Icons.calendar_today,
                                    'Frequency:',
                                    _getScheduleFrequencyText(),
                                  ),
                                  
                                  const Divider(height: 24),
                                  
                                  // Schedule days
                                  _buildInfoRow(
                                    Icons.today,
                                    'Days:',
                                    _getScheduleDaysText(),
                                  ),
                                  
                                  const Divider(height: 24),
                                  
                                  // Schedule time
                                  _buildInfoRow(
                                    Icons.access_time,
                                    'Time:',
                                    '${_formatTimeOfDay(_route?.scheduleStartTime)} - ${_formatTimeOfDay(_route?.scheduleEndTime)}',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
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
}