import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:waste_management/models/cleanlinessIssueModel.dart';
import 'package:waste_management/service/cleanliness_issue_service.dart';

class DriverCleanlinessIssueTab extends StatefulWidget {
  final String driverId;
  final Function(bool) setLoading;

  const DriverCleanlinessIssueTab({
    Key? key,
    required this.driverId,
    required this.setLoading,
  }) : super(key: key);

  @override
  State<DriverCleanlinessIssueTab> createState() =>
      _DriverCleanlinessIssueTabState();
}

class _DriverCleanlinessIssueTabState extends State<DriverCleanlinessIssueTab>
    with AutomaticKeepAliveClientMixin {
  final CleanlinessIssueService _cleanlinessService = CleanlinessIssueService();
  List<CleanlinessIssueModel> _assignedIssues = [];
  bool _isLoading = true;
  final Color primaryColor = const Color(0xFF59A867);

  // For filtering
  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'Assigned', 'In Progress'];
  List<CleanlinessIssueModel> _filteredIssues = [];

  // Stream subscription for real-time updates
  StreamSubscription<List<CleanlinessIssueModel>>?
  _cleanlinessStreamSubscription;

  @override
  void initState() {
    super.initState();
    _loadAssignedIssues();
    _setupStream();
  }

  @override
  void dispose() {
    _cleanlinessStreamSubscription?.cancel();
    super.dispose();
  }

  void _setupStream() {
    if (widget.driverId.isEmpty) return;

    // Set up real-time stream for cleanliness issues
    _cleanlinessStreamSubscription = _cleanlinessService
        .getDriverIssuesStream(widget.driverId)
        .listen(
          (issues) {
            if (mounted) {
              setState(() {
                _assignedIssues = issues;
                _applyFilters();
                _isLoading = false;
                widget.setLoading(false);
              });
            }
          },
          onError: (e) {
            print('Error in cleanliness stream: $e');
          },
        );
  }

  Future<void> _loadAssignedIssues() async {
    if (widget.driverId.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final issues = await _cleanlinessService.getDriverAssignedIssues(
        widget.driverId,
      );
      if (mounted) {
        setState(() {
          _assignedIssues = issues;
          _applyFilters();
          _isLoading = false;
          widget.setLoading(false);
        });
      }
    } catch (e) {
      print('Error loading assigned issues: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          widget.setLoading(false);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load assigned issues')),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      if (_selectedFilter == 'All') {
        _filteredIssues = List.from(_assignedIssues);
      } else if (_selectedFilter == 'Assigned') {
        _filteredIssues =
            _assignedIssues
                .where((issue) => issue.status == 'assigned')
                .toList();
      } else if (_selectedFilter == 'In Progress') {
        _filteredIssues =
            _assignedIssues
                .where((issue) => issue.status == 'inProgress')
                .toList();
      }
    });
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }

  String _formatDate(DateTime dateTime) {
    return DateFormat('d MMM yyyy').format(dateTime);
  }

  Uint8List _decodeBase64(String input) {
    String base64String = input;
    // Remove data:image/jpeg;base64, or similar prefix if present
    if (base64String.contains(',')) {
      base64String = base64String.split(',')[1];
    }
    return base64Decode(base64String);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
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
                              _applyFilters();
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Issues Found',
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
              _selectedFilter == 'All'
                  ? 'When you are assigned to cleanliness issues, they will appear here'
                  : 'No ${_selectedFilter.toLowerCase()} cleanliness issues found',
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

    widget.setLoading(true);
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
        await _loadAssignedIssues();
      } else {
        setState(() {
          _isLoading = false;
          widget.setLoading(false);
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
        widget.setLoading(false);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error updating issue status'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  bool get wantKeepAlive => true;
}
