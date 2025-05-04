import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:waste_management/models/routeModel.dart';
import 'package:waste_management/models/userModel.dart';
import 'package:waste_management/service/auth_service.dart';
import 'package:waste_management/service/route_service.dart';

class AdminRouteCreationScreen extends StatefulWidget {
  const AdminRouteCreationScreen({Key? key}) : super(key: key);

  @override
  _AdminRouteCreationScreenState createState() =>
      _AdminRouteCreationScreenState();
}

class _AdminRouteCreationScreenState extends State<AdminRouteCreationScreen> {
  final RouteService _routeService = RouteService();
  final AuthService _authService = AuthService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _driverNameController = TextEditingController();
  final TextEditingController _driverContactController =
      TextEditingController();
  final TextEditingController _truckIdController = TextEditingController();

  // App theme color
  final Color primaryColor = Color(0xFF59A867);

  String? _selectedDriverId;
  List<UserModel> _drivers = [];
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

  // Page controller for sliding between sections
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Form validation key
  final _formKey = GlobalKey<FormState>();

  // Scheduling fields
  String _scheduleFrequency = 'once';
  List<int> _selectedDays = [];
  TimeOfDay _scheduleStartTime = TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _scheduleEndTime = TimeOfDay(hour: 17, minute: 0);
  String _wasteCategory = 'mixed';

  // Map style
  bool _mapDarkMode = false;

