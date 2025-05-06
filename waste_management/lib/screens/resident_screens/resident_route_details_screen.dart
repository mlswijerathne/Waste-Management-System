import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:waste_management/models/routeModel.dart';
import 'package:waste_management/service/route_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:geolocator/geolocator.dart';
import 'dart:math';

class RouteDetailsScreen extends StatefulWidget {
  final String routeId;

  const RouteDetailsScreen({Key? key, required this.routeId}) : super(key: key);

  @override
  State<RouteDetailsScreen> createState() => _RouteDetailsScreenState();
}

class _RouteDetailsScreenState extends State<RouteDetailsScreen> {
  final RouteService _routeService = RouteService();
  GoogleMapController? _mapController;
  RouteModel? _route;
  LatLng? _truckPosition;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  BitmapDescriptor? _truckIcon;
  bool _isLoading = true;
  double _completion = 0;
  Map<String, dynamic>? _timeEstimation;
  StreamSubscription? _progressSubscription;
  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _refreshTimer;

  final Color primaryColor = const Color(0xFF59A867);

  @override
  void initState() {
    super.initState();
    // Load truck icon first to ensure it's ready when we need it
    _loadTruckIcon().then((_) {
      _loadRouteData();
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _progressSubscription?.cancel();
    _refreshTimer?.cancel();
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadTruckIcon() async {
    try {
      // More reliable approach: Load asset as bytes with explicit size
      final ByteData data = await rootBundle.load(
        'assets/icons/truck_icon.png',
      );
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 110, // Larger size for better visibility
        targetHeight: 110,
      );
      final ui.FrameInfo fi = await codec.getNextFrame();
      final Uint8List markerIcon =
          (await fi.image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!.buffer.asUint8List();

      _truckIcon = BitmapDescriptor.fromBytes(markerIcon);
      print('Truck icon loaded successfully from bytes with size 110x110');

      // Update truck marker if we already have a position
      if (_truckPosition != null && mounted) {
        setState(() {
          _updateTruckMarker(_truckPosition!);
        });
      }
      return;
    } catch (e) {
      print('Error loading truck icon from bytes: $e');
      // Continue to next approach
    }

    try {
      // Second attempt with different configuration
      final ImageConfiguration imageConfig = ImageConfiguration(
        size: const Size(80, 80),
        devicePixelRatio: MediaQuery.of(context).devicePixelRatio,
      );

      _truckIcon = await BitmapDescriptor.fromAssetImage(
        imageConfig,
        'assets/icons/truck_icon.png',
      );
      print('Loaded truck icon from asset image with custom configuration');

      if (_truckPosition != null && mounted) {
        setState(() {
          _updateTruckMarker(_truckPosition!);
        });
      }
      return;
    } catch (e) {
      print('Error loading truck icon from asset image: $e');
      // Fall back to default marker
    }

    // Fallback to default marker
    _truckIcon = BitmapDescriptor.defaultMarkerWithHue(
      BitmapDescriptor.hueOrange,
    );
    print('Using default orange marker as fallback');

    if (_truckPosition != null && mounted) {
      setState(() {
        _updateTruckMarker(_truckPosition!);
      });
    }
  }

  Future<Uint8List> _getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
    );
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
  }

  Future<void> _loadRouteData() async {
    try {
      final route = await _routeService.getRoute(widget.routeId);
      final estimation = await _routeService.getRouteTimeEstimation(
        widget.routeId,
      );

      if (route == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Route not found')));
        Navigator.pop(context);
        return;
      }

      _route = route;
      _completion = estimation['completionPercentage'] ?? 0.0;
      _timeEstimation = estimation;

      // Set up path polyline
      final List<LatLng> path =
          route.actualDirectionPath
              .map((e) => LatLng(e['lat'] ?? 0.0, e['lng'] ?? 0.0))
              .toList();

      if (path.isNotEmpty) {
        _polylines.add(
          Polyline(
            polylineId: PolylineId('route_${route.id}'),
            color: primaryColor,
            width: 5,
            points: path,
          ),
        );
      }

      // Add start and end markers
      _markers.add(
        Marker(
          markerId: const MarkerId('start'),
          position: LatLng(route.startLat, route.startLng),
          infoWindow: const InfoWindow(title: 'Start'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );

      _markers.add(
        Marker(
          markerId: const MarkerId('end'),
          position: LatLng(route.endLat, route.endLng),
          infoWindow: const InfoWindow(title: 'End'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );

      // Set up real-time truck position listener
      _setupTruckPositionListener();

      _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
        final newEstimation = await _routeService.getRouteTimeEstimation(
          widget.routeId,
        );
        if (mounted) {
          setState(() {
            _timeEstimation = newEstimation;
            _completion = newEstimation['completionPercentage'] ?? 0.0;
          });
        }
      });

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading route data: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading route: $e')));
      }
      setState(() => _isLoading = false);
    }
  }

  void _setupTruckPositionListener() {
    // Cancel any existing subscriptions
    _progressSubscription?.cancel();
    _positionStreamSubscription?.cancel();

    // Set up new subscription to route progress
    _progressSubscription = _routeService
        .getRouteProgress(widget.routeId)
        .listen(
          (position) {
            if (position != null && mounted) {
              // Validate position - ignore invalid coordinates
              if (position.latitude == 0.0 && position.longitude == 0.0) {
                print('⚠ Ignored invalid truck position: $position');
                return;
              }

              print(
                '📍 Received truck position update: ${position.latitude}, ${position.longitude}',
              );

              setState(() {
                _truckPosition = position;
                _updateTruckMarker(position);
              });
            } else {
              print('ℹ️ No position data received from route progress');

              // If no position received but route is active, use start point as fallback
              if (_route != null &&
                  _route!.isActive &&
                  _truckPosition == null &&
                  mounted) {
                setState(() {
                  _truckPosition = LatLng(_route!.startLat, _route!.startLng);
                  _updateTruckMarker(_truckPosition!);
                });
              }
            }
          },
          onError: (e) {
            print('Error in route position stream: $e');
          },
        );

    // Add a periodic position refresh as a backup to the stream
    // This will ensure we get updates even if the stream isn't firing frequently enough
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      try {
        // Get the latest position data manually
        final progressDoc = await _routeService.getRouteProgressState(
          widget.routeId,
        );

        if (progressDoc != null &&
            progressDoc['currentLat'] != null &&
            progressDoc['currentLng'] != null) {
          final newPosition = LatLng(
            progressDoc['currentLat'],
            progressDoc['currentLng'],
          );

          // Only update if position has changed
          if (_truckPosition == null ||
              _truckPosition!.latitude != newPosition.latitude ||
              _truckPosition!.longitude != newPosition.longitude) {
            if (mounted) {
              setState(() {
                _truckPosition = newPosition;
                _updateTruckMarker(newPosition);
              });
            }
          }
        }
      } catch (e) {
        print('Error in periodic position refresh: $e');
      }
    });
  }

