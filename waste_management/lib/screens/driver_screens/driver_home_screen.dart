import 'package:flutter/material.dart';
import 'package:waste_management/widgets/driver_navbar.dart';

class DriverHome extends StatefulWidget {
  const DriverHome({super.key});

  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome> {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Interface'),
        backgroundColor: const Color(0xFF59A867),
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
                        title: 'Select Route ',
                        description: 'Select your route for the day',
                        onTap: () {
                          Navigator.pushNamed(context, '');
                        },
                        color: const Color(0xFF59A867),
                      ),
                      _ActionCard(
                        icon: Icons.info,
                        title: 'Cleanliness Issues',
                        description: 'Cleanliness issues in your area',
                        onTap: () {
                          Navigator.pushNamed(context, '');
                        },
                        color: Colors.orange,
                      ),
                      _ActionCard(
                        icon: Icons.folder_special,
                        title: 'Special Requests',
                        description: 'View special requests from citizens',
                        onTap: () {
                          Navigator.pushNamed(context, '');
                        },
                        color: Colors.blue,
                      ),
                      _ActionCard(
                        icon: Icons.build,
                        title: 'Report Breakdown',
                        description: 'Report vehicle breakdowns',
                        onTap: () {
                          Navigator.pushNamed(context, '');
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
      bottomNavigationBar: DriversNavbar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
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