import 'package:flutter/material.dart';

class AdminNavbar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const AdminNavbar({
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

              onTap(index);

              
              if (index == 0 && currentIndex != 0) {
                Navigator.pushReplacementNamed(context, '/admin_home');
              } else if (index == 1 && currentIndex != 1) {
                Navigator.pushReplacementNamed(
                  context,
                  '/admin_active_drivers_screen',
                );
              } else if (index == 2 && currentIndex != 2) {
                Navigator.pushReplacementNamed(
                  context,
                  '/admin_cleanliness_issue_list',
                );
              } else if (index == 3 && currentIndex != 3) {
                Navigator.pushReplacementNamed(context, '/admin_breakdown');
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
                Icons.fire_truck_outlined,
                Icons.fire_truck,
                'Truck',
                currentIndex == 1,
              ),
              _buildBottomNavigationBarItem(
                Icons.assessment_outlined,
                Icons.assessment,
                'Cleanliness',
                currentIndex == 2,
              ),
              _buildBottomNavigationBarItem(
                Icons.garage_outlined,
                Icons.garage,
                'Breakdown',
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
