import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:waste_management/service/auth_service.dart';

class ResidentNavbar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  const ResidentNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<ResidentNavbar> createState() => _ResidentNavbarState();
}

class _ResidentNavbarState extends State<ResidentNavbar> {
  int _unreadNotificationCount = 0;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _fetchUnreadNotificationCount();
  }

  @override
  void didUpdateWidget(ResidentNavbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fetchUnreadNotificationCount();
  }

  Future<void> _fetchUnreadNotificationCount() async {
    try {
      final userId = _authService.getCurrentUserId();
      if (userId == null) {
        print('User ID is null, cannot fetch notifications');
        return;
      }

      // Get notifications from Firestore where 'isRead' is false
      QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance
              .collection('notifications')
              .where('userId', isEqualTo: userId)
              .where('isRead', isEqualTo: false)
              .get();

      if (mounted) {
        setState(() {
          _unreadNotificationCount = querySnapshot.docs.length;
        });
      }
      print('Unread notification count: $_unreadNotificationCount');
    } catch (e) {
      print('Error fetching notification count: $e');
    }
  }

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
            currentIndex: widget.currentIndex,
            onTap: (index) {
              // First update the index to show the selected tab
              widget.onTap(index);

              // Then navigate to appropriate screen if not already there
              if (index == 0 && widget.currentIndex != 0) {
                Navigator.pushReplacementNamed(context, '/resident_home');
              } else if (index == 1 && widget.currentIndex != 1) {
                Navigator.pushReplacementNamed(
                  context,
                  '/recent_report_and_request',
                );
              } else if (index == 2 && widget.currentIndex != 2) {
                Navigator.pushReplacementNamed(
                  context,
                  '/resident_notifications',
                );
                // Reset unread count when navigating to notifications
                _fetchUnreadNotificationCount();
              } else if (index == 3 && widget.currentIndex != 3) {
                Navigator.pushReplacementNamed(context, '/resident_profile');
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
                widget.currentIndex == 0,
                0,
              ),
              _buildBottomNavigationBarItem(
                Icons.assignment_outlined,
                Icons.assignment,
                'Report',
                widget.currentIndex == 1,
                0,
              ),
              _buildBottomNavigationBarItem(
                Icons.notifications_outlined,
                Icons.notifications,
                'Notification',
                widget.currentIndex == 2,
                _unreadNotificationCount,
              ),
              _buildBottomNavigationBarItem(
                Icons.person_outline,
                Icons.person,
                'Profile',
                widget.currentIndex == 3,
                0,
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
    int badgeCount,
  ) {
    return BottomNavigationBarItem(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Transform.scale(
            scale: isSelected ? 1.3 : 1.0,
            child: Icon(
              isSelected ? activeIcon : icon,
              weight: isSelected ? 700 : 400,
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              right: -6,
              top: -3,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      label: label,
    );
  }
}
