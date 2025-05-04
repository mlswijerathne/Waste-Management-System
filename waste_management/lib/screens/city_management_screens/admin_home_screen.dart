import 'package:flutter/material.dart';
import 'package:waste_management/models/breakdownReportModel.dart';
import 'package:waste_management/models/routeModel.dart';
import 'package:waste_management/service/auth_service.dart';
import 'package:waste_management/service/breakdown_service.dart';
import 'package:waste_management/service/cleanliness_issue_service.dart';
import 'package:waste_management/service/route_service.dart';
import 'package:waste_management/service/special_Garbage_Request_service.dart';
import 'package:waste_management/widgets/admin_navbar.dart';
import 'package:waste_management/screens/city_management_screens/admin_all_residents_screen.dart';
import 'package:waste_management/screens/city_management_screens/admin_all_drivers_screen.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _currentIndex = 0;
  final AuthService _authService = AuthService();
  final RouteService _routeService = RouteService();
  final CleanlinessIssueService _cleanlinessService = CleanlinessIssueService();
  final BreakdownService _breakdownService = BreakdownService();
  final SpecialGarbageRequestService _specialRequestService =
      SpecialGarbageRequestService();

  // Statistics data
  int activeRoutes = 0;
  int pendingCleanlinessIssues = 0;
  int pendingBreakdowns = 0;
  int pendingSpecialRequests = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      // Get active routes using the proper method from RouteService
      try {
        final routes = await _routeService.getTodayScheduledRoutes();
        if (mounted) setState(() => activeRoutes = routes.length);
      } catch (e) {
        print('Error loading active routes: $e');
        if (mounted) setState(() => activeRoutes = 0);
      }

      // Get pending cleanliness issues count
      try {
        final cleanlinessIssues = await _cleanlinessService.getPendingIssues();
        if (mounted)
          setState(() => pendingCleanlinessIssues = cleanlinessIssues.length);
      } catch (e) {
        print('Error loading cleanliness issues: $e');
        if (mounted) setState(() => pendingCleanlinessIssues = 0);
      }

      // Get pending breakdowns using the proper method from BreakdownService
      try {
        // Use the stream with proper error handling and first value
        final breakdownsList = await _breakdownService
            .getBreakdownReportsByStatus(BreakdownStatus.pending)
            .first
            .catchError((error) {
              print('Error in breakdown stream: $error');
              return <BreakdownReport>[];
            });

        if (mounted) setState(() => pendingBreakdowns = breakdownsList.length);
      } catch (e) {
        print('Error loading breakdowns: $e');
        if (mounted) setState(() => pendingBreakdowns = 0);
      }

      // Get pending special garbage requests
      try {
        final specialRequests =
            await _specialRequestService.getPendingRequests();
        if (mounted)
          setState(() => pendingSpecialRequests = specialRequests.length);
      } catch (e) {
        print('Error loading special requests: $e');
        if (mounted) setState(() => pendingSpecialRequests = 0);
      }
    } catch (e) {
      print('Error loading statistics: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load statistics: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _logout() async {
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/sign_in_page',
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to logout: ${e.toString()}')),
        );
      }
    }
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _logout();
                },
                child: const Text('Logout'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF59A867);

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text(
            'Welcome Admin',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: primaryColor,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [

            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _showLogoutConfirmation,
              tooltip: 'Logout',
              color: Colors.white,
            ),
          ],
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: [
            // Home Page
            _buildHomeTab(),
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

  Widget _buildHomeTab() {
    const primaryColor = Color(0xFF59A867);

    return RefreshIndicator(
      onRefresh: _loadStatistics,
      color: primaryColor,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Welcome Header with Green Background
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            decoration: const BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [_buildWelcomeHeader()],
            ),
          ),

          // Statistics Cards
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Transform.translate(
              offset: const Offset(0, -16),
              child: _buildStatisticsCards(),
            ),
          ),

          // Quick Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildQuickActionsSection(),
          ),

          const SizedBox(height: 16),

          // Recent Activity
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: _buildRecentActivitySection(),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Row(
      children: [
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [const SizedBox(height: 2)],
        ),
      ],
    );
  }

  Widget _buildStatisticsCards() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child:
          isLoading
              ? const SizedBox(
                height: 160,
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF59A867)),
                ),
              )
              : Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildActiveRoutesStream(),
                        _buildStatCard(
                          title: 'Cleanliness Issues',
                          value: pendingCleanlinessIssues.toString(),
                          iconData: Icons.cleaning_services,
                          backgroundColor: const Color(0xFFE3F2FD),
                          iconColor: Colors.blue,
                          textColor: Colors.blue,
                          onTap:
                              () => Navigator.pushNamed(
                                context,
                                '/admin_cleanliness_issue_list',
                              ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _buildBreakdownIssuesStream(),
                        _buildStatCard(
                          title: 'Special Requests',
                          value: pendingSpecialRequests.toString(),
                          iconData: Icons.delete,
                          backgroundColor: const Color(0xFFF3E5F5),
                          iconColor: Colors.purple,
                          textColor: Colors.purple,
                          onTap:
                              () => Navigator.pushNamed(
                                context,
                                '/admin_special_garbage_requests',
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData iconData,
    required Color backgroundColor,
    required Color iconColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          margin: const EdgeInsets.all(4),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: backgroundColor, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(iconData, color: iconColor, size: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap to view',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveRoutesStream() {
    return StreamBuilder<List<RouteModel>>(
      stream: _routeService.getActiveRoutes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildStatCard(
            title: 'Active Routes',
            value: '...',
            iconData: Icons.directions,
            backgroundColor: const Color(0xFFE8F5E9),
            iconColor: const Color(0xFF59A867),
            textColor: const Color(0xFF59A867),
            onTap: () => Navigator.pushNamed(context, '/admin_route_list'),
          );
        }

        if (snapshot.hasError) {
          return _buildStatCard(
            title: 'Active Routes',
            value: 'Error',
            iconData: Icons.directions,
            backgroundColor: const Color(0xFFE8F5E9),
            iconColor: const Color(0xFF59A867),
            textColor: Colors.red,
            onTap: () => Navigator.pushNamed(context, '/admin_route_list'),
          );
        }

        final activeRoutes = snapshot.data?.length ?? 0;

        return _buildStatCard(
          title: 'Active Routes',
          value: activeRoutes.toString(),
          iconData: Icons.directions,
          backgroundColor: const Color(0xFFE8F5E9),
          iconColor: const Color(0xFF59A867),
          textColor: const Color(0xFF59A867),
          onTap: () => Navigator.pushNamed(context, '/admin_route_list'),
        );
      },
    );
  }

  Widget _buildBreakdownIssuesStream() {
    return StreamBuilder<List<BreakdownReport>>(
      stream: _breakdownService.getBreakdownReportsByStatus(
        BreakdownStatus.pending,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildStatCard(
            title: 'Breakdowns',
            value: '...',
            iconData: Icons.car_repair,
            backgroundColor: const Color(0xFFFFF8E1),
            iconColor: Colors.orange,
            textColor: Colors.orange,
            onTap: () => Navigator.pushNamed(context, '/admin_breakdown'),
          );
        }

        if (snapshot.hasError) {
          return _buildStatCard(
            title: 'Breakdowns',
            value: 'Error',
            iconData: Icons.car_repair,
            backgroundColor: const Color(0xFFFFF8E1),
            iconColor: Colors.orange,
            textColor: Colors.red,
            onTap: () => Navigator.pushNamed(context, '/admin_breakdown'),
          );
        }

        final breakdownIssues = snapshot.data?.length ?? 0;

        return _buildStatCard(
          title: 'Breakdowns',
          value: breakdownIssues.toString(),
          iconData: Icons.car_repair,
          backgroundColor: const Color(0xFFFFF8E1),
          iconColor: Colors.orange,
          textColor: Colors.orange,
          onTap: () => Navigator.pushNamed(context, '/admin_breakdown'),
        );
      },
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(
                Icons.arrow_forward,
                color: Color(0xFF59A867),
                size: 16,
              ),
              label: const Text(
                'View All',
                style: TextStyle(color: Color(0xFF59A867), fontSize: 14),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(50, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.0,
          children: [
            _buildQuickActionButton(
              title: 'Create Route',
              icon: Icons.add_road,
              backgroundColor: const Color(0xFFE8F5E9),
              iconColor: const Color(0xFF59A867),
              onTap: () => Navigator.pushNamed(context, '/admin_create_route'),
            ),
            _buildQuickActionButton(
              title: 'View Reports',
              icon: Icons.assignment,
              backgroundColor: const Color(0xFFFFF8E1),
              iconColor: Colors.orange,
              onTap: () => Navigator.pushNamed(context, '/admin_reports'),
            ),
            _buildQuickActionButton(
              title: 'All Residents',
              icon: Icons.people,
              backgroundColor: const Color(0xFFF3E5F5),
              iconColor: Colors.purple,
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminAllResidentsScreen(),
                    ),
                  ),
            ),
            _buildQuickActionButton(
              title: 'All Drivers',
              icon: Icons.people,
              backgroundColor: const Color(0xFFE3F2FD),
              iconColor: Colors.blue,
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminAllDriversScreen(),
                    ),
                  ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required String title,
    required IconData icon,
    required Color backgroundColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: backgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: iconColor),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(
                Icons.arrow_forward,
                color: Color(0xFF59A867),
                size: 16,
              ),
              label: const Text(
                'View All',
                style: TextStyle(color: Color(0xFF59A867), fontSize: 14),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(50, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                spreadRadius: 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildActivityItem(
                icon: Icons.directions,
                title: 'New route assigned',
                subtitle: 'Route #123 to Driver John',
                time: '10 mins ago',
                iconColor: const Color(0xFF59A867),
                iconBackgroundColor: const Color(0xFFE8F5E9),
              ),
              const Divider(height: 1, indent: 54),
              _buildActivityItem(
                icon: Icons.cleaning_services,
                title: 'Cleanliness issue reported',
                subtitle: 'By Resident Alice',
                time: '25 mins ago',
                iconColor: Colors.blue,
                iconBackgroundColor: const Color(0xFFE3F2FD),
              ),
              const Divider(height: 1, indent: 54),
              _buildActivityItem(
                icon: Icons.car_repair,
                title: 'Breakdown reported',
                subtitle: 'Truck #456 - Engine issue',
                time: '1 hour ago',
                iconColor: Colors.orange,
                iconBackgroundColor: const Color(0xFFFFF8E1),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String time,
    required Color iconColor,
    required Color iconBackgroundColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBackgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              time,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
