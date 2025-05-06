import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:waste_management/models/cleanlinessIssueModel.dart';
import 'package:waste_management/service/cleanliness_issue_service.dart';
import 'package:waste_management/service/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:waste_management/widgets/resident_navbar.dart';
import 'package:http/http.dart' as http;

class RecentReportsRequestsPage extends StatefulWidget {
  const RecentReportsRequestsPage({super.key});

  @override
  _RecentReportsRequestsPageState createState() =>
      _RecentReportsRequestsPageState();
}

class _RecentReportsRequestsPageState extends State<RecentReportsRequestsPage> {
  final CleanlinessIssueService _issueService = CleanlinessIssueService();
  final AuthService _authService = AuthService();

  List<CleanlinessIssueModel> _issues = [];
  List<CleanlinessIssueModel> _filteredIssues = [];
  bool _isLoading = true;
  int _currentIndex = 1; // Set to 1 since this is the "Report" tab
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserIssues();
    _searchController.addListener(_filterIssues);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserIssues() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        // Use stream instead of future for real-time updates
        _issueService
            .getResidentIssuesStream(currentUser.uid)
            .listen(
              (issues) {
                setState(() {
                  _issues = issues;
                  _filterIssues();
                  _isLoading = false;
                });
              },
              onError: (e) {
                setState(() {
                  _errorMessage = 'Error loading issues: $e';
                  _isLoading = false;
                });
              },
            );
      } else {
        setState(() {
          _errorMessage = 'User not logged in';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user issues: $e');
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  void _filterIssues() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredIssues = List.from(_issues);
      } else {
        _filteredIssues =
            _issues.where((issue) {
              return issue.description.toLowerCase().contains(query) ||
                  issue.location.toLowerCase().contains(query) ||
                  _getStatusText(issue.status).toLowerCase().contains(query) ||
                  (issue.assignedDriverName?.toLowerCase().contains(query) ??
                      false);
            }).toList();
      }
    });
  }

  // Format the date
  String _formatDate(DateTime dateTime) {
    return DateFormat('MMM d, yyyy • h:mm a').format(dateTime);
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Requested';
      case 'assigned':
        return 'Assigned';
      case 'inProgress':
        return 'In Progress';
      case 'resolved':
        return 'Completed';
      default:
        return status.capitalize();
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'resolved':
        return Colors.purple;
      case 'inProgress':
        return Colors.green;
      case 'assigned':
        return Colors.blue;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  // New method to handle image loading
  Future<Uint8List?> _getImageBytes(String imageUrl) async {
    if (imageUrl.isEmpty) return null;

    try {
      if (imageUrl.startsWith('http')) {
        try {
          final response = await http.get(Uri.parse(imageUrl));
          if (response.statusCode == 200) {
            return response.bodyBytes;
          } else {
            print('HTTP error: ${response.statusCode}');
            return null;
          }
        } catch (e) {
          print('Error fetching network image: $e');
          return null;
        }
      } else {
        try {
          String sanitized = imageUrl;
          if (imageUrl.contains(',')) {
            sanitized = imageUrl.split(',')[1];
          }

          try {
            return base64Decode(sanitized);
          } catch (e) {
            print('Initial base64 decode failed: $e');

            while (sanitized.length % 4 != 0) {
              sanitized += '=';
            }

            return base64Decode(sanitized);
          }
        } catch (e) {
          print('Error decoding base64 image: $e');
          return null;
        }
      }
    } catch (e) {
      print('Error processing image: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent Reports & Requests'),
        automaticallyImplyLeading: false,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserIssues,
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
              decoration: InputDecoration(
                hintText: 'Search by description, location or status...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
              ),
            ),
          ),

          // Issues list
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadUserIssues,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                    : _filteredIssues.isEmpty
                    ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No reports found',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      itemCount: _filteredIssues.length,
                      itemBuilder: (context, index) {
                        final issue = _filteredIssues[index];
                        return _buildIssueCard(issue);
                      },
                    ),
          ),
        ],
      ),
      bottomNavigationBar: ResidentNavbar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }

  Widget _buildIssueCard(CleanlinessIssueModel issue) {
    final statusColor = _getStatusColor(issue.status);
    final statusText =
        issue.status == 'resolved'
            ? 'COMPLETED'
            : _getStatusText(issue.status).toUpperCase();

    // Extract rating if available in completed tasks
    String? rating;
    if (issue.status == 'resolved' &&
        issue.residentFeedback != null &&
        issue.residentFeedback!.contains('stars')) {
      // Extract the rating number from feedback like "4 stars: Great service"
      final ratingMatch = RegExp(
        r'(\d+)\s*stars',
      ).firstMatch(issue.residentFeedback!);
      if (ratingMatch != null) {
        rating = ratingMatch.group(1);
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          _showIssueDetailsDialog(issue);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with description
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      issue.description,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Request details
              Text(
                'Requested: ${_formatDate(issue.reportedTime)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),

              const SizedBox(height: 6),

              // Location with icon
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      issue.location,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // Assigned to
              if (issue.assignedDriverName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Assigned to: ${issue.assignedDriverName}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),

              // Show rating if it's a completed task with feedback
              if (issue.status == 'resolved')
                Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Row(
                    children: [
                      Icon(
                        rating != null ? Icons.star : Icons.star_border,
                        size: 16,
                        color: rating != null ? Colors.amber : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        rating != null ? 'Rating: $rating/5' : 'Not Rated',
                        style: TextStyle(
                          color:
                              rating != null
                                  ? Colors.grey[800]
                                  : Colors.grey[600],
                          fontSize: 14,
                          fontWeight:
                              rating != null
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12.0),

              // Progress bar with segments
              Row(
                children: [
                  // Pending segment
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: _getStatusColor('pending'),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(2),
                          bottomLeft: Radius.circular(2),
                        ),
                      ),
                    ),
                  ),

                  // Assigned segment
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color:
                            [
                                  'assigned',
                                  'inProgress',
                                  'resolved',
                                ].contains(issue.status)
                                ? _getStatusColor('assigned')
                                : Colors.grey[300],
                      ),
                    ),
                  ),

                  // In Progress segment
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color:
                            ['inProgress', 'resolved'].contains(issue.status)
                                ? _getStatusColor('inProgress')
                                : Colors.grey[300],
                      ),
                    ),
                  ),

                  // Resolved segment
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color:
                            issue.status == 'resolved'
                                ? _getStatusColor('resolved')
                                : Colors.grey[300],
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(2),
                          bottomRight: Radius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Status labels
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Requested',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color:
                          issue.status == 'pending'
                              ? statusColor
                              : Colors.grey[600],
                    ),
                  ),
                  Text(
                    'Assigned',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color:
                          issue.status == 'assigned'
                              ? statusColor
                              : Colors.grey[600],
                    ),
                  ),
                  Text(
                    'In Progress',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color:
                          issue.status == 'inProgress'
                              ? statusColor
                              : Colors.grey[600],
                    ),
                  ),
                  Text(
                    'Completed',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color:
                          issue.status == 'resolved'
                              ? statusColor
                              : Colors.grey[600],
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

  void _showIssueDetailsDialog(CleanlinessIssueModel issue) {
    final statusColor = _getStatusColor(issue.status);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return StatefulBuilder(
                builder: (context, setState) {
                  // For feedback form
                  int _rating = 0;
                  final TextEditingController _feedbackController =
                      TextEditingController();

                  return Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Drag handle
                        Container(
                          height: 5,
                          width: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Header with status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Issue Details',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Issue content with scroll
                        Expanded(
                          child: ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.only(bottom: 24),
                            children: [
                              // Current status card
                              Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(
                                                0.2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: statusColor,
                                              ),
                                            ),
                                            child: Text(
                                              _getStatusText(
                                                issue.status,
                                              ).toUpperCase(),
                                              style: TextStyle(
                                                color: statusColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      if (issue.status == 'resolved' &&
                                          !(issue.residentConfirmed ?? false))
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 16.0,
                                          ),
                                          child: Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.blue,
                                              ),
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
                                                    'Please confirm this issue was resolved and provide feedback below.',
                                                    style: TextStyle(
                                                      color: Colors.blue,
                                                      fontWeight:
                                                          FontWeight.bold,
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
                              _buildStatusTimeline(issue),

                              const SizedBox(height: 16),

                              // Issue details
                              _buildIssueDetails(issue),

                              const SizedBox(height: 16),

                              // Image if available
                              if (issue.imageUrl.isNotEmpty)
                                _buildImageSection(issue.imageUrl),

                              const SizedBox(height: 16),

                              // Feedback section if resolved but not confirmed
                              if (issue.status == 'resolved' &&
                                  !(issue.residentConfirmed ?? false))
                                _buildFeedbackForm(issue),

                              // If already confirmed, show the feedback provided
                              if (issue.status == 'resolved' &&
                                  (issue.residentConfirmed ?? false) &&
                                  issue.residentFeedback != null)
                                _buildCompletedFeedback(issue),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
    );
  }

  Widget _buildStatusTimeline(CleanlinessIssueModel issue) {
    final statuses = ['pending', 'assigned', 'inProgress', 'resolved'];
    final currentStatusIndex = statuses.indexOf(issue.status);

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
                        ? issue.reportedTime
                        : i == 1
                        ? issue.assignedTime
                        : i == 2
                        ? null // No specific time for inProgress
                        : issue.resolvedTime,
                    i < statuses.length - 1,
                    issue,
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
    CleanlinessIssueModel issue,
  ) {
    final DateFormat dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    final String formattedDate =
        timestamp != null ? dateFormat.format(timestamp) : '';

    final statusLabels = {
      'pending': 'Issue Reported',
      'assigned': 'Driver Assigned',
      'inProgress': 'In Progress',
      'resolved': 'Issue Resolved',
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
                  issue.assignedDriverName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        'Driver: ${issue.assignedDriverName}',
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

  Widget _buildIssueDetails(CleanlinessIssueModel issue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Issue Details',
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.description_outlined, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Description: ${issue.description}',
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
                        'Location: ${issue.location}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Reported: ${_formatDate(issue.reportedTime)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageSection(String imageUrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Issue Image',
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
            child: FutureBuilder<Uint8List?>(
              future: _getImageBytes(imageUrl),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }

                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    snapshot.data == null ||
                    snapshot.data!.isEmpty) {
                  return SizedBox(
                    height: 200,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.broken_image,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Failed to load image',
                            style: const TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    snapshot.data!,
                    fit: BoxFit.cover,
                    height: 200,
                    width: double.infinity,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackForm(CleanlinessIssueModel issue) {
    // Form values
    int _rating = 0;
    final TextEditingController _feedbackController = TextEditingController();
    bool _confirmedResolution = true;

    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Confirm Resolution',
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
                      title: const Text('Issue was resolved successfully'),
                      value: _confirmedResolution,
                      onChanged: (value) {
                        setState(() {
                          _confirmedResolution = value;
                        });
                      },
                      activeColor: Colors.green,
                    ),
                    const Divider(),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'Rate the service:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int i = 1; i <= 5; i++)
                          IconButton(
                            icon: Icon(
                              i <= _rating ? Icons.star : Icons.star_border,
                              color: i <= _rating ? Colors.amber : Colors.grey,
                              size: 32,
                            ),
                            onPressed: () {
                              setState(() {
                                _rating = i;
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Leave feedback (optional):',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _feedbackController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Share your experience with the service...',
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
                        onPressed: () async {
                          // Submit the feedback
                          final success = await _issueService
                              .updateResidentFeedback(
                                issueId: issue.id,
                                confirmed: _confirmedResolution,
                                feedback:
                                    "${_rating} stars: ${_feedbackController.text}",
                              );

                          Navigator.pop(context);

                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Thank you for your feedback!'),
                                backgroundColor: Colors.green,
                              ),
                            );

                            // Refresh the list
                            _loadUserIssues();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Failed to submit feedback. Please try again.',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Submit Feedback',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCompletedFeedback(CleanlinessIssueModel issue) {
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
                      'Resolution Confirmed',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                if (issue.residentFeedback != null &&
                    issue.residentFeedback!.isNotEmpty) ...[
                  const Divider(height: 24),
                  Text(
                    issue.residentFeedback!,
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
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
