import 'package:flutter/material.dart';
import 'package:waste_management/models/specialGarbageRequestModel.dart';
import 'package:waste_management/screens/city_management_screens/admin_assign_driver_garbege_request_screen.dart';
import 'package:waste_management/service/special_Garbage_Request_service.dart';
import 'package:intl/intl.dart';
import 'package:waste_management/widgets/status_timeline.dart';

class AdminSpecialGarbageIssuesScreen extends StatefulWidget {
  const AdminSpecialGarbageIssuesScreen({Key? key}) : super(key: key);

  @override
  State<AdminSpecialGarbageIssuesScreen> createState() => _AdminSpecialGarbageIssuesScreenState();
}

class _AdminSpecialGarbageIssuesScreenState extends State<AdminSpecialGarbageIssuesScreen> with TickerProviderStateMixin {
  final SpecialGarbageRequestService _requestService = SpecialGarbageRequestService();
  List<SpecialGarbageRequestModel> _allRequests = [];
  List<SpecialGarbageRequestModel> _filteredRequests = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _currentFilter = 'all';
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadAllRequests();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      return;
    }
    
    setState(() {
      switch (_tabController.index) {
        case 0:
          _currentFilter = 'all';
          break;
        case 1:
          _currentFilter = 'pending';
          break;
        case 2:
          _currentFilter = 'in_progress';
          break;
        case 3:
          _currentFilter = 'completed';
          break;
        default:
          _currentFilter = 'all';
      }
      _filterRequests();
    });
  }

  Future<void> _loadAllRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final requests = await _requestService.getAllRequests();
      setState(() {
        _allRequests = requests;
        _filterRequests();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading requests: $e';
        _isLoading = false;
      });
    }
  }

  void _filterRequests() {
    setState(() {
      switch (_currentFilter) {
        case 'pending':
          _filteredRequests = _allRequests.where((req) => req.status.toLowerCase() == 'pending').toList();
          break;
        case 'in_progress':
          _filteredRequests = _allRequests.where((req) => 
            req.status.toLowerCase() == 'assigned' || req.status.toLowerCase() == 'collected').toList();
          break;
        case 'completed':
          _filteredRequests = _allRequests.where((req) => req.status.toLowerCase() == 'completed').toList();
          break;
        case 'all':
        default:
          _filteredRequests = List.from(_allRequests);
      }

      // Apply search filter if there's text in the search field
      if (_searchController.text.isNotEmpty) {
        final query = _searchController.text.toLowerCase();
        _filteredRequests = _filteredRequests.where((req) => 
          req.residentName.toLowerCase().contains(query) ||
          req.location.toLowerCase().contains(query) ||
          req.garbageType.toLowerCase().contains(query) ||
          req.description.toLowerCase().contains(query)
        ).toList();
      }
    });
  }

  void _onSearchChanged(String query) {
    _filterRequests();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'assigned':
        return Colors.blue;
      case 'collected':
        return Colors.green;
      case 'completed':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatusBadge(String status) {
    final badgeColor = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
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

  void _showRequestDetails(SpecialGarbageRequestModel request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => _buildDetailSheet(request, scrollController),
      ),
    );
  }

  Widget _buildDetailSheet(SpecialGarbageRequestModel request, ScrollController scrollController) {
    final DateFormat dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle and title bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Request #${request.id.substring(0, 8)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    _buildStatusBadge(request.status),
                  ],
                ),
              ],
            ),
          ),
          
          // Request details
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                // Basic details card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Request Information',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Divider(),
                        _buildInfoRow(Icons.delete_outline, 'Type', request.garbageType),
                        _buildInfoRow(Icons.description_outlined, 'Description', request.description),
                        _buildInfoRow(Icons.location_on_outlined, 'Location', request.location),
                        if (request.estimatedWeight != null)
                          _buildInfoRow(Icons.scale_outlined, 'Estimated Weight', '${request.estimatedWeight} kg'),
                        _buildInfoRow(Icons.person_outline, 'Resident', request.residentName),
                        _buildInfoRow(
                          Icons.calendar_today_outlined, 
                          'Requested', 
                          dateFormat.format(request.requestedTime)
                        ),
                        if (request.notes != null && request.notes!.isNotEmpty)
                          _buildInfoRow(Icons.note_outlined, 'Notes', request.notes!),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Status timeline
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Status Timeline',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Divider(),
                        _buildStatusTimeline(request),
                      ],
                    ),
                  ),
                ),
                
                // Display resident feedback if available
                if (request.status.toLowerCase() == 'completed' && 
                    (request.residentFeedback != null && request.residentFeedback!.isNotEmpty)) ...[
                  const SizedBox(height: 16),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Resident Feedback',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Divider(),
                          if (request.residentConfirmed == true)
                            Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green, size: 18),
                                const SizedBox(width: 8),
                                const Text(
                                  'Collection confirmed by resident',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          if (request.residentConfirmed == false)
                            Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red, size: 18),
                                const SizedBox(width: 8),
                                const Text(
                                  'Collection disputed by resident',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 8),
                          Text(
                            request.residentFeedback!,
                            style: const TextStyle(
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // Action buttons
                if (request.status.toLowerCase() == 'pending')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close the bottom sheet
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdminAssignDriverScreen(requestId: request.id),
                          ),
                        ).then((_) => _loadAllRequests());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Assign Driver'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTimeline(SpecialGarbageRequestModel request) {
  final statuses = ['pending', 'assigned', 'collected', 'completed'];
  final currentStatusIndex = statuses.indexOf(request.status.toLowerCase());

  return Column(
    children: [
      for (int i = 0; i < statuses.length; i++)
        _buildTimelineStep(
          statuses[i],
          i <= currentStatusIndex,
          i == 0
              ? request.requestedTime
              : i == 1
              ? request.assignedTime is DateTime 
                ? request.assignedTime 
                : (request.assignedTime != null ? DateTime.tryParse(request.assignedTime.toString()) : null)
              : i == 2
              ? request.collectedTime is DateTime
                ? request.collectedTime 
                : (request.collectedTime != null ? DateTime.tryParse(request.collectedTime.toString()) : null)
              : null,
          i < statuses.length - 1,
        ),
    ],
  );
}

  Widget _buildTimelineStep(
    String status,
    bool isCompleted,
    DateTime? timestamp,
    bool showConnector,
  ) {
    final DateFormat dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    final String formattedDate =
        timestamp != null ? dateFormat.format(timestamp) : '';

    final statusLabels = {
      'pending': 'Request Submitted',
      'assigned': 'Driver Assigned',
      'collected': 'Garbage Collected',
      'completed': 'Request Completed',
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? _getStatusColor(status) : Colors.grey[300],
                border: Border.all(
                  color:
                      isCompleted ? _getStatusColor(status) : Colors.grey[400]!,
                  width: 2,
                ),
              ),
              child:
                  isCompleted
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
            ),
            if (showConnector)
              Container(
                width: 2,
                height: 40,
                color: isCompleted ? _getStatusColor(status) : Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                statusLabels[status] ?? status.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isCompleted ? Colors.black : Colors.grey[600],
                ),
              ),
              if (formattedDate.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    formattedDate,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ),
              SizedBox(height: showConnector ? 24 : 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRequestCard(SpecialGarbageRequestModel request) {
    final DateFormat formatter = DateFormat('MMM dd, yyyy - hh:mm a');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showRequestDetails(request),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Request #${request.id.substring(0, 8)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  _buildStatusBadge(request.status),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.delete_outline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    request.garbageType,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      request.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(request.residentName),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(formatter.format(request.requestedTime)),
                ],
              ),
              
              // Show resident feedback indication if available
              if (request.status.toLowerCase() == 'completed' && 
                  request.residentFeedback != null && 
                  request.residentFeedback!.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.rate_review_outlined, 
                      size: 16, 
                      color: Colors.purple[700]
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Resident feedback available',
                      style: TextStyle(
                        color: Colors.purple[700],
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
              
              if (request.status.toLowerCase() == 'pending') ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminAssignDriverScreen(requestId: request.id),
                        ),
                      ).then((_) => _loadAllRequests());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Assign Driver'),
                  ),
                ),
              ],
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
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'All Requests'),
            Tab(text: 'Pending'),
            Tab(text: 'In Progress'),
            Tab(text: 'Completed'),
          ],
          labelColor: Theme.of(context).primaryColor,
          indicatorColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllRequests,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by name, location, type...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          
          Expanded(
            child: _isLoading
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
                              onPressed: _loadAllRequests,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _filteredRequests.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No ${_currentFilter == 'all' ? '' : _currentFilter} requests found',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadAllRequests,
                            child: ListView.builder(
                              itemCount: _filteredRequests.length,
                              itemBuilder: (context, index) {
                                final request = _filteredRequests[index];
                                return _buildRequestCard(request);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}