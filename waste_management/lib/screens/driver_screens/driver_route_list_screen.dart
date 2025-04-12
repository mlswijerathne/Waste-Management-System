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
  RouteModel? _activeRoute;
  List<RouteModel> _todayRoutes = [];
  DateTime _selectedDate = DateTime.now();
  int _currentDayIndex = DateTime.now().weekday % 7; // 0=Sun, 1=Mon,...6=Sat
  
  // Define primary color
  final Color primaryColor = const Color(0xFF59A867);

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
      });

      await _checkActiveRoute();
      await _loadTodayRoutes();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading driver data: $e')),
      );
    }
  }

  Future<void> _loadTodayRoutes() async {
    if (_driverId == null) return;
    
    try {
      // Get weekly schedule and extract just today's routes
      final weeklySchedule = await _routeService.getDriverWeeklySchedule(_driverId!);
      setState(() {
        _todayRoutes = weeklySchedule[_currentDayIndex] ?? [];
      });
    } catch (e) {
      print('Error loading today\'s routes: $e');
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

  String _getDayName(int index) {
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return days[index];
  }

  Widget _buildActiveRouteCard() {
    final route = _activeRoute!;
    String status = "Active";
    Color statusColor = primaryColor;
    
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
      margin: const EdgeInsets.all(12.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: statusColor, width: 2.0),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: () => _navigateToRouteDetail(route),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      route.isActive ? Icons.directions_car : 
                      route.isPaused ? Icons.pause :
                      route.completedAt != null ? Icons.check_circle :
                      Icons.cancel,
                      size: 24,
                      color: statusColor
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "CURRENT ROUTE",
                          style: TextStyle(
                            fontSize: 12.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          route.name,
                          style: const TextStyle(
                            fontSize: 20.0,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              
              // Waste category badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (route.wasteCategory == 'organic' ? Colors.brown : Colors.blue).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: route.wasteCategory == 'organic' ? Colors.brown : Colors.blue),
                ),
                child: Text(
                  route.wasteCategory == 'organic' ? 'ORGANIC WASTE' : 'INORGANIC WASTE',
                  style: TextStyle(
                    color: route.wasteCategory == 'organic' ? Colors.brown : Colors.blue,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              const SizedBox(height: 16.0),
              
              // Route details with improved readability
              _buildInfoRow(Icons.route, 'Total Distance', '${route.distance.toStringAsFixed(1)} km'),
              const SizedBox(height: 8.0),
              _buildInfoRow(Icons.access_time, 'Started', _formatDateTime(route.startedAt ?? route.createdAt)),
              
              if (route.isActive) ...[
                const SizedBox(height: 16.0),
                
                // Progress bar for active routes
                Text(
                  'PROGRESS: ${route.currentProgressPercentage?.toStringAsFixed(1) ?? '0.0'}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8.0),
                LinearProgressIndicator(
                  value: (route.currentProgressPercentage ?? 0) / 100,
                  minHeight: 10,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  borderRadius: BorderRadius.circular(5),
                ),
              ],
              
              const SizedBox(height: 20.0),
              ElevatedButton.icon(
                onPressed: () => _navigateToRouteDetail(route),
                icon: Icon(
                  route.isActive ? Icons.play_arrow : Icons.visibility,
                  color: Colors.white,
                ),
                label: Text(
                  route.isActive ? 'CONTINUE THIS ROUTE' : 'VIEW ROUTE DETAILS',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: statusColor,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20.0, color: Colors.grey[700]),
        const SizedBox(width: 8.0),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 16.0,
            color: Colors.grey[800],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildRouteCard(RouteModel route) {
    String status = "Scheduled";
    Color statusColor = Colors.blue;
    IconData statusIcon = Icons.access_time;
    
    if (route.isActive) {
      status = "Active";
      statusColor = primaryColor;
      statusIcon = Icons.directions_car;
    } else if (route.isPaused) {
      status = "Paused";
      statusColor = Colors.orange;
      statusIcon = Icons.pause;
    } else if (route.completedAt != null) {
      status = "Completed";
      statusColor = Colors.grey;
      statusIcon = Icons.check_circle;
    } else if (route.cancelledAt != null) {
      status = "Cancelled";
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
    }
    
    // Get waste category color
    Color categoryColor = route.wasteCategory == 'organic' ? Colors.brown : Colors.blue;
    String categoryText = route.wasteCategory == 'organic' ? 'ORGANIC' : 'INORGANIC';

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: InkWell(
        onTap: () => _navigateToRouteDetail(route),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(statusIcon, size: 20, color: statusColor),
                  ),
                  const SizedBox(width: 12),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12.0),
              
              // Waste category badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: categoryColor),
                ),
                child: Text(
                  '$categoryText WASTE',
                  style: TextStyle(
                    color: categoryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              const SizedBox(height: 12.0),
              
              // Route time and distance information
              Row(
                children: [
                  Icon(Icons.route, size: 18.0, color: Colors.grey[600]),
                  const SizedBox(width: 6.0),
                  Text(
                    '${route.distance.toStringAsFixed(1)} km',
                    style: TextStyle(
                      fontSize: 14.0,
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  Icon(Icons.access_time, size: 18.0, color: Colors.grey[600]),
                  const SizedBox(width: 6.0),
                  Text(
                    '${_formatTime(route.scheduleStartTime)} - ${_formatTime(route.scheduleEndTime)}',
                    style: TextStyle(
                      fontSize: 14.0,
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              
              // Show action buttons based on route status
              if (!route.isActive && !route.isCancelled && route.completedAt == null && _activeRoute == null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: ElevatedButton.icon(
                    onPressed: () => _startRoute(route),
                    icon: const Icon(Icons.play_arrow, color: Colors.white),
                    label: const Text(
                      'START ROUTE',
                      style: TextStyle(
                        fontSize: 14.0,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                
              // Show restart button if route is completed and can be restarted
              if (route.completedAt != null && !route.isCancelled && _activeRoute == null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: ElevatedButton.icon(
                    onPressed: () => _startRoute(route),
                    icon: const Icon(Icons.replay, color: Colors.white),
                    label: const Text(
                      'RESTART ROUTE',
                      style: TextStyle(
                        fontSize: 14.0,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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

  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('h:mm a').format(dt);
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return DateFormat('MMM d, HH:mm').format(dateTime);
  }

  String _formatDate(DateTime dateTime) {
    return DateFormat('MMM d, yyyy').format(dateTime);
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
        SnackBar(
          content: Text(route.completedAt != null 
            ? 'Route restarted successfully' 
            : 'Route started successfully'),
          backgroundColor: primaryColor,
        ),
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
      _loadTodayRoutes();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: primaryColor,
          ),
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

    final todayName = _getDayName(_currentDayIndex);
    final hasNoRoutes = _activeRoute == null && _todayRoutes.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Today\'s Routes', style: TextStyle(fontSize: 20)),
            Text(
              todayName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Routes',
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _loadDriverData();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDriverData,
        color: primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Active route section
              if (_activeRoute != null) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
                  child: Text(
                    'ACTIVE ROUTE',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
                _buildActiveRouteCard(),
                const SizedBox(height: 24),
              ],
              
              // Today's scheduled routes
              Padding(
                padding: const EdgeInsets.only(left: 4.0, bottom: 8.0, top: 4.0),
                child: Row(
                  children: [
                    Text(
                      'TODAY\'S ROUTES',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_todayRoutes.where((r) => r.id != _activeRoute?.id).length}',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              if (hasNoRoutes)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 50.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No routes scheduled for today',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pull down to refresh',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _todayRoutes.length,
                  itemBuilder: (context, index) {
                    final route = _todayRoutes[index];
                    if (_activeRoute != null && route.id == _activeRoute!.id) {
                      return const SizedBox.shrink();
                    }
                    return _buildRouteCard(route);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}