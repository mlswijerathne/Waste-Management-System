import 'package:flutter/material.dart';
import 'package:waste_management/models/routeModel.dart';
import 'package:waste_management/service/route_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

class RouteDetailScreen extends StatefulWidget {
  final String routeId;

  const RouteDetailScreen({Key? key, required this.routeId}) : super(key: key);

  @override
  _RouteDetailScreenState createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  final RouteService _routeService = RouteService();
  RouteModel? _route;
  bool _isLoading = true;
  String? _errorMessage;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _loadRouteDetails();
  }

  Future<void> _loadRouteDetails() async {
    try {
      final route = await _routeService.getRoute(widget.routeId);
      if (route == null) throw Exception('Route not found');
      _prepareMapData(route);
      setState(() {
        _route = route;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _prepareMapData(RouteModel route) {
    _markers.clear();
    _polylines.clear();
    _markers.add(Marker(markerId: MarkerId('start'), position: LatLng(route.startLat, route.startLng)));
    _markers.add(Marker(markerId: MarkerId('end'), position: LatLng(route.endLat, route.endLng)));
    if (route.actualDirectionPath.isNotEmpty) {
      _polylines.add(Polyline(
        polylineId: PolylineId('route'),
        points: route.actualDirectionPath.map((p) => LatLng(p['lat'] ?? 0.0, p['lng'] ?? 0.0)).toList(),
        color: Colors.blue,
        width: 4,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_route?.name ?? 'Route Details')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage'))
              : _buildDetailView(),
    );
  }

  Widget _buildDetailView() {
    final dateFormat = DateFormat('MMM dd, yyyy - hh:mm a');
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 250,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: LatLng(_route!.startLat, _route!.startLng), zoom: 13),
              markers: _markers,
              polylines: _polylines,
              onMapCreated: (controller) => _mapController = controller,
            ),
          ),
          SizedBox(height: 16),
          _infoRow('Route Name', _route!.name),
          _infoRow('Description', _route!.description),
          _infoRow('Distance', '${_route!.distance.toStringAsFixed(1)} km'),
          _infoRow('Created At', dateFormat.format(_route!.createdAt)),
          _infoRow('Waste Category', _route!.wasteCategory.toUpperCase()),
          _infoRow('Schedule Frequency', _route!.scheduleFrequency.toUpperCase()),
          if (_route!.scheduleDays.isNotEmpty)
            _infoRow('Scheduled Days', _route!.scheduleDays.map((d) => ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'][d]).join(', ')),
          _infoRow('Start Time', _route!.scheduleStartTime.format(context)),
          _infoRow('End Time', _route!.scheduleEndTime.format(context)),
          if (_route!.driverName != null)
            _infoRow('Driver', _route!.driverName!),
          if (_route!.truckId != null)
            _infoRow('Truck ID', _route!.truckId!),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text('$label:', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
