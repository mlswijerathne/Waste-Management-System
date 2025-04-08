import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:waste_management/models/cleanlinessIssueModel.dart';
import 'package:waste_management/screens/city_management_screens/assign_driver_screen.dart';
import 'package:waste_management/service/cleanliness_issue_service.dart';


class AdminCleanlinessIssueListScreen extends StatefulWidget {
  const AdminCleanlinessIssueListScreen({Key? key}) : super(key: key);

  @override
  State<AdminCleanlinessIssueListScreen> createState() => _AdminCleanlinessIssueListScreenState();
}

class _AdminCleanlinessIssueListScreenState extends State<AdminCleanlinessIssueListScreen> {
  final CleanlinessIssueService _cleanlinessService = CleanlinessIssueService();
  List<CleanlinessIssueModel> _pendingIssues = [];
  bool _isLoading = true;
  final Color primaryColor = const Color(0xFF59A867);

  @override
  void initState() {
    super.initState();
    _loadPendingIssues();
  }

  Future<void> _loadPendingIssues() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final issues = await _cleanlinessService.getPendingIssues();
      setState(() {
        _pendingIssues = issues;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading pending issues: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load pending issues')),
      );
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
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: primaryColor),
            onPressed: _loadPendingIssues,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _pendingIssues.isEmpty
              ? const Center(child: Text('No pending issues found'))
              : RefreshIndicator(
                  onRefresh: _loadPendingIssues,
                  color: primaryColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12.0),
                    itemCount: _pendingIssues.length,
                    itemBuilder: (context, index) {
                      final issue = _pendingIssues[index];
                      return _buildIssueCard(issue);
                    },
                  ),
                ),
    );
  }

  Widget _buildIssueCard(CleanlinessIssueModel issue) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: InkWell(
        onTap: () => _navigateToIssueDetails(issue),
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: primaryColor,
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
                      Text(
                        issue.location,
                        style: TextStyle(
                          fontSize: 14.0,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        'Reported by: ${issue.residentName}',
                        style: TextStyle(
                          fontSize: 13.0,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTime(issue.reportedTime),
                      style: const TextStyle(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _formatDate(issue.reportedTime),
                      style: TextStyle(
                        fontSize: 12.0,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    _buildStatusChip(issue.status),
                  ],
                ),
                const SizedBox(width: 4.0),
                Icon(
                  Icons.chevron_right,
                  color: primaryColor.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10.0,
          fontWeight: FontWeight.bold,
          color: primaryColor,
        ),
      ),
    );
  }

  Color _getIssueColor(String status) {
    // Using the primary color for all statuses
    return primaryColor;
  }

  void _navigateToIssueDetails(CleanlinessIssueModel issue) {
    // Navigate to issue details screen
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => AdminIssueDetailsScreen(issue: issue),
    //   ),
    // );
    
    // For now just show a modal bottom sheet with quick actions
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
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
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Location: ${issue.location}',
            style: TextStyle(fontSize: 14),
          ),
          Text(
            'Reported by: ${issue.residentName}',
            style: TextStyle(fontSize: 14),
          ),
          Text(
            'Reported: ${_formatTime(issue.reportedTime)}, ${_formatDate(issue.reportedTime)}',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          if (issue.imageUrl.isNotEmpty) ...[
            const Text(
              'Image:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: issue.imageUrl.startsWith('http')
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
    Expanded(
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminAssignDriverScreen(issue: issue,),
            ),
          );
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Assign to Driver'),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    ),
  ],
),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Delete issue confirmation
                    _showDeleteConfirmation(issue);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete Issue'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
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
      builder: (context) => AlertDialog(
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
              Navigator.pop(context); // Close bottom sheet
              
              // Show loading indicator
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Deleting issue...')),
              );
              
              try {
                final success = await _cleanlinessService.deleteIssue(issue.id);
                
                if (success) {
                  // Refresh issues list
                  _loadPendingIssues();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Issue deleted successfully')),
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