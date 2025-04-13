import 'package:flutter/material.dart';

class ResidentNavbar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const ResidentNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF59A867),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(15),
          topRight: Radius.circular(15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent, 
          highlightColor: Colors.transparent, 
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: (index) {
              if (index == 0) {
                // If already on home, just update the index
                onTap(index);
                // If coming from a different tab, navigate to home
                if (currentIndex != 0) {
                  Navigator.pushNamed(context, '/resident_home');
                }
              } else if (index == 1) {
                // Navigate to reports without updating index
                Navigator.pushNamed(context, '/recent_report_and_request');
              } else if (index == 2) {
                // Navigate to notifications without updating index
                Navigator.pushNamed(context, '/resident_notification_screen');
              } else if (index == 3) {
                // Navigate to profile without updating index
                Navigator.pushNamed(context, '/resident_profile');
              }
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white, 
            showUnselectedLabels: true,
            showSelectedLabels: true,
            elevation: 0, 
            items: [
              _buildBottomNavigationBarItem(
                  Icons.home_outlined, Icons.home, 'Home', currentIndex == 0),
              _buildBottomNavigationBarItem(Icons.assignment_outlined,
                  Icons.assignment, 'Report', currentIndex == 1),
              _buildBottomNavigationBarItem(Icons.notifications_outlined,
                  Icons.notifications, 'Notification', currentIndex == 2),
              _buildBottomNavigationBarItem(Icons.person_outline, Icons.person,
                  'Profile', currentIndex == 3),
            ],
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildBottomNavigationBarItem(
      IconData icon, IconData activeIcon, String label, bool isSelected) {
    return BottomNavigationBarItem(
      icon: Transform.scale(
        scale: isSelected ? 1.3 : 1.0, 
        child: Icon(isSelected ? activeIcon : icon),
      ),
      label: label,
    );
  }
}