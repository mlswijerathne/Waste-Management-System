import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:waste_management/models/cleanlinessIssueModel.dart';
import 'package:waste_management/service/cleanliness_issue_service.dart';
import 'package:waste_management/service/auth_service.dart';

class DriverCleanlinessIssueListScreen extends StatefulWidget {
  const DriverCleanlinessIssueListScreen({Key? key}) : super(key: key);

  @override
  State<DriverCleanlinessIssueListScreen> createState() =>
      _DriverCleanlinessIssueListScreenState();
}

class _DriverCleanlinessIssueListScreenState
    extends State<DriverCleanlinessIssueListScreen>
    with SingleTickerProviderStateMixin {
  final CleanlinessIssueService _cleanlinessService = CleanlinessIssueService();
  final AuthService _authService = AuthService();
  List<CleanlinessIssueModel> _allIssues = [];
  List<CleanlinessIssueModel> _filteredIssues = [];
  bool _isLoading = true;
  String _driverId = '';
  final Color primaryColor = const Color(0xFF59A867);

  // Tabs
  late TabController _tabController;
  final List<String> _tabLabels = ['Assigned', 'In Progress', 'Resolved'];

  // Search functionality
  final TextEditingController _searchController = TextEditingController();

  void _filterIssues() {
    if (!mounted) return;

    final query = _searchController.text.toLowerCase();

    setState(() {
      // First, filter by tab
      List<CleanlinessIssueModel> tabFiltered;

      switch (_tabController.index) {
        case 0: // Assigned
          tabFiltered =
              _allIssues.where((issue) => issue.status == 'assigned').toList();
          break;
        case 1: // In Progress
          tabFiltered =
              _allIssues
                  .where((issue) => issue.status == 'inProgress')
                  .toList();
          break;
        case 2: // Resolved
          tabFiltered =
              _allIssues.where((issue) => issue.status == 'resolved').toList();
          break;
        default:
          tabFiltered = _allIssues;
      }

      // Then, apply search filter if there's a query
      if (query.isEmpty) {
        _filteredIssues = tabFiltered;
      } else {
        _filteredIssues =
            tabFiltered.where((issue) {
              return issue.description.toLowerCase().contains(query) ||
                  issue.location.toLowerCase().contains(query) ||
                  issue.residentName.toLowerCase().contains(query);
            }).toList();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _searchController.addListener(_filterIssues);
    _getCurrentDriverId();
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
      _filterIssues();
    }
  }

  Future<void> _getCurrentDriverId() async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        setState(() {
          _driverId = currentUser.uid;
        });
        _loadAssignedIssues();
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

  Future<void> _loadAssignedIssues() async {
    if (_driverId.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get all issues for this driver, including historical ones
      final List<CleanlinessIssueModel> issues = [];

      // Get assigned and in-progress issues
      final activeIssues = await _cleanlinessService.getDriverAssignedIssues(
        _driverId,
      );
      issues.addAll(activeIssues);

      // For resolved issues, we need a separate query
      final resolvedIssues = await _cleanlinessService.getDriverResolvedIssues(
        _driverId,
      );

      // Combine all issues, removing duplicates by ID
      for (final issue in resolvedIssues) {
        if (!issues.any((i) => i.id == issue.id)) {
          issues.add(issue);
        }
      }

      if (mounted) {
        setState(() {
          _allIssues = issues;
          _filterIssues();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading assigned issues: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load assigned issues')),
        );
      }
    }
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }

  String _formatDate(DateTime dateTime) {
    return DateFormat('d MMM yyyy').format(dateTime);
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
            onPressed: _loadAssignedIssues,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryColor,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey[600],
          tabs: _tabLabels.map((label) => Tab(text: label)).toList(),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search issues by location, description...',
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

          // Main content
          Expanded(
            child:
                _isLoading
                    ? Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    )
                    : _filteredIssues.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                      onRefresh: _loadAssignedIssues,
                      color: primaryColor,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12.0),
                        itemCount: _filteredIssues.length,
                        itemBuilder: (context, index) {
                          final issue = _filteredIssues[index];
                          return _buildIssueCard(issue);
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final String tabLabel = _tabLabels[_tabController.index];

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No $tabLabel Issues',
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
              _searchController.text.isEmpty
                  ? 'You have no ${tabLabel.toLowerCase()} cleanliness issues'
                  : 'No matching issues found for your search',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadAssignedIssues,
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        issue.description,
                        style: const TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              issue.location,
                              style: TextStyle(
                                fontSize: 14.0,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        'Reported by: ${issue.residentName}',
                        style: TextStyle(
                          fontSize: 13.0,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 6.0),
                      if (issue.assignedTime != null)
                        Text(
                          'Assigned: ${_formatDate(issue.assignedTime!)}',
                          style: TextStyle(
                            fontSize: 12.0,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[500],
                          ),
                        ),
                      if (issue.resolvedTime != null)
                        Text(
                          'Resolved: ${_formatDate(issue.resolvedTime!)}',
                          style: TextStyle(
                            fontSize: 12.0,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[500],
                          ),
                        ),
                      // Show resident feedback if available and issue is resolved
                      if (issue.status == 'resolved' &&
                          issue.residentConfirmed == true &&
                          issue.residentFeedback != null)
                        Row(
                          children: [
                            Icon(Icons.star, size: 14, color: Colors.amber),
                            const SizedBox(width: 2),
                            Text(
                              'Rated: ${issue.residentFeedback}',
                              style: TextStyle(
                                fontSize: 12.0,
                                fontWeight: FontWeight.w500,
                                color: Colors.amber[700],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildStatusChip(issue.status),
                        // Show a star icon if the issue is resolved and has feedback
                        if (issue.status == 'resolved' &&
                            issue.residentConfirmed == true &&
                            issue.residentFeedback != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            
                          ),
                      ],
                    ),
                    const SizedBox(height: 12.0),
                    Text(
                      _formatTime(issue.reportedTime),
                      style: const TextStyle(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _formatDate(issue.reportedTime),
                      style: TextStyle(fontSize: 12.0, color: Colors.grey[600]),
                    ),
                    // Add action buttons for non-resolved issues
                    if (issue.status != 'resolved') ...[
                      const SizedBox(height: 8.0),

                      if (issue.status == 'assigned')
                        ElevatedButton.icon(
                          onPressed:
                              () => _updateIssueStatus(issue, 'inProgress'),
                          icon: const Icon(Icons.play_arrow, size: 16),
                          label: const Text('Start Work'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            minimumSize: const Size(40, 32),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),

                      if (issue.status == 'inProgress')
                        ElevatedButton.icon(
                          onPressed:
                              () => _updateIssueStatus(issue, 'resolved'),
                          icon: const Icon(Icons.check_circle, size: 16),
                          label: const Text('Mark Resolved'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            minimumSize: const Size(40, 32),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
                const SizedBox(width: 4.0),
                Icon(Icons.chevron_right, color: primaryColor.withOpacity(0.5)),
              ],
            ),
          ),
        ),
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
    // Show a modal bottom sheet with quick actions
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildQuickActionsSheet(issue),
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

  Widget _buildQuickActionsSheet(CleanlinessIssueModel issue) {
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
          if (issue.resolvedTime != null)
            Text(
              'Resolved: ${_formatTime(issue.resolvedTime!)}, ${_formatDate(issue.resolvedTime!)}',
              style: TextStyle(fontSize: 14),
            ),

          // Resident feedback section
          if (issue.status == 'resolved' &&
              issue.residentConfirmed == true &&
              issue.residentFeedback != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text(
                        'Resident Feedback',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(issue.residentFeedback!, style: TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (issue.imageUrl.isNotEmpty) ...[
            const Text(
              'Image:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child:
                  issue.imageUrl.startsWith('http')
                      ? Image.network(
                        issue.imageUrl,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                      : Image.memory(
                        _decodeBase64(issue.imageUrl),
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
            ),
          ],
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
                      // Launch maps with the location coordinates
                      // Implementation would depend on platform and map provider
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
    // Check if we're in a modal bottom sheet before popping
    if (ModalRoute.of(context)?.isCurrent == false) {
      Navigator.pop(context); // Close the bottom sheet only if it's open
    }

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
        _loadAssignedIssues();
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
