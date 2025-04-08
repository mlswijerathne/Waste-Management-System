import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:waste_management/models/specialGarbageRequestModel.dart';
import 'package:waste_management/service/auth_service.dart';
import 'package:waste_management/service/special_Garbage_Request_service.dart';
import 'package:intl/intl.dart';

class AdminAssignedRequestsHistoryScreen extends StatefulWidget {
  const AdminAssignedRequestsHistoryScreen({Key? key}) : super(key: key);

  @override
  State<AdminAssignedRequestsHistoryScreen> createState() => _AdminAssignedRequestsHistoryScreenState();
}

class _AdminAssignedRequestsHistoryScreenState extends State<AdminAssignedRequestsHistoryScreen> {
  final SpecialGarbageRequestService _requestService = SpecialGarbageRequestService();
  List<SpecialGarbageRequestModel> _assignedRequests = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // 'all', 'assigned', 'collected', 'completed'

  @override
  void initState() {
    super.initState();
    _loadAssignedRequests();
  }

  Future<void> _loadAssignedRequests() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get all requests
      final requests = await _requestService.getAllRequests();
      
      // Filter out only the requests that have been assigned to drivers
      final assignedRequests = requests.where((request) => 
        request.status != 'pending' && request.assignedDriverId != null).toList();

      setState(() {
        _assignedRequests = assignedRequests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading assigned requests: $e')),
        );
      }
    }
  }

  List<SpecialGarbageRequestModel> get _filteredRequests {
    if (_selectedFilter == 'all') {
      return _assignedRequests;
    } else {
      return _assignedRequests.where((request) => request.status == _selectedFilter).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assigned Requests History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAssignedRequests,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRequests.isEmpty
                    ? Center(
                        child: Text(
                          _selectedFilter == 'all'
                              ? 'No assigned requests found'
                              : 'No ${_selectedFilter} requests found',
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadAssignedRequests,
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

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Theme.of(context).cardColor,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _buildFilterChip('All', 'all'),
            const SizedBox(width: 8),
            _buildFilterChip('Assigned', 'assigned'),
            const SizedBox(width: 8),
            _buildFilterChip('Collected', 'collected'),
            const SizedBox(width: 8),
            _buildFilterChip('Completed', 'completed'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      backgroundColor: Colors.grey[200],
      selectedColor: Colors.green,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildRequestCard(SpecialGarbageRequestModel request) {
    final DateFormat formatter = DateFormat('MMM dd, yyyy - hh:mm a');
    
    // Get status color
    Color statusColor;
    switch (request.status) {
      case 'assigned':
        statusColor = Colors.blue;
        break;
      case 'collected':
        statusColor = Colors.orange;
        break;
      case 'completed':
        statusColor = Colors.green;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: ExpansionTile(
        title: Text(
          'Request #${request.id.substring(0, 8)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Type: ${request.garbageType}'),
            Text('Driver: ${request.assignedDriverName}'),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            request.status.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Resident:', request.residentName),
                _buildDetailRow('Location:', request.location),
                _buildDetailRow('Coordinates:', '${request.latitude}, ${request.longitude}'),
                _buildDetailRow('Description:', request.description),
                _buildDetailRow('Requested Time:', formatter.format(request.requestedTime)),
                if (request.assignedTime != null)
                  _buildDetailRow('Assigned Time:', formatter.format(request.assignedTime!)),
                if (request.collectedTime != null)
                  _buildDetailRow('Collected Time:', formatter.format(request.collectedTime!)),
                if (request.estimatedWeight != null)
                  _buildDetailRow('Weight:', '${request.estimatedWeight} kg'),
                if (request.notes != null && request.notes!.isNotEmpty)
                  _buildDetailRow('Notes:', request.notes!),
                if (request.residentConfirmed != null)
                  _buildDetailRow(
                    'Resident Confirmed:',
                    request.residentConfirmed! ? 'Yes' : 'No',
                  ),
                if (request.residentFeedback != null && request.residentFeedback!.isNotEmpty)
                  _buildDetailRow('Resident Feedback:', request.residentFeedback!),
                if (request.imageUrl != null && request.imageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Image:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      // Show image in dialog
                      showDialog(
                        context: context,
                        builder: (context) => Dialog(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppBar(
                                title: const Text('Request Image'),
                                leading: IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ),
                              _buildImageWidget(request.imageUrl!),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildImageWidget(request.imageUrl!),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        // Implement view on map functionality
                        // This would navigate to a map view showing the request location
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Map view not implemented')),
                        );
                      },
                      icon: const Icon(Icons.map),
                      label: const Text('VIEW ON MAP'),
                    ),
                    // Add button to call driver or show driver details
                    ElevatedButton.icon(
                      onPressed: () {
                        // Show driver details or implement call functionality
                        _showDriverDetailsDialog(context, request.assignedDriverId!);
                      },
                      icon: const Icon(Icons.person),
                      label: const Text('DRIVER DETAILS'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageWidget(String imageUrl) {
    if (imageUrl.startsWith('data:image') || imageUrl.startsWith('http')) {
      try {
        if (imageUrl.startsWith('data:image')) {
          // Handle base64 image
          String base64String = imageUrl;
          if (imageUrl.contains(',')) {
            base64String = imageUrl.split(',')[1];
          }
          return Image.memory(
            base64Decode(base64String),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(Icons.broken_image, size: 64),
            ),
          );
        } else {
          // Handle network image
          return Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(Icons.broken_image, size: 64),
            ),
          );
        }
      } catch (e) {
        return const Center(
          child: Icon(Icons.broken_image, size: 64),
        );
      }
    } else {
      return const Center(
        child: Icon(Icons.image_not_supported, size: 64),
      );
    }
  }

  Future<void> _showDriverDetailsDialog(BuildContext context, String driverId) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading driver details...'),
          ],
        ),
      ),
    );

    try {
      // Get driver details
      final driver = await _authService.getDriverById(driverId);
      
      // Close loading dialog
      Navigator.pop(context);
      
      if (driver != null) {
        // Show driver details dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Driver Details'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Name:', driver.name),
                _buildDetailRow('Phone:', driver.contactNumber),
                _buildDetailRow('Email:', driver.email),
                _buildDetailRow('Address:', driver.address),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CLOSE'),
              ),
              // Add call button
              ElevatedButton.icon(
                onPressed: () {
                  // Implement call functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Calling ${driver.name}...')),
                  );
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.call),
                label: const Text('CALL'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driver details not found')),
        );
      }
    } catch (e) {
      // Close loading dialog
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading driver details: $e')),
      );
    }
  }

  // Import the auth service
  final _authService = AuthService();
}