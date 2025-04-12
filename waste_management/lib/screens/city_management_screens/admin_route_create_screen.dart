import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:waste_management/models/routeModel.dart';
import 'package:waste_management/models/userModel.dart';
import 'package:waste_management/service/auth_service.dart';
import 'package:waste_management/service/route_service.dart';

class AdminRouteCreationScreen extends StatefulWidget {
  const AdminRouteCreationScreen({Key? key}) : super(key: key);

  @override
  _AdminRouteCreationScreenState createState() => _AdminRouteCreationScreenState();
}

class _AdminRouteCreationScreenState extends State<AdminRouteCreationScreen> {
  final RouteService _routeService = RouteService();
  final AuthService _authService = AuthService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  
  // Driver assignment fields
  final TextEditingController _driverNameController = TextEditingController();
  final TextEditingController _driverContactController = TextEditingController();
  final TextEditingController _truckIdController = TextEditingController();
  String? _selectedDriverId;
  
  // List to store driver data
  List<UserModel> _drivers = [];
  // List to store resident data
  List<UserModel> _residents = [];
  
  bool _isLoadingDrivers = true;
  bool _isLoadingResidents = true;
  bool _showResidentLocations = false;
  
  GoogleMapController? _mapController;
  LatLng? _startPoint;
  LatLng? _endPoint;
  Set<Marker> _markers = {};
  Set<Marker> _residentMarkers = {};
  Set<Polyline> _polylines = {};
  
  bool _isCreatingRoute = false;
  
  @override
  void initState() {
    super.initState();
    _fetchDrivers();
    _fetchResidents();
  }
  
