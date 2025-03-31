import 'package:flutter/material.dart';

class DriversNavbar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const DriversNavbar({
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
              // First update the current index
              onTap(index);

              // Then handle navigation if needed
              if (index == 3) {
                // Use Future.delayed to avoid state update conflicts
                Future.delayed(Duration.zero, () {
                  Navigator.pushNamed(context, '/driver_profile');
                });
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
                Icons.home_outlined,
                Icons.home,
                'Home',
                currentIndex == 0,
              ),
              _buildBottomNavigationBarItem(
                Icons.alt_route_outlined,
                Icons.alt_route,
                'Tracker',
                currentIndex == 1,
              ), // Changed icon for Tracker
              _buildBottomNavigationBarItem(
                Icons.announcement_outlined,
                Icons.announcement,
                'Issues',
                currentIndex == 2,
              ),
              _buildBottomNavigationBarItem(
                Icons.assignment_outlined,
                Icons.assignment,
                'Report',
                currentIndex == 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildBottomNavigationBarItem(
    IconData icon,
    IconData activeIcon,
    String label,
    bool isSelected,
  ) {
    return BottomNavigationBarItem(
      icon: Transform.scale(
        scale: isSelected ? 1.3 : 1.0,
        child: Icon(isSelected ? activeIcon : icon),
      ),
      label: label,
    );
  }
}