  // Calculate bearing between two points (for truck rotation)
  double _getBearing(LatLng start, LatLng end) {
    final startLat = start.latitude * (pi / 180);
    final startLng = start.longitude * (pi / 180);
    final endLat = end.latitude * (pi / 180);
    final endLng = end.longitude * (pi / 180);

    final dLon = endLng - startLng;

    final y = sin(dLon) * cos(endLat);
    final x =
        cos(startLat) * sin(endLat) - sin(startLat) * cos(endLat) * cos(dLon);

    final bearing = atan2(y, x);

    // Convert to degrees
    final bearingDegrees = bearing * (180 / pi);
    return (bearingDegrees + 360) % 360;
  }

  void _updateTruckMarker(LatLng position) {
    // Sanitize location - never use zero coordinates
    if (position.latitude == 0.0 &&
        position.longitude == 0.0 &&
        _route != null) {
      position = LatLng(_route!.startLat, _route!.startLng);
    }

    // Calculate rotation angle if we have a previous position
    double rotation = 0.0;

    final previousTruckMarker = _markers.firstWhere(
      (marker) => marker.markerId.value == 'truck',
      orElse: () => Marker(markerId: const MarkerId('dummy')),
    );

    if (previousTruckMarker.markerId.value != 'dummy') {
      rotation = _getBearing(previousTruckMarker.position, position);
    }

    // Remove old truck marker and add new one
    _markers.removeWhere((m) => m.markerId.value == 'truck');
    _markers.add(
      Marker(
        markerId: const MarkerId('truck'),
        position: position,
        icon:
            _truckIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(
          title: 'Truck',
          snippet:
              _route?.driverName != null
                  ? 'Driver: ${_route!.driverName}'
                  : null,
        ),
        rotation: rotation,
        anchor: const Offset(0.5, 0.5),
        zIndex: 2,
      ),
    );
  }

