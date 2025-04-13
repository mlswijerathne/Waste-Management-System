import 'package:flutter/material.dart';
import 'package:waste_management/widgets/admin_navbar.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _currentIndex = 0;

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _showWasteInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Waste Information'),
        content: const Text('Learn about different types of waste and proper disposal methods.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Prevent back navigation on home screen
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Interface'),
          backgroundColor: const Color(0xFF59A867),
          // Remove the back button
          automaticallyImplyLeading: false,
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: [
            // Home Page with Quick Actions
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Actions Title
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Quick Actions',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),

                  // Action Cards
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      children: [
                        _ActionCard(
                          icon: Icons.map,
                          title: 'Assign Route',
                          description: 'Assign routes to drivers',
                          onTap: () {
                            Navigator.pushNamed(context, '/admin_route_list');
                          },
                          color: const Color(0xFF59A867),
                        ),
                        _ActionCard(
                          icon: Icons.manage_accounts,
                          title: 'Special Gabage Request',
                          description: 'Manage special garbage requests',
                          onTap: () {
                            Navigator.pushNamed(context, '/admin_special_garbage_requests');
                          },
                          color: Colors.orange,
                        ),
                        _ActionCard(
                          icon: Icons.history,
                          title: 'Driver Brekdown Issues',
                          description: 'View driver breakdown issues', 
                          onTap: () {
                            Navigator.pushNamed(context, '/admin_breakdown');
                          },
                          color: Colors.blue,
                        ),
                        _ActionCard(
                          icon: Icons.info,
                          title: 'Resident Cleanliness Issues',
                          description: 'View cleanliness issues reported by residents',
                          onTap: () {
                            Navigator.pushNamed(context, '/admin_cleanliness_issue_list');
                          },
                          color: Colors.purple,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Center(child: Text('Tasks Page')),
            const Center(child: Text('Notification Page')),
            const Center(child: Text('Profile Page')),
          ],
        ),
        bottomNavigationBar: AdminNavbar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final Color color;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    required this.color,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: color),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}