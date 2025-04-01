// driver_route_list_screen.dart (updated)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:waste_management/models/routeModel.dart';
import 'package:waste_management/screens/driver_screens/driver_route_action_screen.dart';
import 'package:waste_management/service/auth_service.dart';
import 'package:waste_management/service/route_service.dart';

class DriverRouteListScreen extends StatefulWidget {
  const DriverRouteListScreen({Key? key}) : super(key: key);

  @override
  _DriverRouteListScreenState createState() => _DriverRouteListScreenState();
}

class _DriverRouteListScreenState extends State<DriverRouteListScreen> {
  final RouteService _routeService = RouteService();
  final AuthService _authService = AuthService();
  String? _driverId;
  bool _isLoading = true;
  List<RouteModel> _assignedRoutes = [];
  RouteModel? _activeRoute;

  @override
  void initState() {
    super.initState();
    _loadDriverData();
  }

  Future<void> _loadDriverData() async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication error. Please login again.')),
        );
        return;
      }

      setState(() {
        _driverId = currentUser.uid;
        _isLoading = false;
      });

      _checkActiveRoute();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading driver data: $e')),
      );
    }
  }

  Future<void> _checkActiveRoute() async {
    if (_driverId == null) return;
    
    try {
      final activeRoute = await _routeService.getDriverActiveRoute(_driverId!);
      setState(() {
        _activeRoute = activeRoute;
      });
    } catch (e) {
      print('Error checking active route: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_driverId == null) {
      return const Scaffold(
        body: Center(
          child: Text('Authentication error. Please login again.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Routes'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
              _checkActiveRoute();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_activeRoute != null)
            _buildActiveRouteCard(),
          
          Expanded(
            child: StreamBuilder<List<RouteModel>>(
              stream: _routeService.getDriverRoutes(_driverId!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('No routes assigned to you.'),
                  );
                }

                _assignedRoutes = snapshot.data!;
                
                return ListView.builder(
                  itemCount: _assignedRoutes.length,
                  itemBuilder: (context, index) {
                    final route = _assignedRoutes[index];
                    
                    if (_activeRoute != null && route.id == _activeRoute!.id) {
                      return const SizedBox.shrink();
                    }
                    
                    return _buildRouteCard(route);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRouteCard() {
    final route = _activeRoute!;
    String status = "Active";
    Color statusColor = Colors.green;
    
    if (route.isPaused) {
      status = "Paused";
      statusColor = Colors.orange;
    } else if (route.completedAt != null) {
      status = "Completed";
      statusColor = Colors.grey;
    } else if (route.cancelledAt != null) {
      status = "Cancelled";
      statusColor = Colors.red;
    }
    
    return Card(
      elevation: 4.0,
      margin: const EdgeInsets.all(8.0),
      color: statusColor.withOpacity(0.1),
      child: InkWell(
        onTap: () => _navigateToRouteDetail(route),
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
                      style: const TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Text(
                      status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              if (route.isActive) ...[
                Text(
                  'Current activity: ${route.isPaused ? "PAUSED" : "IN PROGRESS"}',
                  style: TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.bold,
                    color: route.isPaused ? Colors.orange : Colors.green[700],
                  ),
                ),
                const SizedBox(height: 8.0),
              ],
              Row(
                children: [
                  const Icon(Icons.route, size: 16.0),
                  const SizedBox(width: 4.0),
                  Text('Distance: ${route.distance.toStringAsFixed(1)} km'),
                ],
              ),
              const SizedBox(height: 4.0),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16.0),
                  const SizedBox(width: 4.0),
                  Text('Started: ${_formatDateTime(route.startedAt ?? route.createdAt)}'),
                ],
              ),
              if (route.isActive) ...[
                const SizedBox(height: 8.0),
                Row(
                  children: [
                    const Icon(Icons.trending_up, size: 16.0),
                    const SizedBox(width: 4.0),
                    Text(
                      'Progress: ${route.currentProgressPercentage?.toStringAsFixed(1) ?? '0.0'}%',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12.0),
              ElevatedButton(
                onPressed: () => _navigateToRouteDetail(route),
                style: ElevatedButton.styleFrom(
                  backgroundColor: statusColor,
                  minimumSize: const Size(double.infinity, 40),
                ),
                child: Text(
                  route.isActive ? 'CONTINUE THIS ROUTE' : 'VIEW ROUTE DETAILS',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteCard(RouteModel route) {
    String status = "Not Started";
    Color statusColor = Colors.blue;
    
    if (route.isActive) {
      status = "Active";
      statusColor = Colors.green;
    } else if (route.completedAt != null) {
      status = "Completed";
      statusColor = Colors.grey;
    } else if (route.cancelledAt != null) {
      status = "Cancelled";
      statusColor = Colors.red;
    }
    
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: InkWell(
        onTap: () => _navigateToRouteDetail(route),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
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
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Text(
                      status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              Row(
                children: [
                  const Icon(Icons.route, size: 16.0),
                  const SizedBox(width: 4.0),
                  Text('${route.distance.toStringAsFixed(1)} km'),
                  const Spacer(),
                  const Icon(Icons.calendar_today, size: 14.0),
                  const SizedBox(width: 4.0),
                  Text(
                    _formatDate(route.createdAt),
                    style: const TextStyle(fontSize: 12.0),
                  ),
                ],
              ),
              
              // Show start button if route is not started or completed (can be restarted)
              if ((route.startedAt == null || route.completedAt != null) && 
                  route.cancelledAt == null && 
                  _activeRoute == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: () => _startRoute(route),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                        ),
                        child: Text(
                          route.completedAt != null ? 'RESTART ROUTE' : 'START ROUTE',
                          style: const TextStyle(fontSize: 12.0),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startRoute(RouteModel route) async {
    try {
      if (route.completedAt != null) {
        await _routeService.restartCompletedRoute(route.id);
      } else {
        await _routeService.startRoute(route.id);
      }
      
      setState(() {
        _activeRoute = route.copyWith(
          isActive: true,
          isPaused: false,
          startedAt: DateTime.now(),
          completedAt: null,
          currentProgressPercentage: 0.0,
        );
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(route.completedAt != null 
          ? 'Route restarted successfully' 
          : 'Route started successfully')),
      );
      
      _navigateToRouteDetail(route);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting route: $e')),
      );
    }
  }

  void _navigateToRouteDetail(RouteModel route) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriverRouteDetailScreen(route: route),
      ),
    ).then((_) {
      setState(() {});
      _checkActiveRoute();
    });
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return DateFormat('MMM d, HH:mm').format(dateTime);
  }

  String _formatDate(DateTime dateTime) {
    return DateFormat('MMM d, yyyy').format(dateTime);
  }
}