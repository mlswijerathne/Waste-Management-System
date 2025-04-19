// All previous imports remain
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
  Timer? _refreshTimer;

  final Color primaryColor = const Color(0xFF59A867);

  @override
  void initState() {
    super.initState();
    _loadTruckIcon();
    _loadRouteData();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _progressSubscription?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTruckIcon() async {
    try {
      final Uint8List markerIcon = await _getBytesFromAsset('assets/icons/truck_icon.png', 80);
      _truckIcon = BitmapDescriptor.fromBytes(markerIcon);
    } catch (_) {
      _truckIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }
  }

  Future<Uint8List> _getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  }

  Future<void> _loadRouteData() async {
    try {
      final route = await _routeService.getRoute(widget.routeId);
      final estimation = await _routeService.getRouteTimeEstimation(widget.routeId);

      if (route == null) {
        Navigator.pop(context);
        return;
      }

      _route = route;
      _completion = estimation['completionPercentage'] ?? 0.0;
      _timeEstimation = estimation;

      final List<LatLng> path = route.actualDirectionPath
          .map((e) => LatLng(e['lat'] ?? 0.0, e['lng'] ?? 0.0))
          .toList();

      if (path.isNotEmpty) {
        _polylines.add(Polyline(
          polylineId: PolylineId('route_${route.id}'),
          color: primaryColor,
          width: 5,
          points: path,
        ));
      }

      _markers.add(Marker(
        markerId: const MarkerId('start'),
        position: LatLng(route.startLat, route.startLng),
        infoWindow: const InfoWindow(title: 'Start'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));

      _markers.add(Marker(
        markerId: const MarkerId('end'),
        position: LatLng(route.endLat, route.endLng),
        infoWindow: const InfoWindow(title: 'End'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));

      _progressSubscription = _routeService.getRouteProgress(widget.routeId).listen((position) {
        if (position != null &&
            position.latitude != 0.0 &&
            position.longitude != 0.0 &&
            mounted) {
          setState(() {
            _truckPosition = position;
            _updateTruckMarker(position);
          });
        } else {
          print('⚠ Ignored invalid truck position: $position');
        }
      });

      _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
        final newEstimation = await _routeService.getRouteTimeEstimation(widget.routeId);
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
      setState(() => _isLoading = false);
    }
  }

  void _updateTruckMarker(LatLng pos) {
    // Sanitize location
    if (pos.latitude == 0.0 && pos.longitude == 0.0) {
      if (_route != null) {
        pos = LatLng(_route!.startLat, _route!.startLng);
      } else {
        return;
      }
    }

    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'truck');
      _markers.add(
        Marker(
          markerId: const MarkerId('truck'),
          position: pos,
          icon: _truckIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: const InfoWindow(title: 'Truck'),
          rotation: 0.0,
          anchor: const Offset(0.5, 0.5),
          zIndex: 2,
        ),
      );
    });
  }

  void _focusOnTruck() {
    if (_truckPosition != null && _truckPosition!.latitude != 0.0 && _truckPosition!.longitude != 0.0) {
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_truckPosition!, 16));
    } else if (_route != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(_route!.startLat, _route!.startLng), 14),
      );
    }
  }

  void _callDriver() async {
    final contact = _route?.driverContact;
    if (contact != null && contact.isNotEmpty) {
      final Uri phoneUri = Uri.parse("tel:$contact");
      if (await url_launcher.canLaunchUrl(phoneUri)) {
        await url_launcher.launchUrl(phoneUri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Can't call $contact")));
      }
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
          ),
          if (_route?.driverContact != null)
            IconButton(
              icon: const Icon(Icons.phone),
              onPressed: _callDriver,
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(_route!.startLat, _route!.startLng),
                    zoom: 14,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                  onMapCreated: (controller) => _mapController = controller,
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
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Progress: ${_completion.toStringAsFixed(1)}%",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _completion / 100,
              backgroundColor: Colors.grey[300],
              color: primaryColor,
              minHeight: 10,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Driver: ${_route?.driverName ?? 'N/A'}"),
                Text("ETA: ${_timeEstimation?['estimatedCompletionTime'] != null ? DateFormat('hh:mm a').format(_timeEstimation!['estimatedCompletionTime']) : 'N/A'}"),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
