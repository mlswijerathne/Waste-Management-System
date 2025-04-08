import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:waste_management/models/breakdownReportModel.dart';
import 'package:waste_management/screens/city_management_screens/admin_breakdown_view.dart';
import 'package:waste_management/models/userModel.dart';

class AdminBreakdownListScreen extends StatefulWidget {
  const AdminBreakdownListScreen({Key? key}) : super(key: key);

  @override
  State<AdminBreakdownListScreen> createState() =>
      _AdminBreakdownListScreenState();
}

class _AdminBreakdownListScreenState extends State<AdminBreakdownListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _breakdownReports = [];

  @override
  void initState() {
    super.initState();
    _fetchBreakdownReports();
  }

  Future<void> _fetchBreakdownReports() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get all breakdown reports
      final QuerySnapshot reportSnapshot =
          await _firestore
              .collection('breakdown_reports')
              .orderBy('createdAt', descending: true)
              .get();

      List<Map<String, dynamic>> reports = [];

      // Fetch driver details for each report
      for (var doc in reportSnapshot.docs) {
        final reportData = doc.data() as Map<String, dynamic>;
        final userId = reportData['userId'] as String;

        // Get user data
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final UserModel user = UserModel.fromMap(userData);

          // Create combined data
          reports.add({
            'report': BreakdownReport.fromMap({...reportData, 'id': doc.id}),
            'userName': user.name,
          });
        }
      }

      setState(() {
        _breakdownReports = reports;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching breakdown reports: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error loading breakdown reports')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Breakdown Reports'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchBreakdownReports,
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _breakdownReports.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.build_circle_outlined,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No breakdown reports found',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _fetchBreakdownReports,
                child: ListView.builder(
                  itemCount: _breakdownReports.length,
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (context, index) {
                    final reportData = _breakdownReports[index];
                    final report = reportData['report'] as BreakdownReport;
                    final userName = reportData['userName'] as String;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: BreakdownNotificationCard(
                        report: report,
                        driverName: userName,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => AdminBreakdownViewScreen(
                                    reportId: report.id,
                                    driverName: userName,
                                  ),
                            ),
                          ).then((_) => _fetchBreakdownReports());
                        },
                      ),
                    );
                  },
                ),
              ),
    );
  }
}

class BreakdownNotificationCard extends StatelessWidget {
  final BreakdownReport report;
  final String driverName;
  final VoidCallback onTap;

  const BreakdownNotificationCard({
    required this.report,
    required this.driverName,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  String _formatDateTime(DateTime dateTime) {
    final today = DateTime.now();
    final difference = today.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today at ${DateFormat('h:mm a').format(dateTime)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${DateFormat('h:mm a').format(dateTime)}';
    } else {
      return DateFormat('MMM d, yyyy • h:mm a').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            // Green vertical line
            Container(
              width: 6,
              height: 115,
              decoration: const BoxDecoration(
                color: Color.fromRGBO(76, 175, 80, 1),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.blueGrey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            driverName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Colors.black87,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getIssueTypeText(report.issueType),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${report.delay.hours}h ${report.delay.minutes}m delay',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_today, // More modern icon
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDateTime(report.createdAt),
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2,
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
          ],
        ),
      ),
    );
  }

  String _getIssueTypeText(BreakdownIssueType type) {
    switch (type) {
      case BreakdownIssueType.breakIssue:
        return 'Break Issue';
      case BreakdownIssueType.engineFailure:
        return 'Engine Failure';
      case BreakdownIssueType.tirePuncture:
        return 'Tire Puncture';
      case BreakdownIssueType.runningOutOfFuel:
        return 'Running Out of Fuel';
      case BreakdownIssueType.hydraulicLeak:
        return 'Hydraulic Leak';
      case BreakdownIssueType.compressorJam:
        return 'Compressor Jam';
      case BreakdownIssueType.other:
        return 'Other Issue';
    }
  }
}
