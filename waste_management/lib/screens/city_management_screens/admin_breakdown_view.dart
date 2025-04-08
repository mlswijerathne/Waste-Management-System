import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:waste_management/models/breakdownReportModel.dart';

class AdminBreakdownViewScreen extends StatefulWidget {
  final String reportId;
  final String driverName;

  const AdminBreakdownViewScreen({
    required this.reportId,
    required this.driverName,
    Key? key,
  }) : super(key: key);

  @override
  State<AdminBreakdownViewScreen> createState() =>
      _AdminBreakdownViewScreenState();
}

class _AdminBreakdownViewScreenState extends State<AdminBreakdownViewScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  BreakdownReport? _report;

  @override
  void initState() {
    super.initState();
    _fetchBreakdownReport();
  }

  Future<void> _fetchBreakdownReport() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get breakdown report
      final DocumentSnapshot reportDoc =
          await _firestore
              .collection('breakdown_reports')
              .doc(widget.reportId)
              .get();

      if (reportDoc.exists) {
        final reportData = reportDoc.data() as Map<String, dynamic>;
        final report = BreakdownReport.fromMap({
          ...reportData,
          'id': reportDoc.id,
        });

        setState(() {
          _report = report;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Breakdown report not found')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error fetching breakdown report: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error loading breakdown report')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Breakdown Details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _report == null
              ? const Center(child: Text('Report not found'))
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoCard(),
                    const SizedBox(height: 20),
                    _buildDetailsCard(),
                  ],
                ),
              ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.black),
                      children: [
                        const TextSpan(
                          text: 'Driver: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: widget.driverName),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.green),
                const SizedBox(width: 8),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black),
                    children: [
                      const TextSpan(
                        text: 'Reported: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: DateFormat(
                          'MMM d, yyyy • h:mm a',
                        ).format(_report!.createdAt),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.hourglass_bottom, color: Colors.green),
                const SizedBox(width: 8),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black),
                    children: [
                      const TextSpan(
                        text: 'Expected Delay: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            '${_report!.delay.hours} hours ${_report!.delay.minutes} minutes',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_report!.location != null && _report!.location!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(color: Colors.black),
                        children: [
                          const TextSpan(
                            text: 'Location: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: _report!.location!),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.build, color: Colors.amber[700]),
                const SizedBox(width: 8),
                const Text(
                  'Issue Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    _getIssueIcon(_report!.issueType),
                    color: Colors.green,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getIssueTypeText(_report!.issueType),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (_report!.vehicleId != null &&
                            _report!.vehicleId!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Vehicle ID: ${_report!.vehicleId}',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Description',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                _report!.description,
                style: const TextStyle(fontSize: 15),
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

  IconData _getIssueIcon(BreakdownIssueType type) {
    switch (type) {
      case BreakdownIssueType.breakIssue:
        return Icons.car_repair;
      case BreakdownIssueType.engineFailure:
        return Icons.settings_suggest;
      case BreakdownIssueType.tirePuncture:
        return Icons.tire_repair;
      case BreakdownIssueType.runningOutOfFuel:
        return Icons.local_gas_station;
      case BreakdownIssueType.hydraulicLeak:
        return Icons.water_drop;
      case BreakdownIssueType.compressorJam:
        return Icons.compress;
      case BreakdownIssueType.other:
        return Icons.error_outline;
    }
  }
}
