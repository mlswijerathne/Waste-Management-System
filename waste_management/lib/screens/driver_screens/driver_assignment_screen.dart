import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:waste_management/models/cleanlinessIssueModel.dart';
import 'package:waste_management/models/specialGarbageRequestModel.dart';
import 'package:waste_management/screens/driver_screens/driver_special_garbage_detail_screen.dart';
import 'package:waste_management/service/auth_service.dart';
import 'package:waste_management/service/cleanliness_issue_service.dart';
import 'package:waste_management/service/special_Garbage_Request_service.dart';
import 'package:waste_management/widgets/driver_navbar.dart'; // Import the DriversNavbar

class DriverAssignmentScreen extends StatefulWidget {
  const DriverAssignmentScreen({Key? key}) : super(key: key);

  @override
  State<DriverAssignmentScreen> createState() => _DriverAssignmentScreenState();
}

class _DriverAssignmentScreenState extends State<DriverAssignmentScreen>
    with SingleTickerProviderStateMixin {
  final CleanlinessIssueService _cleanlinessService = CleanlinessIssueService();
  final SpecialGarbageRequestService _specialGarbageService =
      SpecialGarbageRequestService();
  final AuthService _authService = AuthService();

  late TabController _tabController;

  List<CleanlinessIssueModel> _assignedIssues = [];
  List<SpecialGarbageRequestModel> _assignedSpecialRequests = [];

  bool _isLoading = true;
  String _driverId = '';
  final Color primaryColor = const Color(0xFF59A867);
  int _currentIndex = 3; // Set current index to 3 for Assignment screen

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _getCurrentDriverId();
  }

  @override
  void dispose() {
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
        _loadAllAssignments();
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

  Future<void> _loadAllAssignments() async {
    setState(() {
      _isLoading = true;
    });

    // Load both types of assignments in parallel
    await Future.wait([_loadCleanlinessIssues(), _loadSpecialRequests()]);

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadCleanlinessIssues() async {
    if (_driverId.isEmpty) return;

    try {
      final issues = await _cleanlinessService.getDriverAssignedIssues(
        _driverId,
      );
      setState(() {
        _assignedIssues = issues;
      });
    } catch (e) {
      print('Error loading cleanliness issues: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load cleanliness issues')),
      );
    }
  }

  Future<void> _loadSpecialRequests() async {
    if (_driverId.isEmpty) return;

    try {
      final requests = await _specialGarbageService.getDriverAssignedRequests(
        _driverId,
      );
      setState(() {
        _assignedSpecialRequests = requests;
      });
    } catch (e) {
      print('Error loading special requests: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load special garbage requests'),
        ),
      );
    }
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
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
            onPressed: _loadAllAssignments,
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
          _isLoading
              ? Center(child: CircularProgressIndicator(color: primaryColor))
              : TabBarView(
                controller: _tabController,
                children: [
                  // Cleanliness Issues Tab
                  _assignedIssues.isEmpty
                      ? _buildEmptyState(
                        'No Cleanliness Issues',
                        'When you are assigned to cleanliness issues, they will appear here',
                        Icons.cleaning_services_outlined,
                        _loadCleanlinessIssues,
                      )
                      : _buildCleanlinessIssuesList(),

                  // Special Requests Tab
                  _assignedSpecialRequests.isEmpty
                      ? _buildEmptyState(
                        'No Special Requests',
                        'You have no special garbage requests assigned to you',
                        Icons.recycling_outlined,
                        _loadSpecialRequests,
                      )
                      : _buildSpecialRequestsList(),
                ],
              ),
      bottomNavigationBar: DriversNavbar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ), // Add the navbar
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

  Widget _buildCleanlinessIssuesList() {
    return RefreshIndicator(
      onRefresh: _loadCleanlinessIssues,
      color: primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(12.0),
        itemCount: _assignedIssues.length,
        itemBuilder: (context, index) {
          final issue = _assignedIssues[index];
          return _buildIssueCard(issue);
        },
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

  Widget _buildIssueCard(CleanlinessIssueModel issue) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: InkWell(
        onTap: () => _navigateToIssueDetails(issue),
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: _getStatusColor(issue.status),
                width: 6.0,
              ),
            ),
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
                      child: Text(
                        issue.description,
                        style: const TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusChip(issue.status),
                  ],
                ),
                const SizedBox(height: 8.0),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        issue.location,
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
                      'Reported by: ${issue.residentName}',
                      style: TextStyle(fontSize: 13.0, color: Colors.grey[600]),
                    ),
                    Text(
                      _formatDate(issue.reportedTime),
                      style: TextStyle(fontSize: 12.0, color: Colors.grey[500]),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildActionButton(
                      issue.status == 'assigned'
                          ? 'Start Work'
                          : 'View Details',
                      issue.status == 'assigned'
                          ? Icons.play_arrow
                          : Icons.visibility,
                      issue.status == 'assigned' ? Colors.blue : primaryColor,
                      () => _navigateToIssueDetails(issue),
                    ),
                    if (issue.latitude != 0 && issue.longitude != 0)
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

  Widget _buildStatusChip(String status) {
    String displayStatus = status;

    if (status == 'inProgress') {
      displayStatus = 'IN PROGRESS';
    } else {
      displayStatus = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Text(
        displayStatus,
        style: TextStyle(
          fontSize: 10.0,
          fontWeight: FontWeight.bold,
          color: _getStatusColor(status),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'assigned':
        return Colors.orange;
      case 'inProgress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      default:
        return primaryColor;
    }
  }

  void _navigateToIssueDetails(CleanlinessIssueModel issue) {
    // Add your navigation logic here
    // For now, showing the same bottom sheet as in your original code
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildIssueDetailsSheet(issue),
    );
  }

  Widget _buildIssueDetailsSheet(CleanlinessIssueModel issue) {
    // Reuse your existing bottom sheet implementation
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Issue Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            issue.description,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text('Location: ${issue.location}', style: TextStyle(fontSize: 14)),
          Text(
            'Reported by: ${issue.residentName}',
            style: TextStyle(fontSize: 14),
          ),
          Text(
            'Reported: ${_formatTime(issue.reportedTime)}, ${_formatDate(issue.reportedTime)}',
            style: TextStyle(fontSize: 14),
          ),
          if (issue.assignedTime != null)
            Text(
              'Assigned: ${_formatTime(issue.assignedTime!)}, ${_formatDate(issue.assignedTime!)}',
              style: TextStyle(fontSize: 14),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (issue.status == 'assigned') ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateIssueStatus(issue, 'inProgress'),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Work'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ] else if (issue.status == 'inProgress') ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateIssueStatus(issue, 'resolved'),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Mark as Resolved'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (issue.latitude != 0 && issue.longitude != 0)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // Launch maps with the location coordinates
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Opening location in maps...'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.location_on),
                    label: const Text('View Location'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _updateIssueStatus(
    CleanlinessIssueModel issue,
    String newStatus,
  ) async {
    Navigator.pop(context); // Close the bottom sheet

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _cleanlinessService.updateIssueStatus(
        issueId: issue.id,
        newStatus: newStatus,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Issue ${newStatus == 'inProgress' ? 'marked as in progress' : 'resolved'} successfully',
            ),
            backgroundColor:
                newStatus == 'inProgress' ? Colors.blue : Colors.green,
          ),
        );
        // Refresh the issues list
        _loadCleanlinessIssues();
      } else {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update issue status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error updating issue status: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error updating issue status'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