  void _focusOnTruck() {
    if (_truckPosition != null &&
        _truckPosition!.latitude != 0.0 &&
        _truckPosition!.longitude != 0.0) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_truckPosition!, 16),
      );
    } else if (_route != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_route!.startLat, _route!.startLng),
          14,
        ),
      );
    }
  }

  void _focusOnRoute() {
    if (_route == null || _mapController == null) return;

    // Include start, end, and current truck position
    List<LatLng> points = [
      LatLng(_route!.startLat, _route!.startLng),
      LatLng(_route!.endLat, _route!.endLng),
    ];

    // Add truck position if available and valid
    if (_truckPosition != null &&
        (_truckPosition!.latitude != 0.0 || _truckPosition!.longitude != 0.0)) {
      points.add(_truckPosition!);
    }

    // Calculate bounds
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (var point in points) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }

    // Add padding
    final padding = 0.01; // ~1km
    minLat -= padding;
    maxLat += padding;
    minLng -= padding;
    maxLng += padding;

    // Move camera to show all points
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        50, // padding in pixels
      ),
    );
  }

  void _callDriver() async {
    final contact = _route?.driverContact;
    if (contact != null && contact.isNotEmpty) {
      final Uri phoneUri = Uri.parse("tel:$contact");
      if (await url_launcher.canLaunchUrl(phoneUri)) {
        await url_launcher.launchUrl(phoneUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Can't call $contact")));
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No driver contact available")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_route?.name ?? "Route Details"),
        backgroundColor: primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _focusOnTruck,
            tooltip: 'Follow truck',
          ),
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: _focusOnRoute,
            tooltip: 'View entire route',
          ),
          if (_route?.driverContact != null)
            IconButton(
              icon: const Icon(Icons.phone),
              onPressed: _callDriver,
              tooltip: 'Call driver',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRouteData,
            tooltip: 'Refresh data',
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator(color: primaryColor))
              : Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target:
                          _truckPosition ??
                          LatLng(_route!.startLat, _route!.startLng),
                      zoom: 14,
                    ),
                    markers: _markers,
                    polylines: _polylines,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: true,
                    onMapCreated: (controller) {
                      _mapController = controller;

                      // Initial camera position - focus on truck or on route
                      if (_truckPosition != null) {
                        controller.animateCamera(
                          CameraUpdate.newLatLngZoom(_truckPosition!, 15),
                        );
                      } else {
                        _focusOnRoute();
                      }
                    },
                  ),
                  Positioned(
                    bottom: 20,
                    left: 16,
                    right: 16,
                    child: _buildInfoCard(),
                  ),
                ],
              ),
    );
  }

  Widget _buildInfoCard() {
    String driverInfo = _route?.driverName ?? 'N/A';
    if (_route?.driverContact != null && _route!.driverContact!.isNotEmpty) {
      driverInfo += ' • ${_route!.driverContact}';
    }

    String etaText = "N/A";
    if (_timeEstimation?['estimatedCompletionTime'] != null) {
      etaText = DateFormat(
        'hh:mm a',
      ).format(_timeEstimation!['estimatedCompletionTime']);
    }

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Progress: ${_completion.toStringAsFixed(1)}%",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  "ETA: $etaText",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _completion / 100,
              backgroundColor: Colors.grey[300],
              color: primaryColor,
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Driver: $driverInfo",
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                if (_route?.driverContact != null)
                  TextButton.icon(
                    icon: const Icon(Icons.phone, size: 16),
                    label: const Text("CALL"),
                    onPressed: _callDriver,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),

            if (_route?.wasteCategory != null) ...[
              const Divider(height: 16),
              Row(
                children: [
                  Icon(
                    _route!.wasteCategory == 'organic'
                        ? Icons.eco
                        : Icons.delete,
                    size: 16,
                    color:
                        _route!.wasteCategory == 'organic'
                            ? Colors.green
                            : Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Waste Type: ${_route!.wasteCategory.toUpperCase()}",
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          _route!.wasteCategory == 'organic'
                              ? Colors.green
                              : Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