  // Fetch all drivers from Firestore
  Future<void> _fetchDrivers() async {
    setState(() {
      _isLoadingDrivers = true;
    });
    
    try {
      final drivers = await _authService.getDrivers();
      
      setState(() {
        _drivers = drivers;
        _isLoadingDrivers = false;
      });
    } catch (e) {
      print('Error fetching drivers: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load drivers: $e')),
      );
      setState(() {
        _isLoadingDrivers = false;
      });
    }
  }
  
  // Fetch all residents with saved locations
  Future<void> _fetchResidents() async {
    setState(() {
      _isLoadingResidents = true;
    });
    
    try {
      // Add getResidentsWithLocations method to AuthService
      final residents = await _authService.getResidentsWithLocations();
      
      setState(() {
        _residents = residents;
        _isLoadingResidents = false;
        _createResidentMarkers();
      });
    } catch (e) {
      print('Error fetching residents: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load resident locations: $e')),
      );
      setState(() {
        _isLoadingResidents = false;
      });
    }
  }
  
  // Create markers for resident locations
  void _createResidentMarkers() {
    Set<Marker> markers = {};
    
    for (int i = 0; i < _residents.length; i++) {
      UserModel resident = _residents[i];
      
      // Skip if resident doesn't have location data
      if (resident.latitude == null || resident.longitude == null) continue;
      
      markers.add(
        Marker(
          markerId: MarkerId('resident_${resident.uid}'),
          position: LatLng(resident.latitude!, resident.longitude!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
          infoWindow: InfoWindow(
            title: resident.name,
            snippet: resident.address,
            onTap: () {
              // Option to add this resident location as a route point
              _showResidentLocationDialog(resident);
            },
          ),
        ),
      );
    }
    
    setState(() {
      _residentMarkers = markers;
    });
  }
  
  // Dialog to add resident location as route point
  void _showResidentLocationDialog(UserModel resident) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add to Route'),
        content: Text('Do you want to add ${resident.name}\'s location to the route?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _addResidentMarker(resident);
            },
            child: Text('Add as Point'),
          ),
        ],
      ),
    );
  }
  
  // Add resident location as a route point
  void _addResidentMarker(UserModel resident) {
    final position = LatLng(resident.latitude!, resident.longitude!);
    
    setState(() {
      if (_markers.isEmpty) {
        // First point - Start
        _startPoint = position;
        _markers.add(
          Marker(
            markerId: MarkerId('start'),
            position: position,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(
              title: 'Start Point',
              snippet: 'Resident: ${resident.name}',
            ),
          ),
        );
      } else if (_markers.length == 1) {
        // Second point - End
        _endPoint = position;
        _markers.add(
          Marker(
            markerId: MarkerId('end'),
            position: position,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(
              title: 'End Point',
              snippet: 'Resident: ${resident.name}',
            ),
          ),
        );
        
        // Draw basic line between points
        _polylines.add(
          Polyline(
            polylineId: PolylineId('route'),
            points: [_startPoint!, _endPoint!],
            color: Colors.blue,
            width: 3,
          ),
        );
      }
    });
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _driverNameController.dispose();
    _driverContactController.dispose();
    _truckIdController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Waste Collection Route'),
        actions: [
          IconButton(
            icon: Icon(Icons.list),
            onPressed: () {
              Navigator.pushNamed(context, '/admin_route_list');
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Map Section (2/3 of screen)
              Expanded(
                flex: 2,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(37.7749, -122.4194), // Default center
                    zoom: 13,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  markers: _showResidentLocations 
                      ? {..._markers, ..._residentMarkers}
                      : _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  onTap: _addMarker,
                ),
              ),
              
              // Form Section (1/3 of screen)
              Expanded(
                flex: 1,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Route Details',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Row(
                            children: [
                              Text('Show Resident Locations'),
                              Switch(
                                value: _showResidentLocations,
                                onChanged: (value) {
                                  setState(() {
                                    _showResidentLocations = value;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Route Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 12),
                      
                      TextField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      SizedBox(height: 20),
                      
                      // Driver Assignment Section
                      Text(
                        'Driver Assignment',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SizedBox(height: 12),
                      
                      // Driver Dropdown
                      _isLoadingDrivers
                          ? Center(child: CircularProgressIndicator())
                          : DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: 'Select Driver',
                                border: OutlineInputBorder(),
                              ),
                              value: _selectedDriverId,
                              hint: Text('Choose a driver'),
                              onChanged: (value) {
                                setState(() {
                                  _selectedDriverId = value;
                                  // Find the selected driver and populate fields
                                  if (value != null) {
                                    final selectedDriver = _drivers.firstWhere(
                                      (driver) => driver.uid == value,
                                      orElse: () => UserModel(
                                        uid: '',
                                        name: '',
                                        role: '',
                                        nic: '',
                                        address: '',
                                        contactNumber: '',
                                        email: '',
                                      ),
                                    );
                                    
                                    // Populate driver details
                                    _driverNameController.text = selectedDriver.name;
                                    _driverContactController.text = selectedDriver.contactNumber;
                                    
                                    // Use the driver's ID as the truck ID
                                    _truckIdController.text = 'TRUCK-${selectedDriver.uid.substring(0, 6)}';
                                  }
                                });
                              },
                              items: _drivers.map((driver) {
                                return DropdownMenuItem(
                                  value: driver.uid,
                                  child: Text(driver.name),
                                );
                              }).toList(),
                            ),
                      SizedBox(height: 12),
                      
                      TextField(
                        controller: _driverNameController,
                        decoration: InputDecoration(
                          labelText: 'Driver Name',
                          border: OutlineInputBorder(),
                        ),
                        enabled: false, // Automatically filled based on selection
                      ),
                      SizedBox(height: 12),
                      
                      TextField(
                        controller: _driverContactController,
                        decoration: InputDecoration(
                          labelText: 'Driver Contact',
                          border: OutlineInputBorder(),
                        ),
                        enabled: false, // Automatically filled based on selection
                      ),
                      SizedBox(height: 12),
                      
                      TextField(
                        controller: _truckIdController,
                        decoration: InputDecoration(
                          labelText: 'Truck ID',
                          border: OutlineInputBorder(),
                        ),
                        enabled: false, // Automatically filled based on driver selection
                      ),
                      SizedBox(height: 20),
                      
                      ElevatedButton(
                        onPressed: _markers.length < 2 || _isCreatingRoute ? null : _createRoute,
                        child: _isCreatingRoute 
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text('Creating Route...'),
                              ],
                            )
                          : Text('Create Route'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                      
                      if (_markers.length < 2)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'Tap on the map or select resident locations to set start and end points',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.red[700],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // Legend/Instructions overlay
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.circle, color: Colors.green, size: 16),
                      SizedBox(width: 4),
                      Text('Start Point'),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.circle, color: Colors.red, size: 16),
                      SizedBox(width: 4),
                      Text('End Point'),
                    ],
                  ),
                  if (_showResidentLocations) ...[
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.circle, color: Colors.yellow, size: 16),
                        SizedBox(width: 4),
                        Text('Resident Location'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Resident locations loading indicator
          if (_isLoadingResidents && _showResidentLocations)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Loading residents...'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  void _addMarker(LatLng position) {
    setState(() {
      if (_markers.isEmpty) {
        // First point - Start
        _startPoint = position;
        _markers.add(
          Marker(
            markerId: MarkerId('start'),
            position: position,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(title: 'Start Point'),
          ),
        );
      } else if (_markers.length == 1) {
        // Second point - End
        _endPoint = position;
        _markers.add(
          Marker(
            markerId: MarkerId('end'),
            position: position,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(title: 'End Point'),
          ),
        );
        
        // Draw basic line between points (will be replaced with actual directions)
        _polylines.add(
          Polyline(
            polylineId: PolylineId('route'),
            points: [_startPoint!, _endPoint!],
            color: Colors.blue,
            width: 3,
          ),
        );
      } else {
        // Clear and reset if adding more points
        _markers.clear();
        _polylines.clear();
        _startPoint = position;
        _markers.add(
          Marker(
            markerId: MarkerId('start'),
            position: position,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(title: 'Start Point'),
          ),
        );
      }
    });
  }
  
  void _createRoute() async {
    if (_startPoint == null || _endPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please set start and end points')),
      );
      return;
    }
    
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a route name')),
      );
      return;
    }
    
    if (_selectedDriverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a driver')),
      );
      return;
    }
    
    setState(() {
      _isCreatingRoute = true;
    });
    
    try {
      await _routeService.saveRouteWithDirections(
        _nameController.text,
        _descriptionController.text,
        _startPoint!,
        _endPoint!,
        assignedDriverId: _selectedDriverId,
        driverName: _driverNameController.text,
        driverContact: _driverContactController.text,
        truckId: _truckIdController.text,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Route created successfully')),
      );
      
      // Clear the form
      _nameController.clear();
      _descriptionController.clear();
      _driverNameController.clear();
      _driverContactController.text = "";
      _truckIdController.clear();
      setState(() {
        _selectedDriverId = null;
        _markers.clear();
        _polylines.clear();
        _startPoint = null;
        _endPoint = null;
      });
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating route: $e')),
      );
    } finally {
      setState(() {
        _isCreatingRoute = false;
      });
    }
  }
}