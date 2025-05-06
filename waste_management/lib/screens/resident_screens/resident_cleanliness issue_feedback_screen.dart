import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:waste_management/models/cleanlinessIssueModel.dart';
import 'package:waste_management/service/cleanliness_issue_service.dart';
import 'package:waste_management/service/auth_service.dart';
import 'package:waste_management/widgets/resident_navbar.dart';

class ResidentCleanlinessIssueFeedbackScreen extends StatefulWidget {
  final CleanlinessIssueModel? selectedIssue;

  const ResidentCleanlinessIssueFeedbackScreen({Key? key, this.selectedIssue})
    : super(key: key);

  @override
  State<ResidentCleanlinessIssueFeedbackScreen> createState() =>
      _ResidentCleanlinessIssueFeedbackScreenState();
}

class _ResidentCleanlinessIssueFeedbackScreenState
    extends State<ResidentCleanlinessIssueFeedbackScreen> {
  final CleanlinessIssueService _cleanlinessService = CleanlinessIssueService();
  final AuthService _authService = AuthService();
  List<CleanlinessIssueModel> _resolvedIssues = [];
  bool _isLoading = true;
  String _residentId = '';
  final Color primaryColor = const Color(0xFF59A867);
  final Color accentColor = const Color(0xFF9C27B0); // Purple accent color
  int _currentIndex = 2; // Set to 2 since this is the "Notification" tab

  @override
  void initState() {
    super.initState();
    // If a specific issue was selected, show its details immediately
    if (widget.selectedIssue != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showIssueDetailsAndConfirmation(widget.selectedIssue!);
      });
    }
    _getCurrentResidentId();
  }

  Future<void> _getCurrentResidentId() async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        setState(() {
          _residentId = currentUser.uid;
        });
        _loadResolvedIssues();
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

  Future<void> _loadResolvedIssues() async {
    if (_residentId.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get all issues reported by this resident
      final allIssues = await _cleanlinessService.getResidentIssues(
        _residentId,
      );

      // Filter for only resolved issues
      final resolved =
          allIssues
              .where(
                (issue) =>
                    issue.status == 'resolved' &&
                    (issue.residentConfirmed == null ||
                        issue.residentConfirmed == false),
              )
              .toList();

      setState(() {
        _resolvedIssues = resolved;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading resolved issues: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load notifications')),
      );
    }
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }

  String _formatDate(DateTime dateTime) {
    return DateFormat('MMM d, yyyy').format(dateTime);
  }

  String _formatDateWithTime(DateTime dateTime) {
    return DateFormat('MMM d, yyyy • h:mm a').format(dateTime);
  }

  String _getTimeElapsed(DateTime resolvedTime) {
    final now = DateTime.now();
    final difference = now.difference(resolvedTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  // Handle navigation bar taps
  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    
    // Navigate to appropriate screen based on the tab index
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/resident/home');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/resident/reports');
        break;
      case 2:
        // Already on notifications screen
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/resident/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false, // Remove back button
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: primaryColor),
            onPressed: _loadResolvedIssues,
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator(color: primaryColor))
              : _resolvedIssues.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                onRefresh: _loadResolvedIssues,
                color: primaryColor,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _resolvedIssues.length,
                  itemBuilder: (context, index) {
                    final issue = _resolvedIssues[index];
                    return _buildNotificationCard(issue);
                  },
                ),
              ),
      bottomNavigationBar: ResidentNavbar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Notifications',
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
              'When your reported issues are resolved, you will receive notifications here',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadResolvedIssues,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(CleanlinessIssueModel issue) {
    final resolvedTime = issue.resolvedTime ?? DateTime.now();

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: InkWell(
        onTap: () => _showIssueDetailsAndConfirmation(issue),
        borderRadius: BorderRadius.circular(16.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and status badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Issue description
                  Expanded(
                    child: Text(
                      issue.description,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'COMPLETED',
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Request details
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Requested: ${_formatDateWithTime(issue.reportedTime)}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Location
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Location: ${issue.location}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Assigned driver
              if (issue.assignedDriverName != null)
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Resolved by: ${issue.assignedDriverName}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                
              const SizedBox(height: 16),
              
              // Progress bar
              LinearProgressIndicator(
                value: 1.0,  // Always 100% for resolved issues
                backgroundColor: Colors.grey[300],
                color: accentColor,
                minHeight: 4,
              ),
              
              const SizedBox(height: 8),
              
              // Status labels
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Requested',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    Text(
                      'Assigned',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    Text(
                      'Collected',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    Text(
                      'Completed',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Bottom row with time and action button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Time elapsed
                  Text(
                    _getTimeElapsed(resolvedTime),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  
                  // Action button
                  ElevatedButton(
                    onPressed: () => _showIssueDetailsAndConfirmation(issue),
                    child: const Text('Give Feedback'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
  
  void _showIssueDetailsAndConfirmation(CleanlinessIssueModel issue) {
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
                      'Completed Issue Details',
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
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
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
                      _buildDetailRow('Requested', _formatDateWithTime(issue.reportedTime)),
                      const SizedBox(height: 8),
                      _buildDetailRow('Location', issue.location),
                      if (issue.assignedDriverName != null) ...[
                        const SizedBox(height: 8),
                        _buildDetailRow('Resolved by', issue.assignedDriverName!),
                      ],
                      if (issue.resolvedTime != null) ...[
                        const SizedBox(height: 8),
                        _buildDetailRow('Completed', _formatDateWithTime(issue.resolvedTime!)),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Image preview (if available)
                if (issue.imageUrl.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Image',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          // Convert base64 to bytes if it's a base64 string
                          Uri.parse(issue.imageUrl).data?.contentAsBytes() ?? 
                              Uint8List(0),
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 100,
                              width: double.infinity,
                              color: Colors.grey[300],
                              child: const Center(
                                child: Text('Unable to load image'),
                              ),
                            );
                          },
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                
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
                    onPressed: _rating > 0 ? () async {
                      // Submit the feedback
                      final success = await _cleanlinessService.updateResidentFeedback(
                        issueId: issue.id,
                        confirmed: true,
                        feedback: "${_rating} stars: ${_feedbackController.text}",
                      );
                      
                      Navigator.pop(context);
                      
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Thank you for your feedback!'),
                            backgroundColor: primaryColor,
                          ),
                        );
                        
                        // Refresh the list
                        _loadResolvedIssues();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Failed to submit feedback. Please try again.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } : null, // Disable button if no rating is selected
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: Colors.grey[300],
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