import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:waste_management/models/userModel.dart';
import 'package:waste_management/service/auth_service.dart';

class ResidentLocationPickerScreen extends StatefulWidget {
  final Function(double latitude, double longitude)? onLocationSelected;

  const ResidentLocationPickerScreen({Key? key, this.onLocationSelected})
    : super(key: key);

  @override
  State<ResidentLocationPickerScreen> createState() =>
      _ResidentLocationPickerScreenState();
}

class _ResidentLocationPickerScreenState
    extends State<ResidentLocationPickerScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService(); // Use AuthService

  // Default location (Sri Lanka center)
  static const LatLng _defaultLocation = LatLng(7.8731, 80.7718);

  LatLng _currentLocation = _defaultLocation;
  LatLng _selectedLocation = _defaultLocation;
  bool _isLoading = true;
  String _errorMessage = '';
  final Set<Marker> _markers = {};
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserAndLocation();
  }

  Future<void> _loadUserAndLocation() async {
    setState(() => _isLoading = true);

    try {
      // Get current user using AuthService
      _currentUser = await _authService.getCurrentUser();

      // Add debugging print statements
      print('Current user data in location picker: ${_currentUser?.toMap()}');
      print(
        'Latitude in picker: ${_currentUser?.latitude}, Longitude in picker: ${_currentUser?.longitude}',
      );

      if (_currentUser == null) {
        setState(() {
          _errorMessage = 'Error: User not logged in';
          _isLoading = false;
        });
        return;
      }

      // Check if user already has saved location
      if (_currentUser!.latitude != null && _currentUser!.longitude != null) {
        _selectedLocation = LatLng(
          _currentUser!.latitude!,
          _currentUser!.longitude!,
        );
        _currentLocation = _selectedLocation;
        _updateMarkers();
        setState(() => _isLoading = false);
        _animateToPosition(_selectedLocation);
        return;
      }

      // Request location permission
      final status = await Permission.location.request();

      if (status.isGranted) {
        await _getCurrentLocation();
      } else {
        setState(() {
          _errorMessage =
              'Location permission denied. Please enable location services.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error initializing location: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = 'Location services are disabled. Please enable them.';
          _isLoading = false;
        });
        return;
      }

      // Get current position with high accuracy
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _selectedLocation = _currentLocation;
        _isLoading = false;
      });

      _updateMarkers();
      _animateToPosition(_currentLocation);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error getting current location: $e';
        _isLoading = false;
      });
    }
  }

  void _updateMarkers() {
    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('selectedLocation'),
          position: _selectedLocation,
          infoWindow: const InfoWindow(title: 'Your Pinned Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );
    });
  }

  Future<void> _animateToPosition(LatLng position) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: position, zoom: 16.0),
      ),
    );
  }

  Future<void> _saveLocationToFirestore() async {
    setState(() => _isLoading = true);

    try {
      // Make sure we have a current user
      if (_currentUser == null) {
        // Try to get the current user again if somehow it's null
        _currentUser = await _authService.getCurrentUser();

        if (_currentUser == null) {
          setState(() {
            _errorMessage = 'Error: User not logged in';
            _isLoading = false;
          });
          return;
        }
      }

      // Use AuthService method instead of direct Firestore update
      bool success = await _authService.updateUserLocation(
        _currentUser!.uid,
        _selectedLocation.latitude,
        _selectedLocation.longitude,
      );

      if (success) {
        // Call the callback function if provided
        if (widget.onLocationSelected != null) {
          widget.onLocationSelected!(
            _selectedLocation.latitude,
            _selectedLocation.longitude,
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pinned location saved successfully!')),
        );

        Navigator.pushNamed(
          context,
          '/resident_home',
        ); // Navigate to home screen
      } else {
        setState(() {
          _errorMessage = 'Error saving location';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving location: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Your Location'),
        backgroundColor: Colors.green,
      ),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentLocation,
              zoom: 15.0,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
            markers: _markers,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
            onTap: (LatLng location) {
              setState(() {
                _selectedLocation = location;
              });
              _updateMarkers();
            },
          ),

          // Helper Text
          Positioned(
            top: 16.0,
            left: 16.0,
            right: 16.0,
            child: Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: const Text(
                'Tap anywhere on the map to place your pin',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Error Message
          if (_errorMessage.isNotEmpty)
            Positioned(
              top: 80.0, // Moved down to avoid overlapping with helper text
              left: 16.0,
              right: 16.0,
              child: Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),

          // Loading Indicator
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),

          // Location Details Panel
          if (_currentUser != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20.0),
                    topRight: Radius.circular(20.0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  // Added SingleChildScrollView to fix overflow
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Pinned Location',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18.0,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              'User ID: ${_currentUser!.uid}',
                              style: const TextStyle(
                                fontSize: 12.0,
                                color: Colors.grey,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        'Latitude: ${_selectedLocation.latitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 16.0),
                      ),
                      Text(
                        'Longitude: ${_selectedLocation.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 16.0),
                      ),
                      const SizedBox(height: 8.0),
                      const Text(
                        'This is where your waste collection will be scheduled.',
                        style: TextStyle(
                          fontSize: 14.0,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ElevatedButton.icon(
                                onPressed: _getCurrentLocation,
                                icon: const Icon(Icons.my_location),
                                label: const Text('Use Current Location'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: ElevatedButton.icon(
                                onPressed: _saveLocationToFirestore,
                                icon: const Icon(Icons.save),
                                label: const Text('Save Pinned Location'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
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
}
