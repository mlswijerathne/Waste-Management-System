import 'package:flutter/material.dart';
import 'package:waste_management/models/cleanlinessIssueModel.dart';
import 'package:waste_management/service/cleanliness_issue_service.dart';
import 'package:waste_management/service/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:waste_management/widgets/resident_navbar.dart';
import 'package:waste_management/screens/resident_screens/resident_cleanliness%20issue_feedback_screen.dart';


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
  int _currentIndex = 1; // Set to 1 since this is the "Report" tab

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
        return 'Collected';
      case 'resolved':
        return 'Completed';
      default:
        return '';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'resolved':
        return Colors.purple;
      case 'inProgress':
        return Colors.blue;
      case 'assigned':
        return Colors.orange;
      case 'pending':
      default:
        return Colors.grey;
    }
  }

  // Get progress indicator value based on status
  double _getProgressValue(String status) {
    switch (status) {
      case 'pending':
        return 0.25;
      case 'assigned':
        return 0.5;
      case 'inProgress':
        return 0.75;
      case 'resolved':
        return 1.0;
      default:
        return 0.0;
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent Reports & Requests'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Status filter tabs
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
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
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredIssues.isEmpty
                    ? const Center(child: Text('No reports found'))
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
    final statusColor = _getStatusColor(issue.status);
    final statusText = issue.status == 'resolved' ? 'COMPLETED' : _getStatusText(issue.status).toUpperCase();
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          if (issue.status == 'resolved') {
            _showFeedbackDialog(issue);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    issue.description,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
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
              
              const SizedBox(height: 12),
              
              // Request details
              Text(
                'Requested: ${_formatDate(issue.reportedTime)}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Location with icon
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${issue.latitude.toStringAsFixed(6)}, ${issue.longitude.toStringAsFixed(6)}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Assigned to
              if (issue.assignedDriverName != null)
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Assigned to: ${issue.assignedDriverName}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              
              const SizedBox(height: 8.0),
                
              // Progress bar
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _getProgressValue(issue.status),
                backgroundColor: Colors.grey[300],
                color: statusColor,
                minHeight: 4,
              ),
              
              const SizedBox(height: 8),
              
              // Status labels
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Requested',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: issue.status == 'pending' ? statusColor : Colors.grey[600],
                    ),
                  ),
                  Text(
                    'Assigned',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: issue.status == 'assigned' ? statusColor : Colors.grey[600],
                    ),
                  ),
                  Text(
                    'Collected',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: issue.status == 'inProgress' ? statusColor : Colors.grey[600],
                    ),
                  ),
                  Text(
                    'Completed',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: issue.status == 'resolved' ? statusColor : Colors.grey[600],
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

  void _showFeedbackDialog(CleanlinessIssueModel issue) {
    int _rating = 0;
    final TextEditingController _feedbackController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Completed Request Details',
                      style: TextStyle(
                        fontSize: 18,
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
                
                // Issue details
                Text(
                  issue.description,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF59A867),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Details grid
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow('Requested', _formatDate(issue.reportedTime)),
                      const SizedBox(height: 8),
                      _buildDetailRow('Location', issue.location),
                      if (issue.assignedDriverName != null) ...[
                        const SizedBox(height: 8),
                        _buildDetailRow('Resolved by', issue.assignedDriverName!),
                      ],
                      if (issue.resolvedTime != null) ...[
                        const SizedBox(height: 8),
                        _buildDetailRow('Completed', _formatDate(issue.resolvedTime!)),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Star rating
                const Text(
                  'Rate this resolution',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < _rating ? Icons.star : Icons.star_border,
                        color: index < _rating ? Colors.amber : Colors.grey,
                        size: 32,
                      ),
                      onPressed: () {
                        setState(() {
                          _rating = index + 1;
                        });
                      },
                    );
                  }),
                ),
                
                const SizedBox(height: 16),
                
                // Feedback text field
                const Text(
                  'Additional Feedback (Optional)',
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
                    hintText: 'Tell us about your experience...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      // Submit the feedback
                      final success = await _issueService.updateResidentFeedback(
                        issueId: issue.id,
                        confirmed: true,
                        feedback: "${_rating} stars: ${_feedbackController.text}",
                      );
                      
                      Navigator.pop(context);
                      
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Thank you for your feedback!'),
                            backgroundColor: Color(0xFF59A867),
                          ),
                        );
                        
                        // Refresh the list
                        _loadUserIssues();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Failed to submit feedback. Please try again.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF59A867),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$label:',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}