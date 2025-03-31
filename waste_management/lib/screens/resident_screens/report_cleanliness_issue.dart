import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:waste_management/models/userModel.dart';
import 'package:waste_management/service/auth_service.dart';
import 'package:waste_management/service/cleanliness_issue_service.dart';

class ReportCleanlinessIssuePage extends StatefulWidget {
  const ReportCleanlinessIssuePage({Key? key}) : super(key: key);

  @override
  _ReportCleanlinessIssuePageState createState() => _ReportCleanlinessIssuePageState();
}

class _ReportCleanlinessIssuePageState extends State<ReportCleanlinessIssuePage> {
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final CleanlinessIssueService _issueService = CleanlinessIssueService();
  final AuthService _authService = AuthService();

  XFile? _imageFile;
  String? _base64Image;
  GoogleMapController? _mapController;
  Position? _currentPosition;
  LatLng? _selectedLocation;
  Set<Marker> _markers = {};
  bool _isLoading = false;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
  }

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

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      setState(() {
        _currentPosition = position;
        _selectedLocation = LatLng(position.latitude, position.longitude);
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
    } catch (e) {
      _showErrorDialog('Error getting location: $e');
    }
  }

  void _updateMarker() {
    if (_selectedLocation != null) {
      setState(() {
        _markers = {
          Marker(
            markerId: const MarkerId('selectedLocation'),
            position: _selectedLocation!,
            infoWindow: const InfoWindow(title: 'Issue Location'),
          ),
        };
      });
    }
  }

  void _updateLocationText() {
    if (_selectedLocation != null) {
      _locationController.text = 
          '${_selectedLocation!.latitude.toStringAsFixed(5)}, ${_selectedLocation!.longitude.toStringAsFixed(5)}';
    }
  }

  void _onMapTap(LatLng position) {
    setState(() {
      _selectedLocation = position;
      _updateLocationText();
      _updateMarker();
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800, // Reduced for Firestore storage
      maxHeight: 800, // Reduced for Firestore storage
      imageQuality: 70, // Reduced quality to keep base64 string smaller
    );
    
    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      List<int> imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      setState(() {
        _imageFile = pickedFile;
        _base64Image = base64Image;
      });
    }
  }

  Future<void> _takePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800, // Reduced for Firestore storage
      maxHeight: 800, // Reduced for Firestore storage
      imageQuality: 70, // Reduced quality to keep base64 string smaller
    );
    
    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      List<int> imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      setState(() {
        _imageFile = pickedFile;
        _base64Image = base64Image;
      });
    }
  }

  Future<void> _submitIssue() async {
    // Validate inputs
    if (_descriptionController.text.isEmpty || 
        _base64Image == null || 
        _selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields, select a location, and add an image')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get current user
      UserModel? currentUser = await _authService.getCurrentUser();
      
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in first')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Add prefix to base64 image if needed
      String formattedBase64 = _base64Image!;
      if (!formattedBase64.startsWith('data:image')) {
        formattedBase64 = 'data:image/jpeg;base64,' + formattedBase64;
      }

      // Submit the issue with base64 image directly to Firestore
      await _issueService.createIssueWithBase64Image(
        resident: currentUser,
        description: _descriptionController.text,
        location: _locationController.text,
        latitude: _selectedLocation!.latitude,
        longitude: _selectedLocation!.longitude,
        base64Image: formattedBase64,
      );

      // Clear form and show success
      setState(() {
        _locationController.clear();
        _descriptionController.clear();
        _imageFile = null;
        _base64Image = null;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cleanliness issue reported successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error reporting issue: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Color for icons and browse text
    const Color iconColor = Color(0xFF59A867);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Cleanliness Issue'),
        centerTitle: true,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF59A867)))
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Location Map
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
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
                        borderRadius: BorderRadius.circular(10),
                        child: GoogleMap(
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
                            target: _currentPosition != null
                                ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                                : const LatLng(6.9271, 79.8612), // Default location
                            zoom: 16,
                          ),
                          onTap: _onMapTap,
                          markers: _markers,
                          myLocationEnabled: true,
                          myLocationButtonEnabled: true,
                          mapToolbarEnabled: false,
                          zoomControlsEnabled: false,
                          compassEnabled: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Instructions for map
                    const Text(
                      'Tap on the map to select the exact location of the issue',
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Location Input (read-only, updated from map)
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.3),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _locationController,
                        readOnly: true,
                        decoration: InputDecoration(
                          hintText: 'Select location on map',
                          prefixIcon: const Icon(Icons.location_on, color: iconColor),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.my_location, color: iconColor),
                            onPressed: _getCurrentLocation,
                            tooltip: 'Use current location',
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Description Input
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.3),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _descriptionController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Describe the issue',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Image Upload Section with camera and gallery options
                    Text(
                      'Add Photo Evidence',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    // Image preview or placeholder
                    GestureDetector(
                      onTap: () => _showImageSourceOptions(),
                      child: Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              spreadRadius: 2,
                              blurRadius: 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: _imageFile == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.add_a_photo, size: 50, color: iconColor),
                                  Text('Add Photo', style: TextStyle(color: iconColor)),
                                ],
                              )
                            : Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.file(
                                      File(_imageFile!.path),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: CircleAvatar(
                                      backgroundColor: Colors.black.withOpacity(0.7),
                                      radius: 16,
                                      child: IconButton(
                                        icon: const Icon(Icons.close, size: 16, color: Colors.white),
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
                              ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Submit Button
                    ElevatedButton(
                      onPressed: _submitIssue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF59A867),
                        minimumSize: const Size(300, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Submit Report',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder: (context) => Padding(
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
                      backgroundColor: const Color(0xFF59A867).withOpacity(0.1),
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, color: Color(0xFF59A867), size: 30),
                        onPressed: () {
                          Navigator.pop(context);
                          _takePhoto();
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
                      backgroundColor: const Color(0xFF59A867).withOpacity(0.1),
                      child: IconButton(
                        icon: const Icon(Icons.photo_library, color: Color(0xFF59A867), size: 30),
                        onPressed: () {
                          Navigator.pop(context);
                          _pickImage();
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
}