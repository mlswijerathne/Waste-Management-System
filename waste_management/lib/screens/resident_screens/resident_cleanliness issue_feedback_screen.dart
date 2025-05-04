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
    return DateFormat('d MMM yyyy').format(dateTime);
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
                  padding: const EdgeInsets.all(12.0),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(CleanlinessIssueModel issue) {
    final resolvedTime = issue.resolvedTime ?? DateTime.now();

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: InkWell(
        onTap: () => _showIssueDetailsAndConfirmation(issue),
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: primaryColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Issue Resolved',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          issue.description,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Location: ${issue.location}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (issue.assignedDriverName != null)
                          Text(
                            'Resolved by: ${issue.assignedDriverName}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _getTimeElapsed(resolvedTime),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showIssueDetailsAndConfirmation(issue),
                    icon: const Icon(Icons.rate_review, size: 16),
                    label: const Text('Confirm & Review'),
                    style: TextButton.styleFrom(
                      foregroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
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
    final TextEditingController _feedbackController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Padding(
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
                        'Confirm Resolution',
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
                  Text(
                    'Issue Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    issue.description,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Location: ${issue.location}',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reported: ${_formatDate(issue.reportedTime)}',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  if (issue.resolvedTime != null)
                    Text(
                      'Resolved: ${_formatDate(issue.resolvedTime!)}',
                      style: TextStyle(fontSize: 14),
                    ),
                  const SizedBox(height: 20),
                  const Text(
                    'Provide Feedback (Optional)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _feedbackController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Share your thoughts about the resolution...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            side: BorderSide(color: Colors.grey[400]!),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            // Submit confirmation and feedback
                            final success = await _cleanlinessService
                                .updateResidentFeedback(
                                  issueId: issue.id,
                                  confirmed: true,
                                  feedback: _feedbackController.text.trim(),
                                );

                            Navigator.pop(context);

                            if (success) {
                              // Show success message
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Thank you for confirming the resolution!',
                                  ),
                                  backgroundColor: Color(0xFF59A867),
                                ),
                              );
                              // Refresh the list
                              _loadResolvedIssues();
                            } else {
                              // Show error message
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
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Confirm Resolution'),
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
