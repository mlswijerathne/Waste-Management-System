import 'package:flutter/material.dart';

class RecentReportsScreen extends StatefulWidget {
  const RecentReportsScreen({Key? key}) : super(key: key);

  @override
  _RecentReportsScreenState createState() => _RecentReportsScreenState();
}

class _RecentReportsScreenState extends State<RecentReportsScreen> {
  // Tabs for filtering reports
  final List<String> _tabs = ['In Progress', 'Pending', 'Resolved'];
  int _currentTabIndex = 0;

  // Sample data to represent reports
  final List<Map<String, dynamic>> _inProgressReports = [
    {
      'title': 'Overflowing Garbage Bin',
      'subtitle': 'A cleaning team has been assigned to this location.',
      'date': 'Feb 9, 07:20 PM',
      'status': 'In Progress'
    },
    {
      'title': 'Overflowing Garbage Bin',
      'subtitle': 'A cleaning team has been assigned to this location.',
      'date': 'Feb 10, 05:20 PM',
      'status': 'In Progress'
    },
    {
      'title': 'Damaged Trash Can',
      'subtitle': 'A cleaning team has been assigned to this location.',
      'date': 'Feb 10, 03:20 AM',
      'status': 'In Progress'
    },
  ];

  final List<Map<String, dynamic>> _pendingReports = [
    {
      'title': 'Missed Pickup',
      'subtitle': 'The team is reviewing your report',
      'date': 'Feb 5, 02:10 PM',
      'status': 'Pending'
    },
    {
      'title': 'Damaged Trash Can',
      'subtitle': 'The team is reviewing your report',
      'date': 'Feb 9, 12:10 PM',
      'status': 'Pending'
    },
  ];

  final List<Map<String, dynamic>> _resolvedReports = [
    {
      'title': 'Damaged Trash Can',
      'subtitle': 'Your trash can replacement request has been completed.',
      'date': 'Today, 02:10 PM',
      'status': 'Resolved'
    },
    {
      'title': 'Damaged Trash Can',
      'subtitle': 'Your trash can replacement request has been completed.',
      'date': 'Today, 02:10 PM',
      'status': 'Resolved'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Recent Reports & Requests', 
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Custom Tab Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _tabs.asMap().entries.map((entry) {
                int index = entry.key;
                String tab = entry.value;
                return Container(
                  width: 100, // Fixed width
                  height: 20, // Fixed height
                  decoration: BoxDecoration(
                    color: _currentTabIndex == index 
                      ? const Color(0xFF59A867) 
                      : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.center,
                    ),
                    onPressed: () {
                      setState(() {
                        _currentTabIndex = index;
                      });
                    },
                    child: Text(
                      tab,
                      style: TextStyle(
                        color: _currentTabIndex == index 
                          ? Colors.white  // White text when selected
                          : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Reports List
          Expanded(
            child: ListView.builder(
              itemCount: _getCurrentReportsList().length,
              itemBuilder: (context, index) {
                final report = _getCurrentReportsList()[index];
                return _buildReportItem(report);
              },
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to get current list based on selected tab
  List<Map<String, dynamic>> _getCurrentReportsList() {
    switch (_currentTabIndex) {
      case 0:
        return _inProgressReports;
      case 1:
        return _pendingReports;
      case 2:
        return _resolvedReports;
      default:
        return [];
    }
  }

  // Report Item Widget
  Widget _buildReportItem(Map<String, dynamic> report) {
    return ListTile(
      title: Text(
        report['title'],
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(report['subtitle']),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.report, color: Color(0xFF59A867), size: 16),
              const SizedBox(width: 4),
              Text(
                'Reported: ${report['date']}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF59A867)),
      onTap: () {
        // Handle report item tap
      },
    );
  }
}