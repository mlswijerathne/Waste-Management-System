import 'package:flutter/material.dart';
import 'package:waste_management/models/cleanlinessIssueModel.dart';
import 'package:waste_management/service/cleanliness_issue_service.dart';
import 'package:waste_management/service/auth_service.dart';
import 'package:intl/intl.dart';

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
  bool _isLoading = true;
  String _selectedStatus = 'In Progress'; // Default filter
  
  @override
  void initState() {
    super.initState();
    _loadUserIssues();
  }
  
  Future<void> _loadUserIssues() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        // Use stream instead of future for real-time updates
        _issueService.getResidentIssuesStream(currentUser.uid).listen((issues) {
          setState(() {
            _issues = issues;
            _isLoading = false;
          });
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user issues: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Filter issues based on selected status
  List<CleanlinessIssueModel> get _filteredIssues {
    String statusFilter = _selectedStatus.toLowerCase().replaceAll(' ', '');
    
    return _issues.where((issue) {
      if (statusFilter == 'inprogress') {
        return issue.status == 'inProgress' || issue.status == 'assigned';
      } else {
        return issue.status == statusFilter;
      }
    }).toList();
  }
  
  // Format the reported time
  String _formatReportedTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reportDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (reportDate == today) {
      return 'Today, ${DateFormat('hh:mm a').format(dateTime)}';
    } else {
      return 'Feb ${dateTime.day}, ${DateFormat('hh:mm a').format(dateTime)}';
    }
  }
  
  // Get status message based on issue status
  String _getStatusMessage(CleanlinessIssueModel issue) {
    switch (issue.status) {
      case 'pending':
        return 'The team is reviewing your report';
      case 'assigned':
      case 'inProgress':
        return 'A cleaning team has been assigned to this location.';
      case 'resolved':
        return 'Your ${issue.description.toLowerCase()} request has been completed.';
      default:
        return '';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent Reports & Requests'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Status filter tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildFilterTab('In Progress'),
                const SizedBox(width: 8),
                _buildFilterTab('Pending'),
                const SizedBox(width: 8),
                _buildFilterTab('Resolved'),
              ],
            ),
          ),
          
          // Issues list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredIssues.isEmpty
                    ? const Center(child: Text('No reports found'))
                    : ListView.builder(
                        itemCount: _filteredIssues.length,
                        itemBuilder: (context, index) {
                          final issue = _filteredIssues[index];
                          return _buildIssueCard(issue);
                        },
                      ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilterTab(String status) {
    final isSelected = _selectedStatus == status;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedStatus = status;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF59A867) : Colors.grey[300],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            status,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildIssueCard(CleanlinessIssueModel issue) {
    // Determine if showing "Reported" or "Updated" based on status
    final bool isUpdated = issue.status == 'resolved';
    final String timeLabel = isUpdated ? 'Updated' : 'Reported';
    
    // Format time for display
    String timeText;
    if (isUpdated && issue.resolvedTime != null) {
      timeText = _formatReportedTime(issue.resolvedTime!);
    } else {
      timeText = _formatReportedTime(issue.reportedTime);
    }
    
    // Status icon color
    final Color statusIconColor = isUpdated 
        ? Colors.green 
        : issue.status == 'pending' 
            ? Colors.orange 
            : const Color(0xFF59A867);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to issue details
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    issue.description,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _getStatusMessage(issue),
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    isUpdated ? Icons.check_circle : Icons.access_time,
                    size: 16,
                    color: statusIconColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$timeLabel: $timeText',
                    style: TextStyle(
                      fontSize: 12,
                      color: statusIconColor,
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