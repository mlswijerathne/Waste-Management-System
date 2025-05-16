import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:waste_management/models/cleanlinessIssueModel.dart';
import 'package:waste_management/screens/city_management_screens/admin_assign_driver_cleanliness_issue_screen.dart';
import 'package:waste_management/service/cleanliness_issue_service.dart';
import 'package:waste_management/widgets/admin_navbar.dart';

class AdminCleanlinessIssueListScreen extends StatefulWidget {
  const AdminCleanlinessIssueListScreen({Key? key}) : super(key: key);

  @override
  State<AdminCleanlinessIssueListScreen> createState() =>
      _AdminCleanlinessIssueListScreenState();
}

class _AdminCleanlinessIssueListScreenState
    extends State<AdminCleanlinessIssueListScreen> {
  final CleanlinessIssueService _cleanlinessService = CleanlinessIssueService();
  List<CleanlinessIssueModel> _allIssues = [];
  List<CleanlinessIssueModel> _filteredIssues = [];
  bool _isLoading = true;
  final Color primaryColor = const Color(0xFF59A867);

  // Search functionality
  final TextEditingController _searchController = TextEditingController();

  // Filter management
  String _selectedFilter = 'All'; // Default filter is 'All'
  final List<String> _filterOptions = [
    'All',
    'Pending',
    'Assigned',
    'In Progress',
    'Resolved',
  ];

  @override
  void initState() {
    super.initState();
    _loadAllIssues();
    _searchController.addListener(_filterIssues);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterIssues() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredIssues = List.from(_getFilteredIssues());
      } else {
        _filteredIssues =
            _allIssues.where((issue) {
              return issue.description.toLowerCase().contains(query) ||
                  issue.location.toLowerCase().contains(query) ||
                  issue.status.toLowerCase().contains(query) ||
                  issue.residentName.toLowerCase().contains(query) ||
                  (issue.assignedDriverName?.toLowerCase().contains(query) ??
                      false);
            }).toList();
      }
    });
  }

  List<CleanlinessIssueModel> _getFilteredIssues() {
    if (_selectedFilter == 'All') {
      return _allIssues;
    } else {
      String filterStatus = _selectedFilter.toLowerCase();
      if (_selectedFilter == 'In Progress') {
        filterStatus = 'inprogress'; // Match the case used in _getStatusColor
      }
      return _allIssues
          .where((issue) => issue.status.toLowerCase() == filterStatus)
          .toList();
    }
  }

  Future<void> _loadAllIssues() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load all issues instead of just pending ones
      final issues = await _cleanlinessService.getAllIssues();
      setState(() {
        _allIssues = issues;
        _filterIssues(); // Apply any search query and filters
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading issues: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to load issues')));
    }
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }

  String _formatDate(DateTime dateTime) {
    return DateFormat('d MMM yyyy').format(dateTime);
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'assigned':
        return Colors.blue;
      case 'inprogress':
        return Colors.green;
      case 'resolved':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatusBadge(String status) {
    final badgeColor = _getStatusColor(status);
    String displayStatus = status;

    // Properly format status text
    if (status.toLowerCase() == 'inprogress') {
      displayStatus = 'IN PROGRESS';
    } else {
      displayStatus = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor),
      ),
      child: Text(
        displayStatus,
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Cleanliness Issues',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: primaryColor),
            onPressed: _loadAllIssues,
          ),
        ],
      ),
      bottomNavigationBar: AdminNavbar(
        currentIndex: 2, // Always 2 for this screen
        onTap: (index) {
          if (index != 2) {
            // Only navigate if not already on this tab
            if (index == 0) {
              Navigator.pushReplacementNamed(context, '/admin_home');
            } else if (index == 1) {
              Navigator.pushReplacementNamed(
                context,
                '/admin_active_drivers_screen',
              );
            } else if (index == 3) {
              Navigator.pushReplacementNamed(context, '/admin_breakdown');
            }
          }
        },
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by description, location, or status...',
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

          // Filter chips (only show when not searching)
          if (_searchController.text.isEmpty)
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
                                  _filterIssues();
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
                    ? Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    )
                    : _buildIssuesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildIssuesList() {
    final displayedIssues =
        _searchController.text.isNotEmpty
            ? _filteredIssues
            : _getFilteredIssues();

    return displayedIssues.isEmpty
        ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cleaning_services_outlined,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                _searchController.text.isNotEmpty
                    ? 'No matching issues found'
                    : 'No ${_selectedFilter.toLowerCase()} issues found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try adjusting your filters or search criteria',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        )
        : RefreshIndicator(
          onRefresh: _loadAllIssues,
          color: primaryColor,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: displayedIssues.length,
            itemBuilder: (context, index) {
              return _buildIssueCard(displayedIssues[index]);
            },
          ),
        );
  }

  Widget _buildIssueCard(CleanlinessIssueModel issue) {
    final DateFormat formatter = DateFormat('MMM d, yyyy • h:mm a');
    final String formattedDate = formatter.format(issue.reportedTime);

    // Extract rating if available in resolved issues
    int? rating;
    if (issue.status.toLowerCase() == 'resolved' &&
        issue.residentFeedback != null &&
        issue.residentFeedback!.contains('stars')) {
      // Extract the rating number from feedback like "4 stars: Great service"
      final ratingMatch = RegExp(
        r'(\d+)\s*stars',
      ).firstMatch(issue.residentFeedback!);
      if (ratingMatch != null) {
        rating = int.tryParse(ratingMatch.group(1) ?? '0');
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToIssueDetails(issue),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with description and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      issue.description,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusBadge(issue.status),
                ],
              ),

              // Request time
              const SizedBox(height: 8),
              Text(
                'Reported: $formattedDate',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),

              // Location
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      issue.location,
                      style: TextStyle(color: Colors.grey[700], fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // Reporter info
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Reported by: ${issue.residentName}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 14),
                  ),
                ],
              ),

              // Assigned driver info (if any)
              if (issue.assignedDriverName != null &&
                  issue.assignedDriverName!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.assignment_ind,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Assigned to: ${issue.assignedDriverName}',
                      style: TextStyle(color: Colors.grey[700], fontSize: 14),
                    ),
                  ],
                ),
              ],

              // Show rating for resolved issues that have feedback
              if (issue.status.toLowerCase() == 'resolved' &&
                  rating != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      'Rating: $rating/5',
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],

              // Status timeline for visual progress indication
              if (issue.status.toLowerCase() != 'pending') ...[
                const SizedBox(height: 16),
                _buildStatusBar(issue),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar(CleanlinessIssueModel issue) {
    final statuses = ['pending', 'assigned', 'inprogress', 'resolved'];
    final currentStatus = issue.status.toLowerCase();
    final currentStatusIndex = statuses.indexOf(currentStatus);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress bar
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
                      currentStatusIndex >= 1
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
                      currentStatusIndex >= 2
                          ? _getStatusColor('inprogress')
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
                      currentStatusIndex >= 3
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
              style: TextStyle(fontSize: 10, color: Colors.black),
            ),
            Text(
              'Assigned',
              style: TextStyle(
                fontSize: 10,
                color:
                    currentStatusIndex >= 1 ? Colors.black : Colors.grey[400],
              ),
            ),
            Text(
              'In Progress',
              style: TextStyle(
                fontSize: 10,
                color:
                    currentStatusIndex >= 2 ? Colors.black : Colors.grey[400],
              ),
            ),
            Text(
              'Resolved',
              style: TextStyle(
                fontSize: 10,
                color:
                    currentStatusIndex >= 3 ? Colors.black : Colors.grey[400],
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _navigateToIssueDetails(CleanlinessIssueModel issue) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildDetailSheet(issue),
    );
  }

  Widget _buildDetailSheet(CleanlinessIssueModel issue) {
    // Extract rating if available in resolved issues
    int? rating;
    String? feedback;

    if (issue.status.toLowerCase() == 'resolved' &&
        issue.residentFeedback != null &&
        issue.residentFeedback!.isNotEmpty) {
      // Extract the rating number from feedback like "4 stars: Great service"
      final ratingMatch = RegExp(
        r'(\d+)\s*stars',
      ).firstMatch(issue.residentFeedback!);
      if (ratingMatch != null) {
        rating = int.tryParse(ratingMatch.group(1) ?? '0');

        // Extract the feedback text after the "stars:" part
        final parts = issue.residentFeedback!.split(':');
        if (parts.length > 1) {
          feedback = parts.sublist(1).join(':').trim();
        }
      } else {
        // If no rating pattern found, use the whole string as feedback
        feedback = issue.residentFeedback;
      }
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(20),
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
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Current Status',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                                _buildStatusBadge(issue.status),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Issue details
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
                                const Icon(
                                  Icons.description_outlined,
                                  color: Colors.grey,
                                ),
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
                                const Icon(
                                  Icons.location_on_outlined,
                                  color: Colors.grey,
                                ),
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
                                const Icon(
                                  Icons.person_outlined,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Reported by: ${issue.residentName}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Reported: ${_formatDate(issue.reportedTime)} at ${_formatTime(issue.reportedTime)}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                            if (issue.assignedDriverName != null &&
                                issue.assignedDriverName!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.assignment_ind,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Assigned to: ${issue.assignedDriverName}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                              if (issue.assignedTime != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const SizedBox(width: 32),
                                    Text(
                                      'Assigned on: ${_formatDate(issue.assignedTime!)} at ${_formatTime(issue.assignedTime!)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],

                            // Show specific information for In Progress issues
                            if (issue.status.toLowerCase() == 'inprogress') ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(
                                        'inprogress',
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _getStatusColor('inprogress'),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.cleaning_services,
                                          color: Colors.green,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        const Text(
                                          'In Progress',
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Driver is currently addressing this issue.',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],

                            // Show resolved time for resolved issues
                            if (issue.status.toLowerCase() == 'resolved' &&
                                issue.resolvedTime != null) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline,
                                    color: Colors.purple,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Resolved on: ${_formatDate(issue.resolvedTime!)} at ${_formatTime(issue.resolvedTime!)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.purple,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Resident feedback card for resolved issues
                    if (issue.status.toLowerCase() == 'resolved' &&
                        (rating != null ||
                            (feedback != null && feedback.isNotEmpty))) ...[
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'Resident Feedback',
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (rating != null) ...[
                                    Row(
                                      children: [
                                        for (int i = 0; i < 5; i++)
                                          Icon(
                                            i < (rating)
                                                ? Icons.star
                                                : Icons.star_border,
                                            color:
                                                i < (rating)
                                                    ? Colors.amber
                                                    : Colors.grey,
                                            size: 24,
                                          ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '$rating/5',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (feedback != null &&
                                      feedback.isNotEmpty) ...[
                                    if (rating != null)
                                      const SizedBox(height: 12),
                                    Text(
                                      '"$feedback"',
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
                      ),
                    ],

                    // Image if available
                    if (issue.imageUrl.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'Issue Image',
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
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child:
                                    issue.imageUrl.startsWith('http')
                                        ? Image.network(
                                          issue.imageUrl,
                                          height: 200,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        )
                                        : Image.memory(
                                          _decodeBase64(issue.imageUrl),
                                          height: 200,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Action buttons
                    if (issue.status.toLowerCase() == 'pending')
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      AdminAssignDriverScreen(issue: issue),
                            ),
                          ).then((_) => _loadAllIssues());
                        },
                        icon: const Icon(Icons.person_add),
                        label: const Text('Assign to Driver'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),

                    const SizedBox(height: 12),

                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showDeleteConfirmation(issue);
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete Issue'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Uint8List _decodeBase64(String input) {
    String base64String = input;
    // Remove data:image/jpeg;base64, or similar prefix if present
    if (base64String.contains(',')) {
      base64String = base64String.split(',')[1];
    }
    return base64Decode(base64String);
  }

  void _showDeleteConfirmation(CleanlinessIssueModel issue) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Issue'),
            content: const Text(
              'Are you sure you want to delete this issue? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context); // Close dialog

                  // Show loading indicator
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Deleting issue...')),
                  );

                  try {
                    final success = await _cleanlinessService.deleteIssue(
                      issue.id,
                    );

                    if (success) {
                      // Refresh issues list
                      _loadAllIssues();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Issue deleted successfully'),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to delete issue')),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Error deleting issue')),
                    );
                  }
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }
}
