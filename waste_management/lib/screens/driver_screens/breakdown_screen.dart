import 'package:flutter/material.dart';
import 'package:waste_management/models/breakdown_report_model.dart';
import 'package:waste_management/models/userModel.dart';
import 'package:waste_management/service/auth_service.dart';
import 'package:waste_management/service/breakdown_service.dart';
import 'package:intl/intl.dart';

class BreakdownReportScreen extends StatefulWidget {
  const BreakdownReportScreen({super.key});

  @override
  State<BreakdownReportScreen> createState() => _BreakdownReportScreenState();
}

class _BreakdownReportScreenState extends State<BreakdownReportScreen> {
  final BreakdownService breakdownService = BreakdownService();
  final AuthService _authService = AuthService();

  // Issue type options matching screenshot
  final List<String> _issueTypes = [
    'Break issue',
    'Engine failure',
    'Tire punctture',
    'Running out of fuel',
    'Hydraulic leak',
    'Compressor jam',
  ];

  // Selected values
  String? _selectedIssueType;
  int _delayHours = 0;
  int _delayMinutes = 0;
  final TextEditingController _descriptionController = TextEditingController();

  // User details
  String _currentUserName = 'Unknown User';

  @override
  void initState() {
    super.initState();
    _fetchCurrentUser();
  }

  // Fetch current user details
  void _fetchCurrentUser() async {
    try {
      UserModel? currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        setState(() {
          // Use display name 
          _currentUserName = currentUser.name;
        });
      }
    } catch (e) {
      print('Error fetching user: $e');
      setState(() {
        _currentUserName = 'Unknown User';
      });
    }
  }

  // Submit report method
  void _submitReport() {
    // Validate inputs
    if (_selectedIssueType == null) {
      _showErrorDialog('Please select an issue type');
      return;
    }

    // Convert selected issue type to enum
    final issueType = BreakdownIssueType.values.firstWhere(
      (type) =>
          type.value == _selectedIssueType?.toLowerCase().replaceAll(' ', '_'),
      orElse: () => BreakdownIssueType.other,
    );

    // Create delay object
    final delay = BreakdownDelay(hours: _delayHours, minutes: _delayMinutes);

    // Submit report using service
    breakdownService
        .createBreakdownReport(
          issueType: issueType,
          description: _descriptionController.text,
          delay: delay,
        )
        .then((_) {
          _showSuccessPopup();
        })
        .catchError((error) {
          _showErrorDialog('Failed to submit report: $error');
        });
  }

  // Show error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Error'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  // Success popup matching screenshot
  void _showSuccessPopup() {
    final String currentDateTime = DateFormat(
      'yyyy-MM-dd hh:mm a',
    ).format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Breakdown Issue',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Reported Successfully!',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                _buildInfoRow('Issue Type:', _selectedIssueType ?? ''),
                _buildInfoRow(
                  'Delay Time:',
                  '$_delayHours Hours $_delayMinutes Minutes',
                ),
                _buildInfoRow('Reported By:', _currentUserName),
                _buildInfoRow('Date:', currentDateTime),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          // Add navigation to view details if needed
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('View Details'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          // Reset form or prepare for new report
                          setState(() {
                            _selectedIssueType = null;
                            _delayHours = 0;
                            _delayMinutes = 0;
                            _descriptionController.clear();
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Report Another'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Build info row for popup
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text(value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Breakdown'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Issue Type Section
            featureItem(" Issue Type"),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _issueTypes.length,
              itemBuilder: (context, index) {
                final issueType = _issueTypes[index];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIssueType = issueType;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color:
                            _selectedIssueType == issueType
                                ? Colors.green
                                : Colors.grey,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _selectedIssueType == issueType,
                          onChanged: (bool? value) {
                            setState(() {
                              _selectedIssueType =
                                  value == true ? issueType : null;
                            });
                          },
                          activeColor: Colors.green,
                        ),
                        Text(
                          issueType,
                          style: TextStyle(
                            color:
                                _selectedIssueType == issueType
                                    ? Colors.green
                                    : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Description Section
            const SizedBox(height: 16),
            featureItem(" Description"),

            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Describe the breakdown...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),

            // Delay Time Section
            const SizedBox(height: 16),
            featureItem(" Delay Time"),
            const SizedBox(height: 10),
            Row(
              children: [
                // Hours Selector
                Expanded(
                  child: Column(
                    children: [
                      const Text('Hours'),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () {
                              setState(() {
                                if (_delayHours > 0) _delayHours--;
                              });
                            },
                          ),
                          Text(
                            _delayHours.toString().padLeft(2, '0'),
                            style: const TextStyle(fontSize: 16),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              setState(() {
                                _delayHours++;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Minutes Selector
                Expanded(
                  child: Column(
                    children: [
                      const Text('Minutes'),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () {
                              setState(() {
                                if (_delayMinutes > 0) _delayMinutes--;
                              });
                            },
                          ),
                          Text(
                            _delayMinutes.toString().padLeft(2, '0'),
                            style: const TextStyle(fontSize: 16),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              setState(() {
                                if (_delayMinutes < 59) _delayMinutes++;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Submit Button
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(150, 50),
                ),
                child: const Text('Submit'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget featureItem(String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [Container(width: 3, height: 30, color: Colors.green)],
          ),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