  @override
  void initState() {
    super.initState();
    _fetchDrivers();
    _fetchResidents();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _driverNameController.dispose();
    _driverContactController.dispose();
    _truckIdController.dispose();
    _mapController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchDrivers() async {
    setState(() => _isLoadingDrivers = true);
    try {
      final drivers = await _authService.getDrivers();
      setState(() {
        _drivers = drivers;
        _isLoadingDrivers = false;
      });
    } catch (e) {
      print('Error fetching drivers: $e');
      _showSnackBar('Failed to load drivers: $e');
      setState(() => _isLoadingDrivers = false);
    }
  }

  Future<void> _fetchResidents() async {
    setState(() => _isLoadingResidents = true);
    try {
      final residents = await _authService.getResidentsWithLocations();
      setState(() {
        _residents = residents;
        _isLoadingResidents = false;
        _createResidentMarkers();
      });
    } catch (e) {
      print('Error fetching residents: $e');
      _showSnackBar('Failed to load resident locations: $e');
      setState(() => _isLoadingResidents = false);
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[700] : primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(10),
      ),
    );
  }

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
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueYellow,
          ),
          infoWindow: InfoWindow(
            title: resident.name,
            snippet: resident.address,
            onTap: () {
              _showResidentLocationDialog(resident);
            },
          ),
        ),
      );
    }

    setState(() => _residentMarkers = markers);
  }

  void _showResidentLocationDialog(UserModel resident) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Add to Route'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Do you want to add this location to the route?'),
                SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.person, color: primaryColor),
                  title: Text(resident.name),
                  subtitle: Text(resident.address ?? 'No address provided'),
                  dense: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _addResidentMarker(resident);
                },
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                child: Text('Add as Point'),
              ),
            ],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
    );
  }

  void _addResidentMarker(UserModel resident) {
    final position = LatLng(resident.latitude!, resident.longitude!);
    _addMarkerAtPosition(position, resident.name);
  }

  void _addMarkerAtPosition(LatLng position, [String? residentName]) {
    setState(() {
      if (_markers.isEmpty) {
        // First point - Start
        _startPoint = position;
        _markers.add(
          Marker(
            markerId: MarkerId('start'),
            position: position,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
            infoWindow: InfoWindow(
              title: 'Start Point',
              snippet: residentName != null ? 'Resident: $residentName' : null,
            ),
          ),
        );
        _showSnackBar('Start point added successfully', isError: false);
      } else if (_markers.length == 1) {
        // Second point - End
        _endPoint = position;
        _markers.add(
          Marker(
            markerId: MarkerId('end'),
            position: position,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
            infoWindow: InfoWindow(
              title: 'End Point',
              snippet: residentName != null ? 'Resident: $residentName' : null,
            ),
          ),
        );

        // Draw basic line between points
        _polylines.add(
          Polyline(
            polylineId: PolylineId('route'),
            points: [_startPoint!, _endPoint!],
            color: primaryColor,
            width: 5,
          ),
        );
        _showSnackBar('End point added and route drawn', isError: false);
      } else {
        // Clear and reset if adding more points
        _markers.clear();
        _polylines.clear();
        _startPoint = position;
        _markers.add(
          Marker(
            markerId: MarkerId('start'),
            position: position,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
            infoWindow: InfoWindow(
              title: 'Start Point',
              snippet: residentName != null ? 'Resident: $residentName' : null,
            ),
          ),
        );
        _showSnackBar('Route reset. New start point added', isError: false);
      }
      print('Driver ID: $_selectedDriverId');
    });
  }

  void _addMarker(LatLng position) {
    _addMarkerAtPosition(position);
  }

  Future<void> _createRoute() async {
    final formState = _formKey.currentState;
    if (formState == null) {
      _showSnackBar('Form is not available. Please try again.');
      return;
    }
    if (!formState.validate()) {
      _showSnackBar('Please correct the errors in the form');
      return;
    }

    if (_startPoint == null || _endPoint == null) {
      _showSnackBar('Start or End point is missing');
      setState(() => _isCreatingRoute = false);
      return;
    }

    print('Start: $_startPoint, End: $_endPoint');

    if (_scheduleFrequency != 'once' && _selectedDays.isEmpty) {
      _showSnackBar('Please select at least one day for recurring collection');
      return;
    }

    if (_selectedDriverId == null) {
      _showSnackBar('Please select a driver for this route');
      return;
    }

    setState(() => _isCreatingRoute = true);

    try {
      await _routeService.saveScheduledRoute(
        _nameController.text.trim(),
        _descriptionController.text.trim(),
        _startPoint!,
        _endPoint!,
        assignedDriverId: _selectedDriverId,
        driverName: _driverNameController.text.trim(),
        driverContact: _driverContactController.text.trim(),
        truckId: _truckIdController.text.trim(),
        scheduleFrequency: _scheduleFrequency,
        scheduleDays: _selectedDays,
        scheduleStartTime: _scheduleStartTime,
        scheduleEndTime: _scheduleEndTime,
        wasteCategory: _wasteCategory,
      );

      _showSnackBar('Route created successfully! 🎉', isError: false);

      // Clear the form
      _formKey.currentState!.reset();
      _nameController.clear();
      _descriptionController.clear();
      _driverNameController.clear();
      _driverContactController.clear();
      _truckIdController.clear();
      setState(() {
        _selectedDriverId = null;
        _markers.clear();
        _polylines.clear();
        _startPoint = null;
        _endPoint = null;
        _scheduleFrequency = 'once';
        _selectedDays = [];
        _scheduleStartTime = TimeOfDay(hour: 8, minute: 0);
        _scheduleEndTime = TimeOfDay(hour: 17, minute: 0);
        _wasteCategory = 'mixed';
        _currentPage = 0;
        _pageController.animateToPage(
          0,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    } catch (e) {
      _showSnackBar('Error creating route: $e');
    } finally {
      setState(() => _isCreatingRoute = false);
    }
  }

  String _getFormattedTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStepCircle(0, 'Map'),
          _buildStepDivider(0),
          _buildStepCircle(1, 'Details'),
          _buildStepDivider(1),
          _buildStepCircle(2, 'Schedule'),
          _buildStepDivider(2),
          _buildStepCircle(3, 'Driver'),
        ],
      ),
    );
  }

  Widget _buildStepCircle(int step, String label) {
    final isActive = _currentPage == step;
    final isCompleted = _currentPage > step;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: isActive || isCompleted ? primaryColor : Colors.grey[300],
            shape: BoxShape.circle,
            boxShadow:
                isActive
                    ? [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ]
                    : null,
          ),
          child: Center(
            child:
                isCompleted
                    ? Icon(Icons.check, color: Colors.white, size: 16)
                    : Text(
                      '${step + 1}',
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive ? primaryColor : Colors.grey[600],
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider(int beforeStep) {
    final isActive = _currentPage > beforeStep;

    return Container(
      width: 40,
      height: 2,
      color: isActive ? primaryColor : Colors.grey[300],
    );
  }

  void _toggleMapStyle() {
    setState(() {
      _mapDarkMode = !_mapDarkMode;
    });

    if (_mapController != null) {
      _mapController!.setMapStyle(
        _mapDarkMode
            ? '[{"featureType":"all","elementType":"geometry","stylers":[{"color":"#242f3e"}]},{"featureType":"all","elementType":"labels.text.stroke","stylers":[{"lightness":-80}]},{"featureType":"administrative","elementType":"labels.text.fill","stylers":[{"color":"#746855"}]},{"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},{"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},{"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#263c3f"}]},{"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#6b9a76"}]},{"featureType":"road","elementType":"geometry","stylers":[{"color":"#38414e"}]},{"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#212a37"}]},{"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#9ca5b3"}]},{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#746855"}]},{"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#1f2835"}]},{"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#f3d19c"}]},{"featureType":"transit","elementType":"geometry","stylers":[{"color":"#2f3948"}]},{"featureType":"transit.station","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#17263c"}]},{"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#515c6d"}]},{"featureType":"water","elementType":"labels.text.stroke","stylers":[{"lightness":-20}]}]'
            : null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Create Waste Collection Route',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.list_alt_rounded),
            tooltip: 'View Routes',
            onPressed: () {
              Navigator.pushNamed(context, '/admin_route_list');
            },
          ),
          IconButton(
            icon: Icon(
              _mapDarkMode
                  ? Icons.wb_sunny_outlined
                  : Icons.nights_stay_outlined,
            ),
            tooltip: _mapDarkMode ? 'Light Mode' : 'Dark Mode',
            onPressed: _toggleMapStyle,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildStepIndicator(),
            Expanded(
              child: Form(
                key: _formKey,
                child: PageView(
                  controller: _pageController,
                  physics: NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  children: [
                    _buildMapPage(),
                    _buildRouteDetailsPage(),
                    _buildSchedulePage(),
                    _buildDriverPage(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: BottomAppBar(
          color: Colors.white,
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.arrow_back),
                    label: Text('Previous'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _currentPage > 0 ? primaryColor : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed:
                        _currentPage > 0
                            ? () {
                              _pageController.previousPage(
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                            : null,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child:
                      _currentPage == 3
                          ? ElevatedButton.icon(
                            icon:
                                _isCreatingRoute
                                    ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                    : Icon(Icons.check),
                            label: Text(
                              _isCreatingRoute ? 'Creating...' : 'Create',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _markers.length < 2 || _isCreatingRoute
                                      ? Colors.grey
                                      : primaryColor,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed:
                                _markers.length < 2 || _isCreatingRoute
                                    ? null
                                    : _createRoute,
                          )
                          : ElevatedButton.icon(
                            icon: Icon(Icons.arrow_forward),
                            label: Text('Next'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () {
                              _pageController.nextPage(
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapPage() {
    return Stack(
      children: [
        // Google Map
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(6.9271, 79.8612),
            zoom: 13,
          ),
          onMapCreated: (controller) {
            _mapController = controller;
            if (_mapDarkMode) {
              controller.setMapStyle(
                '[{"featureType":"all","elementType":"geometry","stylers":[{"color":"#242f3e"}]},{"featureType":"all","elementType":"labels.text.stroke","stylers":[{"lightness":-80}]},{"featureType":"administrative","elementType":"labels.text.fill","stylers":[{"color":"#746855"}]},{"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},{"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},{"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#263c3f"}]},{"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#6b9a76"}]},{"featureType":"road","elementType":"geometry","stylers":[{"color":"#38414e"}]},{"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#212a37"}]},{"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#9ca5b3"}]},{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#746855"}]},{"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#1f2835"}]},{"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#f3d19c"}]},{"featureType":"transit","elementType":"geometry","stylers":[{"color":"#2f3948"}]},{"featureType":"transit.station","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#17263c"}]},{"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#515c6d"}]},{"featureType":"water","elementType":"labels.text.stroke","stylers":[{"lightness":-20}]}]',
              );
            }
          },
          onCameraMove: (position) {}, // Keep this to allow dragging
          gestureRecognizers:
              Set()
                ..add(
                  Factory<PanGestureRecognizer>(() => PanGestureRecognizer()),
                )
                ..add(
                  Factory<ScaleGestureRecognizer>(
                    () => ScaleGestureRecognizer(),
                  ),
                )
                ..add(
                  Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
                )
                ..add(
                  Factory<VerticalDragGestureRecognizer>(
                    () => VerticalDragGestureRecognizer(),
                  ),
                ),
          zoomGesturesEnabled: true,
          scrollGesturesEnabled: true,
          rotateGesturesEnabled: true,
          tiltGesturesEnabled: true,
          markers:
              _showResidentLocations
                  ? {..._markers, ..._residentMarkers}
                  : _markers,
          polylines: _polylines,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: true,
          onTap: _addMarker,
        ),

        // Floating controls
        Positioned(
          top: 16,
          right: 16,
          child: Column(
            children: [
              _buildMapControlButton(
                icon: Icons.my_location,
                tooltip: 'My Location',
                onPressed: () {
                  _mapController?.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(
                        target: LatLng(
                          6.9271,
                          79.8612,
                        ), // Default or get from GPS
                        zoom: 15,
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 8),
              _buildMapControlButton(
                icon: Icons.zoom_in,
                tooltip: 'Zoom In',
                onPressed: () {
                  _mapController?.animateCamera(CameraUpdate.zoomIn());
                },
              ),
              SizedBox(height: 8),
              _buildMapControlButton(
                icon: Icons.zoom_out,
                tooltip: 'Zoom Out',
                onPressed: () {
                  _mapController?.animateCamera(CameraUpdate.zoomOut());
                },
              ),
              SizedBox(height: 8),
              _buildMapControlButton(
                icon: _markers.isNotEmpty ? Icons.refresh : Icons.location_on,
                tooltip: _markers.isNotEmpty ? 'Reset Points' : 'Add Points',
                onPressed: () {
                  if (_markers.isNotEmpty) {
                    setState(() {
                      _markers.clear();
                      _polylines.clear();
                      _startPoint = null;
                      _endPoint = null;
                    });
                    _showSnackBar(
                      'Route points have been reset',
                      isError: false,
                    );
                  } else {
                    _showSnackBar(
                      'Tap on the map to add route points',
                      isError: false,
                    );
                  }
                },
              ),
            ],
          ),
        ),

        // Resident locations toggle
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Resident Locations',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Switch(
                        value: _showResidentLocations,
                        activeColor: primaryColor,
                        onChanged: (value) {
                          setState(() {
                            _showResidentLocations = value;
                          });
                          if (value && _isLoadingResidents) {
                            _showSnackBar(
                              'Loading resident locations...',
                              isError: false,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  if (_showResidentLocations) ...[
                    SizedBox(height: 8),
                    Text(
                      'Tap on a resident marker (yellow) to add it to your route',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Map legend
        Positioned(
          top: 16,
          left: 16,
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Map Legend',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.green, size: 18),
                      SizedBox(width: 4),
                      Text('Start Point', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.red, size: 18),
                      SizedBox(width: 4),
                      Text('End Point', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                  if (_showResidentLocations) ...[
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: Colors.yellow[700],
                          size: 18,
                        ),
                        SizedBox(width: 4),
                        Text('Resident', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Loading indicator for residents
        if (_isLoadingResidents && _showResidentLocations)
          Positioned(
            top: 16,
            right: 90,
            child: Card(
              color: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text('Loading residents...'),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMapControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: IconButton(
        icon: Icon(icon),
        color: primaryColor,
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildRouteDetailsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Route Details', Icons.route),
          SizedBox(height: 16),

          _buildTextFormField(
            controller: _nameController,
            labelText: 'Route Name',
            prefixIcon: Icons.label_outline,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a route name';
              }
              return null;
            },
          ),
          SizedBox(height: 16),

          _buildTextFormField(
            controller: _descriptionController,
            labelText: 'Description',
            prefixIcon: Icons.description_outlined,
            maxLines: 3,
            hintText: 'Enter route description and any special instructions',
          ),
          SizedBox(height: 20),

          _buildSectionHeader('Route Status', Icons.info_outline),
          SizedBox(height: 16),

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
                  Row(
                    children: [
                      Icon(
                        _startPoint != null && _endPoint != null
                            ? Icons.check_circle
                            : Icons.error_outline,
                        color:
                            _startPoint != null && _endPoint != null
                                ? primaryColor
                                : Colors.orange,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Route Points',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _buildStatusItem(
                          'Start Point',
                          _startPoint != null ? 'Set ✓' : 'Not Set',
                          _startPoint != null,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildStatusItem(
                          'End Point',
                          _endPoint != null ? 'Set ✓' : 'Not Set',
                          _endPoint != null,
                        ),
                      ),
                    ],
                  ),

                  if (_startPoint != null && _endPoint != null) ...[
                    SizedBox(height: 16),
                    Text(
                      'Your route is ready! Continue to add scheduling details.',
                      style: TextStyle(
                        color: primaryColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ] else ...[
                    SizedBox(height: 16),
                    Text(
                      'Go back to the map and set the required points by tapping on the map.',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: 20),

          Center(
            child: OutlinedButton.icon(
              icon: Icon(Icons.map),
              label: Text('Return to Map'),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: BorderSide(color: primaryColor),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () {
                _pageController.animateToPage(
                  0,
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchedulePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Schedule Information', Icons.calendar_today),
          SizedBox(height: 16),

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
                  Text(
                    'How often should this route be collected?',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 16),

                  // Frequency selection as vertical column with radio buttons
                  Column(
                    children: [
                      _buildFrequencyOption('once', 'Once', Icons.looks_one),
                      SizedBox(height: 8),
                      _buildFrequencyOption(
                        'weekly',
                        'Weekly',
                        Icons.calendar_view_week,
                      ),
                      SizedBox(height: 8),
                      _buildFrequencyOption(
                        'biweekly',
                        'Biweekly',
                        Icons.calendar_view_month,
                      ),
                      SizedBox(height: 8),
                      _buildFrequencyOption('monthly', 'Monthly', Icons.event),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),

          if (_scheduleFrequency != 'once')
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
                    Text(
                      'Which days of the week?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 12),

                    // Day selection
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(
                        7,
                        (i) => FilterChip(
                          label: Text(
                            [
                              'Sun',
                              'Mon',
                              'Tue',
                              'Wed',
                              'Thu',
                              'Fri',
                              'Sat',
                            ][i],
                          ),
                          selected: _selectedDays.contains(i),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedDays.add(i);
                              } else {
                                _selectedDays.remove(i);
                              }
                            });
                          },
                          selectedColor: primaryColor.withOpacity(0.2),
                          checkmarkColor: primaryColor,
                          labelStyle: TextStyle(
                            color:
                                _selectedDays.contains(i)
                                    ? primaryColor
                                    : Colors.black87,
                            fontWeight:
                                _selectedDays.contains(i)
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),

                    if (_selectedDays.isEmpty &&
                        _scheduleFrequency != 'once') ...[
                      SizedBox(height: 10),
                      Text(
                        'Please select at least one day',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          SizedBox(height: 16),

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
                  Text(
                    'Collection Time Window',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: _scheduleStartTime,
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: primaryColor,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (time != null)
                              setState(() => _scheduleStartTime = time);
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Start Time',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      color: primaryColor,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      _getFormattedTime(_scheduleStartTime),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: _scheduleEndTime,
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: primaryColor,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (time != null)
                              setState(() => _scheduleEndTime = time);
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'End Time',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      color: primaryColor,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      _getFormattedTime(_scheduleEndTime),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
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
                ],
              ),
            ),
          ),
          SizedBox(height: 16),

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
                  Text(
                    'Waste Category',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 16),

                  // Waste category selection
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildWasteCategoryOption(
                        'organic',
                        'Organic',
                        Icons.eco,
                      ),
                      _buildWasteCategoryOption(
                        'inorganic',
                        'Inorganic',
                        Icons.delete,
                      ),
                      _buildWasteCategoryOption(
                        'mixed',
                        'Mixed',
                        Icons.recycling,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWasteCategoryOption(String value, String label, IconData icon) {
    final isSelected = _wasteCategory == value;

    return InkWell(
      onTap: () {
        setState(() => _wasteCategory = value);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color:
              isSelected ? primaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? primaryColor : Colors.grey[600],
              size: 28,
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? primaryColor : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Driver Assignment', Icons.person),
          SizedBox(height: 16),

          // Driver selection
          _isLoadingDrivers
              ? Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                    SizedBox(height: 16),
                    Text('Loading available drivers...'),
                  ],
                ),
              )
              : Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Driver',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 16),

                      if (_drivers.isEmpty)
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.person_off,
                                size: 48,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No drivers available',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Please add drivers to the system first',
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _selectedDriverId,
                              hint: Text('Choose a driver'),
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: primaryColor,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _selectedDriverId = value;
                                  // Find the selected driver and populate fields
                                  if (value != null) {
                                    final selectedDriver = _drivers.firstWhere(
                                      (driver) => driver.uid == value,
                                      orElse:
                                          () => UserModel(
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
                                    _driverNameController.text =
                                        selectedDriver.name;
                                    _driverContactController.text =
                                        selectedDriver.contactNumber;

                                    // Use the driver's ID as the truck ID
                                    _truckIdController.text =
                                        'TRUCK-${selectedDriver.uid.substring(0, 6)}';
                                  } else {
                                    _driverNameController.text = '';
                                    _driverContactController.text = '';
                                    _truckIdController.text = '';
                                  }
                                });
                              },
                              items:
                                  _drivers.map((driver) {
                                    return DropdownMenuItem<String>(
                                      value: driver.uid,
                                      child: Text(driver.name),
                                    );
                                  }).toList(),
                            ),
                          ),
                        ),

                      if (_selectedDriverId != null) ...[
                        SizedBox(height: 24),
                        _buildDriverDetailsCard(),
                      ],
                    ],
                  ),
                ),
              ),

          SizedBox(height: 32),

          // Summary card
          if (_startPoint != null &&
              _endPoint != null &&
              _nameController.text.isNotEmpty)
            Card(
              color: primaryColor.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: primaryColor),
                        SizedBox(width: 8),
                        Text(
                          'Route Summary',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                    Divider(color: primaryColor.withOpacity(0.3)),
                    SizedBox(height: 8),

                    _buildSummaryItem('Route Name', _nameController.text),
                    _buildSummaryItem(
                      'Collection',
                      _scheduleFrequency.toUpperCase(),
                    ),
                    if (_scheduleFrequency != 'once' &&
                        _selectedDays.isNotEmpty)
                      _buildSummaryItem(
                        'Days',
                        _selectedDays
                            .map(
                              (day) =>
                                  [
                                    'Sun',
                                    'Mon',
                                    'Tue',
                                    'Wed',
                                    'Thu',
                                    'Fri',
                                    'Sat',
                                  ][day],
                            )
                            .join(', '),
                      ),
                    _buildSummaryItem(
                      'Time Window',
                      '${_getFormattedTime(_scheduleStartTime)} - ${_getFormattedTime(_scheduleEndTime)}',
                    ),
                    _buildSummaryItem(
                      'Waste Type',
                      _wasteCategory.toUpperCase(),
                    ),
                    if (_selectedDriverId != null)
                      _buildSummaryItem('Driver', _driverNameController.text),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDriverDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Driver Details',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 12),

          Row(
            children: [
              CircleAvatar(
                backgroundColor: primaryColor.withOpacity(0.2),
                child: Icon(Icons.person, color: primaryColor),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _driverNameController.text,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (_driverContactController.text.isNotEmpty)
                      Text(
                        _driverContactController.text,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Divider(),
          SizedBox(height: 8),

          Row(
            children: [
              Icon(Icons.local_shipping, color: primaryColor, size: 18),
              SizedBox(width: 8),
              Text('Truck ID:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(width: 8),
              Text(_truckIdController.text),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, String status, bool isComplete) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isComplete ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isComplete ? Colors.green[200]! : Colors.orange[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
          SizedBox(height: 4),
          Text(
            status,
            style: TextStyle(
              color: isComplete ? Colors.green[700] : Colors.orange[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: primaryColor),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    required IconData prefixIcon,
    String? hintText,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: Icon(prefixIcon, color: primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        floatingLabelStyle: TextStyle(color: primaryColor),
      ),
      maxLines: maxLines,
      validator: validator,
    );
  }

  Widget _buildFrequencyOption(String value, String label, IconData icon) {
    return InkWell(
      onTap: () {
        setState(() {
          _scheduleFrequency = value;
        });
      },
      child: Row(
        children: [
          Radio<String>(
            value: value,
            groupValue: _scheduleFrequency,
            onChanged: (newValue) {
              setState(() {
                _scheduleFrequency = newValue!;
              });
            },
            activeColor: primaryColor,
          ),
          Icon(icon, color: primaryColor),
          SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
