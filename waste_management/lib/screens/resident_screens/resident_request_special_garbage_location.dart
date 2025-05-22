import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:waste_management/models/specialGarbageRequestModel.dart';
import 'package:waste_management/models/userModel.dart';
import 'package:waste_management/service/special_Garbage_Request_service.dart';
import 'package:waste_management/service/auth_service.dart';

class SpecialGarbageRequestScreen extends StatefulWidget {
  const SpecialGarbageRequestScreen({Key? key}) : super(key: key);

  @override
  _SpecialGarbageRequestScreenState createState() =>
      _SpecialGarbageRequestScreenState();
}

class _SpecialGarbageRequestScreenState
    extends State<SpecialGarbageRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final SpecialGarbageRequestService _requestService =
      SpecialGarbageRequestService();
  final AuthService _authService = AuthService();
  UserModel? _currentUser;
  bool _isLoadingUser = true;

  // Form controllers
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // Form values
  String _selectedGarbageType = 'Furniture';
  File? _imageFile;
  String? _base64Image;
  double _latitude = 0.0;
  double _longitude = 0.0;
  bool _isLoading = false;

  // Map related variables
  GoogleMapController? _mapController;
  Position? _currentPosition;
  LatLng? _selectedLocation;
  Set<Marker> _markers = {};
  bool _isMapReady = false;
  bool _isMapFullScreen = false; // Flag for full-screen map mode

  // Garbage type options
  final List<String> _garbageTypes = [
    'Furniture',
    'Electronics',
    'Construction Debris',
    'Garden Waste',
    'Large Appliances',
    'Hazardous Waste',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _checkLocationPermission();
  }

  // Load current user data
  Future<void> _loadCurrentUser() async {
    try {
      final user = await _authService.getCurrentUser();
      setState(() {
        _currentUser = user;
        _isLoadingUser = false;
      });

      if (user == null) {
        // Handle case where user is not logged in
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not authenticated. Please log in.'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _isLoadingUser = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load user: $e')));
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    if (_mapController != null) {
      _mapController!.dispose();
    }
    super.dispose();
  }

  // Check location permission
  Future<void> _checkLocationPermission() async {
    setState(() {
      _isLoading = true;
    });

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showErrorDialog('Location services are disabled');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showErrorDialog('Location permission denied');
        setState(() {
          _isLoading = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showErrorDialog('Location permissions are permanently denied');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    await _getCurrentLocation();
    setState(() {
      _isLoading = false;
    });
  }

  // Show error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Error'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  // Get current location
  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _latitude = position.latitude;
        _longitude = position.longitude;
        _updateLocationText();
        _updateMarker();
      });

      if (_mapController != null && _isMapReady) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 16,
            ),
          ),
        );
      }

      // Get address from coordinates
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          String address =
              '${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}';

          setState(() {
            _locationController.text = address;
          });
        }
      } catch (e) {
        _locationController.text =
            '${position.latitude}, ${position.longitude}';
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to get location: $e')));
    }
  }

  // Update marker on map
  void _updateMarker() {
    if (_selectedLocation != null) {
      setState(() {
        _markers = {
          Marker(
            markerId: const MarkerId('selectedLocation'),
            position: _selectedLocation!,
            infoWindow: const InfoWindow(title: 'Collection Location'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
          ),
        };
      });
    }
  }

  // Update location text
  void _updateLocationText() {
    if (_selectedLocation != null) {
      _locationController.text =
          '${_selectedLocation!.latitude.toStringAsFixed(5)}, ${_selectedLocation!.longitude.toStringAsFixed(5)}';

      // Update latitude and longitude for submission
      _latitude = _selectedLocation!.latitude;
      _longitude = _selectedLocation!.longitude;
    }
  }

  // Handle map tap for location selection
  void _onMapTap(LatLng position) {
    setState(() {
      // If we're in normal mode, expand the map first
      if (!_isMapFullScreen) {
        _isMapFullScreen = true;
      } else {
        // In full-screen mode, update the location when tapped
        _selectedLocation = position;
        _updateLocationText();
        _updateMarker();
      }
    });
  }

  // Toggle map between full screen and normal view
  void _toggleMapFullScreen() {
    setState(() {
      _isMapFullScreen = !_isMapFullScreen;

      // When returning to the normal view, focus on the selected location
      if (!_isMapFullScreen &&
          _selectedLocation != null &&
          _mapController != null &&
          _isMapReady) {
        // Small delay to ensure the map is properly rendered after state change
        Future.delayed(const Duration(milliseconds: 300), () {
          _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: _selectedLocation!, zoom: 16),
            ),
          );
        });
      }
    });
  }

  // Pick image from gallery or camera
  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });

        // Convert to base64 for storage
        final bytes = await _imageFile!.readAsBytes();
        setState(() {
          _base64Image = base64Encode(bytes);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  // Show image picker dialog
  void _showImagePickerDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder:
          (context) => Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select Image Source',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Camera option
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.green.withOpacity(0.1),
                          child: IconButton(
                            icon: const Icon(
                              Icons.camera_alt,
                              color: Colors.green,
                              size: 30,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              _pickImage(ImageSource.camera);
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text('Camera'),
                      ],
                    ),
                    // Gallery option
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.green.withOpacity(0.1),
                          child: IconButton(
                            icon: const Icon(
                              Icons.photo_library,
                              color: Colors.green,
                              size: 30,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              _pickImage(ImageSource.gallery);
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text('Gallery'),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  // Submit the form
  Future<void> _submitRequest() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated. Please log in.')),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _requestService.createRequest(
          resident: _currentUser!,
          description: _descriptionController.text,
          garbageType: _selectedGarbageType,
          location: _locationController.text,
          latitude: _latitude,
          longitude: _longitude,
          base64Image: _base64Image,
          notes:
              _notesController.text.isNotEmpty ? _notesController.text : null,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Special garbage request submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  // This method is replaced by _toggleMapFullScreen

  @override
  Widget build(BuildContext context) {
    // Map widget that will be reused in both normal and full-screen mode
    Widget mapWidget = GoogleMap(
      onMapCreated: (controller) {
        _mapController = controller;
        setState(() {
          _isMapReady = true;
        });
        if (_currentPosition != null) {
          controller.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                ),
                zoom: 16,
              ),
            ),
          );
        }
      },
      initialCameraPosition: CameraPosition(
        target:
            _currentPosition != null
                ? LatLng(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                )
                : const LatLng(6.9271, 79.8612), // Default location
        zoom: 16,
      ),
      onTap: _onMapTap,
      markers: _markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      mapToolbarEnabled: false,
      zoomControlsEnabled: true,
      compassEnabled: true,
    );

    // Show full screen map if in full screen mode
    if (_isMapFullScreen) {
      return Scaffold(
        body: Stack(
          children: [
            // Full screen map
            SizedBox(
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width,
              child: mapWidget,
            ),

            // Simple back button to exit full screen
            Positioned(
              top: 40,
              left: 16,
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.green),
                  onPressed: _toggleMapFullScreen,
                ),
              ),
            ),

            // Message at the bottom to help user
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Tap anywhere on the map to select location',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Request Special Garbage Collection'),
      ),
      body:
          _isLoadingUser || _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Reason
                      const Text(
                        'Reason',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _reasonController,
                        decoration: InputDecoration(
                          hintText: 'Why do you need special collection?',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a reason';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Garbage Type
                      const Text(
                        'Garbage Type',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedGarbageType,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items:
                            _garbageTypes.map((String type) {
                              return DropdownMenuItem<String>(
                                value: type,
                                child: Text(type),
                              );
                            }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedGarbageType = newValue!;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a garbage type';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Location Map
                      const Text(
                        'Location',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _toggleMapFullScreen,
                        child: Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.3),
                                spreadRadius: 2,
                                blurRadius: 5,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: mapWidget,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.touch_app,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Tap on the map to expand and select location',
                            style: TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Location Text Field
                      TextFormField(
                        controller: _locationController,
                        decoration: InputDecoration(
                          hintText: 'Collection address',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(Icons.location_on),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.my_location),
                            onPressed: _getCurrentLocation,
                            tooltip: 'Use Current Location',
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a location or select on map';
                          }
                          return null;
                        },
                        readOnly: true,
                      ),
                      const SizedBox(height: 16),

                      // Description
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Describe the situation',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please provide a description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Image Upload
                      const Text(
                        'Upload Image (Optional)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _showImagePickerDialog,
                        child: Container(
                          width: double.infinity,
                          height: 150,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child:
                              _imageFile != null
                                  ? Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.file(
                                          _imageFile!,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 5,
                                        right: 5,
                                        child: CircleAvatar(
                                          backgroundColor: Colors.black
                                              .withOpacity(0.7),
                                          radius: 16,
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.delete,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _imageFile = null;
                                                _base64Image = null;
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                  : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate,
                                        size: 50,
                                        color: Colors.grey,
                                      ),
                                      SizedBox(height: 8),
                                      Text('Tap to add an image'),
                                    ],
                                  ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Additional Notes
                      const Text(
                        'Additional Notes (Optional)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Any special instructions or notes',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitRequest,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: Colors.green,
                          ),
                          child: const Text(
                            'Submit',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
