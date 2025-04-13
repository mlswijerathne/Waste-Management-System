import 'package:flutter/material.dart';
import 'package:waste_management/models/specialGarbageRequestModel.dart';
import 'package:waste_management/screens/driver_screens/driver_special_garbage_detail_screen.dart';
import 'package:waste_management/service/auth_service.dart';
import 'package:waste_management/service/special_Garbage_Request_service.dart';
import 'package:intl/intl.dart';

class DriverSpecialGarbageScreen extends StatefulWidget {
  const DriverSpecialGarbageScreen({Key? key}) : super(key: key);

  @override
  State<DriverSpecialGarbageScreen> createState() => _DriverSpecialGarbageScreenState();
}

class _DriverSpecialGarbageScreenState extends State<DriverSpecialGarbageScreen> {
  final SpecialGarbageRequestService _requestService = SpecialGarbageRequestService();
  final AuthService _authService = AuthService();
  List<SpecialGarbageRequestModel> _assignedRequests = [];
  bool _isLoading = true;
  String _driverId = '';

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
      _loadAssignedRequests();
    }
  }

  Future<void> _loadAssignedRequests() async {
    if (_driverId.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final requests = await _requestService.getDriverAssignedRequests(_driverId);
      setState(() {
        _assignedRequests = requests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading requests: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Special Garbage Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAssignedRequests,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _assignedRequests.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadAssignedRequests,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _assignedRequests.length,
                    itemBuilder: (context, index) {
                      final request = _assignedRequests[index];
                      return _buildRequestCard(request);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.recycling_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
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
            onPressed: _loadAssignedRequests,
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
    final DateFormat formatter = DateFormat('MMM dd, yyyy - hh:mm a');
    final Color cardColor = Colors.green.shade50;
    final Color statusColor = Colors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cardColor,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DriverSpecialGarbageDetailScreen(requestId: request.id),
            ),
          ).then((_) => _loadAssignedRequests());
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
                  Text(
                    'Request #${request.id.substring(0, 8)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(16),
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
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.category, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Type: ${request.garbageType}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Location: ${request.location}'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text('Resident: ${request.residentName}'),
                ],
              ),
              if (request.estimatedWeight != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.scale, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text('Est. Weight: ${request.estimatedWeight} kg'),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Assigned: ${formatter.format(request.assignedTime!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Implement navigation to the location
                      // Launch maps app with coordinates
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Opening navigation...')),
                      );
                    },
                    icon: const Icon(Icons.directions),
                    label: const Text('NAVIGATE'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DriverSpecialGarbageDetailScreen(requestId: request.id),
                        ),
                      ).then((_) => _loadAssignedRequests());
                    },
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('DETAILS'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}