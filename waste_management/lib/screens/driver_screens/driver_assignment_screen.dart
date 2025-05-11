import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:waste_management/models/specialGarbageRequestModel.dart';
import 'package:waste_management/screens/driver_screens/driver_cleanliness_issue_tab.dart';
import 'package:waste_management/screens/driver_screens/driver_special_garbage_detail_screen.dart';
import 'package:waste_management/service/auth_service.dart';
import 'package:waste_management/service/special_Garbage_Request_service.dart';
import 'package:waste_management/widgets/driver_navbar.dart';

class DriverAssignmentScreen extends StatefulWidget {
  const DriverAssignmentScreen({Key? key}) : super(key: key);

  @override
  State<DriverAssignmentScreen> createState() => _DriverAssignmentScreenState();
}

class _DriverAssignmentScreenState extends State<DriverAssignmentScreen>
    with SingleTickerProviderStateMixin {
  final SpecialGarbageRequestService _specialGarbageService =
      SpecialGarbageRequestService();
  final AuthService _authService = AuthService();

  late TabController _tabController;

  List<SpecialGarbageRequestModel> _assignedSpecialRequests = [];

  bool _isLoading = true;
  bool _isInitialLoading = true; // Track initial load
  String _driverId = '';
  final Color primaryColor = const Color(0xFF59A867);
  int _currentIndex = 3; // Set current index to 3 for Assignment screen

  // Stream subscriptions for real-time updates
  StreamSubscription<List<SpecialGarbageRequestModel>>?
  _specialRequestsStreamSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _getCurrentDriverId();
  }

  @override
  void dispose() {
    // Cancel stream subscriptions when disposing the widget
    _specialRequestsStreamSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentDriverId() async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        setState(() {
          _driverId = currentUser.uid;
        });
        // Initial load with one-time queries for faster startup
        await _loadAllAssignments();
        // Then set up streams for real-time updates
        _setupStreams();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User not authenticated')));
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      print('Error getting current user: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to load user data')));
    }
  }

  void _setupStreams() {
    // Set up real-time stream for special requests
    _specialRequestsStreamSubscription = _specialGarbageService
        .getDriverRequestsStream(_driverId)
        .listen(
          (requests) {
            if (mounted) {
              setState(() {
                _assignedSpecialRequests = requests;
                _isLoading = false;
              });
            }
          },
          onError: (e) {
            print('Error in special requests stream: $e');
          },
        );
  }

  Future<void> _loadAllAssignments() async {
    if (_driverId.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Load only special requests since cleanliness issues are handled by DriverCleanlinessIssueTab
      await _loadSpecialRequests();
    } catch (e) {
      print('Error loading assignments: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitialLoading = false;
        });
      }
    }
  }

  Future<void> _loadSpecialRequests() async {
    if (_driverId.isEmpty) return;

    try {
      // Use the method that only fetches requests with 'assigned' status
      final requests = await _specialGarbageService.getDriverAssignedRequests(
        _driverId,
      );
      if (mounted) {
        setState(() {
          _assignedSpecialRequests = requests;
        });
      }
    } catch (e) {
      print('Error loading special requests: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load special garbage requests'),
          ),
        );
      }
    }
  } // Force refresh function to manually update data

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });

    // Use one-time load to refresh the data
    await _loadAllAssignments();
  }

  void _setLoading(bool loading) {
    if (mounted) {
      setState(() {
        _isLoading = loading;
      });
    }
  }

  String _formatDate(DateTime dateTime) {
    return DateFormat('d MMM yyyy').format(dateTime);
  }

  // Add onTabTapped method to handle navigation
  void _onTabTapped(int index) {
    if (index == _currentIndex)
      return; // Don't navigate if we're already on this tab

    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'My Assignments',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: primaryColor),
            onPressed: _refreshData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryColor,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey[600],
          tabs: const [
            Tab(
              icon: Icon(Icons.cleaning_services),
              text: 'Cleanliness Issues',
            ),
            Tab(icon: Icon(Icons.recycling), text: 'Special Requests'),
          ],
        ),
      ),
      body:
          _isInitialLoading
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: primaryColor),
                    SizedBox(height: 16),
                    Text(
                      'Loading your assignments...',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
              : TabBarView(
                controller: _tabController,
                children: [
                  // Cleanliness Issues Tab - Use the new separated component
                  DriverCleanlinessIssueTab(
                    driverId: _driverId,
                    setLoading: _setLoading,
                  ),

                  // Special Requests Tab
                  _assignedSpecialRequests.isEmpty
                      ? _buildEmptyState(
                        'No Special Requests',
                        'You have no special garbage requests assigned to you',
                        Icons.recycling_outlined,
                        _refreshData,
                      )
                      : _buildSpecialRequestsList(),
                ],
              ),
      bottomNavigationBar: DriversNavbar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }

  Widget _buildEmptyState(
    String title,
    String message,
    IconData icon,
    Function() onRefresh,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialRequestsList() {
    return RefreshIndicator(
      onRefresh: _loadSpecialRequests,
      color: primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(12.0),
        itemCount: _assignedSpecialRequests.length,
        itemBuilder: (context, index) {
          final request = _assignedSpecialRequests[index];
          return _buildRequestCard(request);
        },
      ),
    );
  }

  Widget _buildRequestCard(SpecialGarbageRequestModel request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) =>
                      DriverSpecialGarbageDetailScreen(requestId: request.id),
            ),
          ).then((_) => _loadSpecialRequests());
        },
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: Colors.blue, width: 6.0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Type: ${request.garbageType}',
                              style: const TextStyle(
                                fontSize: 16.0,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 4.0,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Text(
                        request.status.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        request.location,
                        style: TextStyle(
                          fontSize: 14.0,
                          color: Colors.grey[700],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Resident: ${request.residentName}',
                      style: TextStyle(fontSize: 13.0, color: Colors.grey[600]),
                    ),
                    if (request.estimatedWeight != null)
                      Text(
                        'Weight: ${request.estimatedWeight} kg',
                        style: TextStyle(
                          fontSize: 13.0,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Assigned: ${_formatDate(request.assignedTime!)}',
                      style: TextStyle(fontSize: 12.0, color: Colors.grey[500]),
                    ),
                    Text(
                      'ID: #${request.id.substring(0, 8)}',
                      style: TextStyle(fontSize: 12.0, color: Colors.grey[500]),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildActionButton(
                      'View Details',
                      Icons.visibility,
                      Colors.blue,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => DriverSpecialGarbageDetailScreen(
                                  requestId: request.id,
                                ),
                          ),
                        ).then((_) => _loadSpecialRequests());
                      },
                    ),
                    _buildActionButton(
                      'Navigate',
                      Icons.directions,
                      Colors.amber,
                      () {
                        // Launch maps app
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Opening navigation...'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(40, 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
