import 'package:flutter/material.dart';
import 'package:waste_management/models/routeModel.dart';
import 'package:waste_management/screens/city_management_screens/admin_route_detail_screen.dart';
import 'package:waste_management/service/route_service.dart';
import 'package:intl/intl.dart';

class AdminRouteListScreen extends StatefulWidget {
  const AdminRouteListScreen({Key? key}) : super(key: key);

  @override
  _AdminRouteListScreenState createState() => _AdminRouteListScreenState();
}

class _AdminRouteListScreenState extends State<AdminRouteListScreen> {
  final RouteService _routeService = RouteService();
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    try {
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Waste Collection Routes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.pushNamed(context, '/admin_create_route').then((_) => setState(() {}));
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage'))
              : _buildRoutesList(),
    );
  }

  Widget _buildRoutesList() {
    return StreamBuilder<List<RouteModel>>(
      stream: _routeService.getRoutes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No routes found. Create a new route.'));
        }

        final routes = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView.builder(
            itemCount: routes.length,
            itemBuilder: (context, index) => _buildRouteCard(routes[index]),
          ),
        );
      },
    );
  }

  Widget _buildRouteCard(RouteModel route) {
    final dateFormat = DateFormat('MMM dd, yyyy - hh:mm a');
    final createdDate = dateFormat.format(route.createdAt);

    Color statusColor = Colors.grey;
    String statusText = 'Inactive';
    if (route.isCancelled) {
      statusColor = Colors.red;
      statusText = 'Cancelled';
    } else if (route.completedAt != null) {
      statusColor = Colors.green;
      statusText = 'Completed';
    } else if (route.isActive) {
      statusColor = route.isPaused ? Colors.amber : Colors.blue;
      statusText = route.isPaused ? 'Paused' : 'Active';
    } else if (route.assignedDriverId != null) {
      statusColor = Colors.purple;
      statusText = 'Assigned';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => RouteDetailScreen(routeId: route.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      route.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(statusText, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                route.description,
                style: TextStyle(color: Colors.grey[600]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('${route.distance.toStringAsFixed(1)} km'),
                  const SizedBox(width: 16),
                  Text('Created: $createdDate'),
                ],
              ),
              const SizedBox(height: 4),
              Text('Category: ${route.wasteCategory.toUpperCase()}'),
              const SizedBox(height: 4),
              Text('Schedule: ${route.scheduleFrequency.toUpperCase()}'),
              if (route.assignedDriverId != null && route.driverName != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text('Driver: ${route.driverName}'),
                  ],
                ),
              ],
              if (route.isActive && route.currentProgressPercentage != null) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: route.currentProgressPercentage! / 100,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                const SizedBox(height: 4),
                Text('Progress: ${route.currentProgressPercentage!.toStringAsFixed(1)}%'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
