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
              
              onTap(index);
              
              
              switch (index) {
                case 0:
                  Navigator.pushReplacementNamed(context, '/driver_home');
                  break;
                case 1:
                  Navigator.pushReplacementNamed(context, '/driver_route_list');
                  break;
                case 2:
                  Navigator.pushReplacementNamed(context, '/driver_special_garbage_screen');
                  break;
                case 3:
                  Navigator.pushReplacementNamed(context, '/driver_assignment_screen');
                  break;
              }
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white.withOpacity(0.7),
            showUnselectedLabels: true,
            showSelectedLabels: true,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
            elevation: 0,
            items: [
              _buildBottomNavigationBarItem(
                  Icons.home_outlined, Icons.home, 'Home', currentIndex == 0),
              _buildBottomNavigationBarItem(
                  Icons.directions_outlined, Icons.directions, 'Routes', currentIndex == 1),
              _buildBottomNavigationBarItem(
                  Icons.delete_outline, Icons.delete, 'Requests', currentIndex == 2),
              _buildBottomNavigationBarItem(
                  Icons.assignment_outlined, Icons.assignment, 'Tasks', currentIndex == 3),
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
