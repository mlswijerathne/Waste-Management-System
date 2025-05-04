import 'package:flutter/material.dart';
import 'package:waste_management/models/specialGarbageRequestModel.dart';
import 'package:waste_management/screens/driver_screens/driver_special_garbage_detail_screen.dart';
import 'package:waste_management/service/auth_service.dart';
import 'package:waste_management/service/special_Garbage_Request_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class DriverSpecialGarbageScreen extends StatefulWidget {
  const DriverSpecialGarbageScreen({Key? key}) : super(key: key);

  @override
  State<DriverSpecialGarbageScreen> createState() =>
      _DriverSpecialGarbageScreenState();
}

class _DriverSpecialGarbageScreenState
    extends State<DriverSpecialGarbageScreen> {
  final SpecialGarbageRequestService _requestService =
      SpecialGarbageRequestService();
  final AuthService _authService = AuthService();
  List<SpecialGarbageRequestModel> _allRequests = [];
  bool _isLoading = true;
  String _driverId = '';
  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'Assigned', 'Completed'];

  // Stream subscription for real-time updates
  Stream<List<SpecialGarbageRequestModel>>? _requestsStream;

  @override
  void initState() {
    super.initState();
    _getCurrentDriverId();
  }

  Future<void> _getCurrentDriverId() async {
    final currentUser = await _authService.getCurrentUser();
    if (currentUser != null) {
      setState(() {
        _driverId = currentUser.uid;
      });
      _setupRequestsStream();
    }
  }

  void _setupRequestsStream() {
    if (_driverId.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    // Subscribe to real-time updates for driver requests
    _requestsStream = _requestService.getDriverRequestsStream(_driverId);

    // Also fetch completed requests that aren't in the stream
    _loadHistoricalRequests();
  }

  Future<void> _loadHistoricalRequests() async {
    try {
      // Get all requests that were assigned to this driver (including historical ones)
      final requests = await _requestService.getDriverAssignedRequests(
        _driverId,
      );

      setState(() {
        _allRequests = requests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading requests: $e')));
      }
    }
  }

  List<SpecialGarbageRequestModel> _getFilteredRequests() {
    if (_selectedFilter == 'All') {
      // Exclude "Collected" requests
      return _allRequests
          .where((request) => request.status.toLowerCase() != 'collected')
          .toList();
    } else if (_selectedFilter == 'Completed') {
      // Include only "Completed" requests
      return _allRequests
          .where((request) => request.status.toLowerCase() == 'completed')
          .toList();
    } else {
      // Include requests matching the selected filter
      return _allRequests
          .where(
            (request) =>
                request.status.toLowerCase() == _selectedFilter.toLowerCase(),
          )
          .toList();
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'assigned':
        return Colors.blue;
      case 'completed':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatusBadge(String status) {
    final badgeColor = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: badgeColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
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
            onPressed: _loadHistoricalRequests,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: Colors.grey[100],
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children:
                    _filterOptions.map((filter) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: _selectedFilter == filter,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedFilter = filter;
                              });
                            }
                          },
                          selectedColor: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.2),
                          labelStyle: TextStyle(
                            color:
                                _selectedFilter == filter
                                    ? Theme.of(context).primaryColor
                                    : Colors.black,
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ),
          ),

          // Main content
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : (_allRequests.isEmpty
                        ? _buildEmptyState()
                        : _buildRequestsList()),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList() {
    final filteredRequests = _getFilteredRequests();

    return filteredRequests.isEmpty
        ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.recycling_outlined, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No ${_selectedFilter.toLowerCase()} requests',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        )
        : RefreshIndicator(
          onRefresh: _loadHistoricalRequests,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredRequests.length,
            itemBuilder: (context, index) {
              return _buildRequestCard(filteredRequests[index]);
            },
          ),
        );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.recycling_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No assigned requests',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You have no special garbage requests assigned to you.',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadHistoricalRequests,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(SpecialGarbageRequestModel request) {
    final DateFormat formatter = DateFormat('MMM d, yyyy • h:mm a');
    final String formattedDate = formatter.format(request.requestedTime);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // Only navigate if the request is not "Completed"
          if (request.status.toLowerCase() != 'completed') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) =>
                        DriverSpecialGarbageDetailScreen(requestId: request.id),
              ),
            ).then((_) => _loadHistoricalRequests());
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with type and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    request.garbageType,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  _buildStatusBadge(request.status),
                ],
              ),

              // Request time
              const SizedBox(height: 8),
              Text(
                'Requested: $formattedDate',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),

              // Description preview
              const SizedBox(height: 8),
              Text(
                'Description: ${request.description.length > 30 ? request.description.substring(0, 30) + '...' : request.description}',
                style: const TextStyle(fontSize: 14),
              ),

              // Location
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      request.location,
                      style: TextStyle(color: Colors.grey[700], fontSize: 14),
                    ),
                  ),
                ],
              ),

              // Assigned driver info
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Assigned to: ${request.assignedDriverName ?? "You"}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 14),
                  ),
                ],
              ),

              // Show feedback and rating if completed
              if (request.status.toLowerCase() == 'completed' &&
                  (request.residentFeedback != null || request.rating != null))
                _buildFeedbackSection(request),

              // Status timeline
              const SizedBox(height: 16),
              _buildStatusBar(request),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackSection(SpecialGarbageRequestModel request) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.feedback_outlined, size: 16, color: Colors.grey[700]),
            const SizedBox(width: 4),
            Text(
              'Resident Feedback',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        if (request.rating != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const SizedBox(width: 20),
              RatingBar.builder(
                initialRating: request.rating ?? 0,
                minRating: 0,
                direction: Axis.horizontal,
                allowHalfRating: true,
                itemCount: 5,
                itemSize: 18,
                ignoreGestures: true,
                itemBuilder:
                    (context, _) => const Icon(Icons.star, color: Colors.amber),
                onRatingUpdate: (_) {},
              ),
              const SizedBox(width: 8),
              Text(
                '${request.rating}',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
            ],
          ),
        ],
        if (request.residentFeedback != null &&
            request.residentFeedback!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Text(
              request.residentFeedback!,
              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 14),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusBar(SpecialGarbageRequestModel request) {
    final statuses = ['assigned', 'completed']; // Removed 'collected'
    final currentStatus = request.status.toLowerCase();
    final currentStatusIndex = statuses.indexOf(currentStatus);

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: currentStatusIndex >= 0 ? Colors.blue : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: currentStatusIndex >= 1 ? Colors.purple : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
  }
}
