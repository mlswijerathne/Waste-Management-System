import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:waste_management/models/routeModel.dart';
import 'package:waste_management/screens/resident_screens/resident_route_details_screen.dart';
import 'package:waste_management/service/route_service.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart' as permission;
import 'package:url_launcher/url_launcher.dart' as url_launcher;

class ResidentActiveRoutesScreen extends StatefulWidget {
  const ResidentActiveRoutesScreen({Key? key}) : super(key: key);

  @override
  State<ResidentActiveRoutesScreen> createState() => _ResidentActiveRoutesScreenState();
}

class _ResidentActiveRoutesScreenState extends State<ResidentActiveRoutesScreen> {
  final RouteService _routeService = RouteService();
  final Completer<GoogleMapController> _controller = Completer();
  final Location _location = Location();
  
  CameraPosition _initialCameraPosition = const CameraPosition(
    target: LatLng(6.9271, 79.8612),
    zoom: 12,
  );
  
  Set<Marker> _markers = {};
  bool _mapLoaded = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _activeRoutes = [];
  Map<String, BitmapDescriptor> _markerIcons = {};
  LatLng? _currentUserLocation;
  bool _locationInitialized = false;
  
  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
    _initializeLocation();
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
          _currentUserLocation = LatLng(locationData.latitude!, locationData.longitude!);
          _updateMapWithUserLocation();
        });
      });
      
    } catch (e) {
      print('Error initializing location: $e');
    }
  }
  
  Future<void> _loadMarkerIcons() async {
    _markerIcons['user'] = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/images/user_location.png',
    );
    
    setState(() {
      _isLoading = false;
    });
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
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _centerOnUserLocation,
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _routeService.getActiveRoutesWithDriverInfo(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }
                
                final activeRoutes = snapshot.data ?? [];
                
                if (activeRoutes.isEmpty) {
                  return const Center(
                    child: Text(
                      'No active waste collection routes at the moment.\nCheck back later!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                }
                
                return Column(
                  children: [
                    // Map showing only user's location
                    Expanded(
                      flex: 2,
                      child: GoogleMap(
                        mapType: MapType.normal,
                        initialCameraPosition: _initialCameraPosition,
                        markers: _markers,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: true,
                        onMapCreated: (GoogleMapController controller) {
                          _controller.complete(controller);
                          setState(() => _mapLoaded = true);
                          _updateMapWithUserLocation();
                        },
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
                              child: Text(
                                'Active Waste Collection Routes',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
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
                                  
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    elevation: 3,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(color: Colors.green.withOpacity(0.5), width: 1),
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
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: Colors.green),
                                                  ),
                                                  child: const Text(
                                                    'ACTIVE',
                                                    style: TextStyle(
                                                      color: Colors.green,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                const Icon(Icons.person, size: 16, color: Colors.grey),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'Driver: ${route.driverName ?? 'Not assigned'}',
                                                    style: TextStyle(
                                                      color: Colors.grey[700],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                const Icon(Icons.local_shipping, size: 16, color: Colors.grey),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Truck ID: ${route.truckId ?? 'N/A'}',
                                                  style: TextStyle(
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            const Text(
                                              'Route Progress:',
                                              style: TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 8),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: completionPercentage / 100,
                                                backgroundColor: Colors.grey[300],
                                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                                                minHeight: 8,
                                              ),
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
                                                    foregroundColor: Colors.green,
                                                    side: const BorderSide(color: Colors.green),
                                                  ),
                                                ),
                                                ElevatedButton.icon(
                                                  onPressed: () => _navigateToRouteDetails(route),
                                                  icon: const Icon(Icons.arrow_forward, size: 16),
                                                  label: const Text('View Details'),
                                                  style: ElevatedButton.styleFrom(
                                                    foregroundColor: Colors.white,
                                                    backgroundColor: Colors.green,
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
}