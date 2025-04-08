import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:waste_management/models/specialGarbageRequestModel.dart';
import 'package:waste_management/screens/resident_screens/resident_request_special_garbage_location.dart';
import 'package:waste_management/service/special_Garbage_Request_service.dart';
import 'package:waste_management/service/auth_service.dart';
import 'package:waste_management/models/userModel.dart';

class SpecialGarbageRequestsScreen extends StatefulWidget {
  const SpecialGarbageRequestsScreen({Key? key}) : super(key: key);

  @override
  _SpecialGarbageRequestsScreenState createState() => _SpecialGarbageRequestsScreenState();
}

class _SpecialGarbageRequestsScreenState extends State<SpecialGarbageRequestsScreen> {
  final SpecialGarbageRequestService _requestService = SpecialGarbageRequestService();
  final AuthService _authService = AuthService();
  UserModel? _currentUser;
  List<SpecialGarbageRequestModel> _requests = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadUserAndRequests();
  }

  Future<void> _loadUserAndRequests() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Load current user
      final user = await _authService.getCurrentUser();
      setState(() {
        _currentUser = user;
      });

      if (user == null) {
        setState(() {
          _errorMessage = 'User not authenticated. Please log in.';
          _isLoading = false;
        });
        return;
      }

      // Check user role to determine which requests to fetch
      if (user.role == 'admin') {
        // Admin sees all requests
        final requests = await _requestService.getAllRequests();
        setState(() {
          _requests = requests;
        });
      } else if (user.role == 'driver') {
        // Driver sees assigned requests
        final requests = await _requestService.getDriverAssignedRequests(user.uid);
        setState(() {
          _requests = requests;
        });
      } else {
        // Resident sees their own requests
        final requests = await _requestService.getResidentRequests(user.uid);
        setState(() {
          _requests = requests;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load requests: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToRequestForm() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SpecialGarbageRequestScreen(),
      ),
    ).then((_) {
      // Refresh the list when returning from the request form
      _loadUserAndRequests();
    });
  }

  String _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'orange';
      case 'assigned':
        return 'blue';
      case 'collected':
        return 'green';
      case 'completed':
        return 'purple';
      default:
        return 'grey';
    }
  }

  Widget _buildStatusBadge(String status) {
    Color badgeColor;
    switch (status.toLowerCase()) {
      case 'pending':
        badgeColor = Colors.orange;
        break;
      case 'assigned':
        badgeColor = Colors.blue;
        break;
      case 'collected':
        badgeColor = Colors.green;
        break;
      case 'completed':
        badgeColor = Colors.purple;
        break;
      default:
        badgeColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: badgeColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildRequestCard(SpecialGarbageRequestModel request) {
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    final requestDate = request.requestedTime != null 
        ? dateFormat.format(request.requestedTime!) 
        : 'Unknown date';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to request details screen
          // This would be implemented in a follow-up
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${request.garbageType}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildStatusBadge(request.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Requested: $requestDate',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Description: ${request.description}',
                style: const TextStyle(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      request.location,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (_currentUser?.role == 'admin' || _currentUser?.role == 'driver')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        'Requested by: ${request.residentName}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Special Garbage Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserAndRequests,
            tooltip: 'Refresh',
          ),
          // Only show the add button for residents
          if (_currentUser == null || _currentUser!.role == 'resident')
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _navigateToRequestForm,
              tooltip: 'New Request',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadUserAndRequests,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _requests.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No special garbage requests found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (_currentUser == null || _currentUser!.role == 'resident')
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: ElevatedButton.icon(
                                onPressed: _navigateToRequestForm,
                                icon: const Icon(Icons.add),
                                label: const Text('Create New Request'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadUserAndRequests,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _requests.length,
                        itemBuilder: (context, index) {
                          return _buildRequestCard(_requests[index]);
                        },
                      ),
                    ),
      floatingActionButton: (_currentUser == null || _currentUser!.role == 'resident')
          ? FloatingActionButton(
              onPressed: _navigateToRequestForm,
              backgroundColor: Colors.green,
              tooltip: 'Create Request',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

