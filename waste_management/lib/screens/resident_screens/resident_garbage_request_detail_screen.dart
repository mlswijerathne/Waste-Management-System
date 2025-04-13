import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:waste_management/models/specialGarbageRequestModel.dart';
import 'package:waste_management/service/special_Garbage_Request_service.dart';
import 'package:waste_management/service/auth_service.dart';
import 'package:waste_management/models/userModel.dart';
import 'package:waste_management/widgets/status_timeline.dart';

class SpecialGarbageRequestDetailsScreen extends StatefulWidget {
  final SpecialGarbageRequestModel request;

  const SpecialGarbageRequestDetailsScreen({Key? key, required this.request})
    : super(key: key);

  @override
  _SpecialGarbageRequestDetailsScreenState createState() =>
      _SpecialGarbageRequestDetailsScreenState();
}

class _SpecialGarbageRequestDetailsScreenState
    extends State<SpecialGarbageRequestDetailsScreen> {
  final SpecialGarbageRequestService _requestService =
      SpecialGarbageRequestService();
  final AuthService _authService = AuthService();

  SpecialGarbageRequestModel? _currentRequest;
  UserModel? _currentUser;
  bool _isLoading = true;
  String _errorMessage = '';

  // Feedback form values
  bool _confirmCollection = true;
  final TextEditingController _feedbackController = TextEditingController();
  double _ratingValue = 3.0;

  // For real-time updates
  Stream<SpecialGarbageRequestModel?>? _requestStream;

  @override
  void initState() {
    super.initState();
    _currentRequest = widget.request;
    _loadUserData();
    _setupRequestStream();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _setupRequestStream() {
    _requestStream = _requestService.getRequestStream(widget.request.id);
  }

  Future<void> _loadUserData() async {
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

      // Refresh request data
      final updatedRequest = await _requestService.getRequestById(
        widget.request.id,
      );
      if (updatedRequest != null) {
        setState(() {
          _currentRequest = updatedRequest;
        });
      } else {
        setState(() {
          _errorMessage = 'Request details could not be loaded.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load request details: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitFeedback() async {
    if (_currentRequest == null) return;

    try {
      setState(() {
        _isLoading = true;
      });

      String feedback = '';

      if (_ratingValue > 0) {
        feedback = 'Rating: ${_ratingValue.toInt()} stars. ';
      }

      if (_feedbackController.text.isNotEmpty) {
        feedback += _feedbackController.text;
      }

      bool result = await _requestService.updateResidentFeedback(
        requestId: _currentRequest!.id,
        confirmed: _confirmCollection,
        feedback: feedback,
      );

      if (result) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your feedback!'),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh the request data
        final updatedRequest = await _requestService.getRequestById(
          widget.request.id,
        );
        if (updatedRequest != null) {
          setState(() {
            _currentRequest = updatedRequest;
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit feedback. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: badgeColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildStatusTimeline(SpecialGarbageRequestModel request) {
    final statuses = ['pending', 'assigned', 'collected', 'completed'];
    final currentStatusIndex = statuses.indexOf(request.status.toLowerCase());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Status Timeline',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                for (int i = 0; i < statuses.length; i++)
                  _buildTimelineStep(
                    statuses[i],
                    i <= currentStatusIndex,
                    i == 0
                        ? request.requestedTime
                        : i == 1
                        ? request.assignedTime
                        : i == 2
                        ? request.collectedTime
                        : null,
                    i < statuses.length - 1,
                  ),
              ],
            ),
          ),
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
              if (status == 'assigned' &&
                  isCompleted &&
                  _currentRequest?.assignedDriverName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        'Driver: ${_currentRequest!.assignedDriverName}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: showConnector ? 24 : 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRequestDetails(SpecialGarbageRequestModel request) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Request Details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.delete_outline, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Type: ${request.garbageType}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.description_outlined, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Description: ${request.description}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Location: ${request.location}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
                if (request.estimatedWeight != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.scale_outlined, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        'Estimated Weight: ${request.estimatedWeight} kg',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ],
                if (request.notes != null && request.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.note_outlined, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Notes: ${request.notes}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Confirm Collection',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  title: const Text('Garbage was collected successfully'),
                  value: _confirmCollection,
                  onChanged: (value) {
                    setState(() {
                      _confirmCollection = value;
                    });
                  },
                  activeColor: Colors.green,
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Rate the service:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (int i = 1; i <= 5; i++)
                      IconButton(
                        icon: Icon(
                          i <= _ratingValue.round()
                              ? Icons.star
                              : Icons.star_border,
                          color:
                              i <= _ratingValue.round()
                                  ? Colors.amber
                                  : Colors.grey,
                          size: 32,
                        ),
                        onPressed: () {
                          setState(() {
                            _ratingValue = i.toDouble();
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Leave feedback (optional):',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _feedbackController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText:
                        'Share your experience with the collection service...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitFeedback,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child:
                        _isLoading
                            ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : const Text(
                              'Submit Feedback',
                              style: TextStyle(fontSize: 16),
                            ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedFeedback(SpecialGarbageRequestModel request) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Your Feedback',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Collection Confirmed',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                if (request.residentFeedback != null &&
                    request.residentFeedback!.isNotEmpty) ...[
                  const Divider(height: 24),
                  Text(
                    request.residentFeedback!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request Details'), elevation: 0),
      body:
          _isLoading && _currentRequest == null
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
                      onPressed: _loadUserData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
              : StreamBuilder<SpecialGarbageRequestModel?>(
                stream: _requestStream,
                initialData: _currentRequest,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final request = snapshot.data ?? _currentRequest!;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with status
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Current Status',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    _buildStatusBadge(request.status),
                                  ],
                                ),

                                if (request.status.toLowerCase() ==
                                        'collected' &&
                                    _currentUser?.role == 'resident' &&
                                    !(request.residentConfirmed ?? false))
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16.0),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.blue),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.info_outline,
                                            color: Colors.blue,
                                          ),
                                          const SizedBox(width: 8),
                                          const Expanded(
                                            child: Text(
                                              'Please confirm if the garbage was collected and rate the service below.',
                                              style: TextStyle(
                                                color: Colors.blue,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Timeline of status updates
                        _buildStatusTimeline(request),

                        const SizedBox(height: 16),

                        // Request details
                        _buildRequestDetails(request),

                        const SizedBox(height: 16),

                        // Base64 image if available
                        if (request.imageUrl != null && request.imageUrl!.startsWith('data:image/')) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                'Garbage Image',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                              Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Image.memory(
                                  Uri.parse(request.imageUrl!).data?.contentAsBytes() ?? Uint8List(0),
                                  fit: BoxFit.cover,
                                  height: 200,
                                  width: double.infinity,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(child: Text('Failed to load image'));
                                  },
                                ),
                              ),
                            ),
                          ] else if (request.imageUrl != null) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                'Garbage Image',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Image.network(
                                  request.imageUrl!,
                                  fit: BoxFit.cover,
                                  height: 200,
                                  width: double.infinity,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(child: Text('Failed to load image'));
                                  },
                                ),
                              ),
                            ),
                          ],
                        const SizedBox(height: 16),

                        // Display feedback form if user is resident and status is collected but not confirmed
                        if (_currentUser?.role == 'resident' &&
                            request.status.toLowerCase() == 'collected' &&
                            !(request.residentConfirmed ?? false))
                          _buildFeedbackForm(),

                        // If already confirmed, show the feedback provided
                        if (_currentUser?.role == 'resident' &&
                            request.status.toLowerCase() == 'completed' &&
                            (request.residentConfirmed ?? false))
                          _buildCompletedFeedback(request),

                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              ),
    );
  }
}