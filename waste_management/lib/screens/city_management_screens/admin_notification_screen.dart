import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:waste_management/models/notificationModel.dart' as custom;
import 'package:waste_management/screens/city_management_screens/admin_route_detail_screen.dart';
import 'package:waste_management/service/notification_service.dart';
import 'package:waste_management/service/route_service.dart';
import 'package:waste_management/service/cleanliness_issue_service.dart';
import 'package:waste_management/service/special_Garbage_Request_service.dart';
import 'package:waste_management/service/breakdown_service.dart';
import 'package:intl/intl.dart';

class AdminNotificationScreen extends StatefulWidget {
  const AdminNotificationScreen({super.key});

  @override
  State<AdminNotificationScreen> createState() =>
      _AdminNotificationScreenState();
}

class _AdminNotificationScreenState extends State<AdminNotificationScreen>
    with SingleTickerProviderStateMixin {
  final NotificationService _notificationService = NotificationService();
  final RouteService _routeService = RouteService();
  final CleanlinessIssueService _cleanlinessIssueService =
      CleanlinessIssueService();
  final SpecialGarbageRequestService _specialGarbageRequestService =
      SpecialGarbageRequestService();
  final BreakdownService _breakdownService = BreakdownService();

  late TabController _tabController;
  List<custom.NotificationModel> _notifications = [];
  bool _isLoading = true;
  final Color _primaryColor = const Color(0xFF59A867);

  // Filter options
  String _currentFilter = 'all';
  bool _showReadNotifications = true;

  // Selected notification for detail view
  custom.NotificationModel? _selectedNotification;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadNotifications();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      return;
    }

    setState(() {
      switch (_tabController.index) {
        case 0:
          _currentFilter = 'all';
          break;
        case 1:
          _currentFilter = 'route';
          break;
        case 2:
          _currentFilter = 'cleanliness';
          break;
        case 3:
          _currentFilter = 'breakdown';
          break;
      }
    });

    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);

    try {
      // For admin screen, we'll show notifications for all city management users
      // This would typically use a more refined query in a production app
      QuerySnapshot allNotificationsSnapshot;
      
      // Only apply type filter if we have specific types to filter by
      final notificationTypes = _getNotificationTypesByFilter(_currentFilter);
      
      if (_currentFilter == 'all' || notificationTypes.isEmpty) {
        // For 'all' category, don't use the whereIn filter at all
        allNotificationsSnapshot = await FirebaseFirestore.instance
            .collection('notifications')
            .orderBy('timestamp', descending: true)
            .get();
      } else {
        // For specific categories, use the whereIn filter with non-empty list
        allNotificationsSnapshot = await FirebaseFirestore.instance
            .collection('notifications')
            .where('type', whereIn: notificationTypes)
            .orderBy('timestamp', descending: true)
            .get();
      }

      setState(() {
        _notifications =
            allNotificationsSnapshot.docs
                .map(
                  (doc) => custom.NotificationModel.fromMap(
                    doc.data() as Map<String, dynamic>,
                  ),
                )
                .toList();

        if (!_showReadNotifications) {
          _notifications =
              _notifications
                  .where((notification) => !notification.isRead)
                  .toList();
        }

        _isLoading = false;
      });
    } catch (e) {
      print('Error loading notifications: $e');
      setState(() {
        _notifications = [];
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading notifications: ${e.toString()}')),
      );
    }
  }

  List<String> _getNotificationTypesByFilter(String filter) {
    switch (filter) {
      case 'route':
        return [
          'route_created',
          'route_assigned',
          'route_started',
          'route_paused',
          'route_resumed',
          'route_completed',
          'route_cancelled',
          'route_restarted',
          'long_pending_route',
        ];
      case 'cleanliness':
        return [
          'new_cleanliness_issue',
          'issue_assigned',
          'issue_in_progress',
          'issue_resolved',
          'issue_confirmed',
          'issue_not_confirmed',
          'long_pending_issue',
          'special_garbage_request',
          'special_garbage_assigned',
          'special_garbage_collected',
          'special_garbage_confirmed',
          'special_garbage_cancelled',
          'special_garbage_issue',
        ];
      case 'breakdown':
        return [
          'new_breakdown',
          'breakdown_status_update',
          'breakdown_status_change',
          'breakdown_comment',
          'stale_breakdown_report',
        ];
      case 'all':
      default:
        return [];
    }
  }

  void _markNotificationAsRead(String notificationId) async {
    try {
      await _notificationService.markNotificationAsRead(notificationId);
      _loadNotifications();
    } catch (e) {
      print('Error marking notification as read: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error marking notification as read: ${e.toString()}'),
        ),
      );
    }
  }

  void _markAllNotificationsAsRead() async {
    try {
      await _notificationService.markAllNotificationsAsRead();
      _loadNotifications();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read')),
      );
    } catch (e) {
      print('Error marking all notifications as read: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error marking all notifications as read: ${e.toString()}',
          ),
        ),
      );
    }
  }

  void _deleteNotification(String notificationId) async {
    try {
      await _notificationService.deleteNotification(notificationId);
      setState(() {
        _notifications.removeWhere(
          (notification) => notification.id == notificationId,
        );
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Notification deleted')));
    } catch (e) {
      print('Error deleting notification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting notification: ${e.toString()}')),
      );
    }
  }

  void _deleteAllNotifications() async {
    try {
      await _notificationService.clearAllNotifications();
      _loadNotifications();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications cleared')),
      );
    } catch (e) {
      print('Error clearing all notifications: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error clearing all notifications: ${e.toString()}'),
        ),
      );
    }
  }

  void _showNotificationDetail(custom.NotificationModel notification) async {
    setState(() {
      _selectedNotification = notification;
    });

    // Mark as read when viewed
    if (!notification.isRead) {
      _markNotificationAsRead(notification.id);
    }

    // Navigate to detail view based on type
    if (notification.referenceId != null) {
      await _navigateBasedOnNotificationType(notification);
    }
  }

  Future<void> _navigateBasedOnNotificationType(
    custom.NotificationModel notification,
  ) async {
    final type = notification.type;
    final referenceId = notification.referenceId;

    if (referenceId == null) return;

    try {
      if (type.startsWith('route_')) {
        // Use direct navigation with MaterialPageRoute for route details
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RouteDetailScreen(routeId: referenceId),
          ),
        );
      } else if (type.contains('cleanliness_issue') ||
          type.contains('issue_')) {
        // Check if the route exists in the navigation system
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pushNamed('/admin_cleanliness_issue_list');
        } else {
          // Fallback to safer navigation
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Opening cleanliness issue details')),
          );
        }
      } else if (type.contains('special_garbage')) {
        // Check if the route exists in the navigation system
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pushNamed('/admin_special_garbage_requests');
        } else {
          // Fallback to safer navigation
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Opening special garbage request details')),
          );
        }
      } else if (type.contains('breakdown')) {
        // Check if the route exists in the navigation system
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pushNamed('/admin_breakdown');
        } else {
          // Fallback to safer navigation
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Opening breakdown report details')),
          );
        }
      }
    } catch (e) {
      print('Error navigating to detail: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error navigating to detail: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: _primaryColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Routes'),
            Tab(text: 'Issues'),
            Tab(text: 'Breakdowns'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showReadNotifications ? Icons.visibility_off : Icons.visibility,
            ),
            onPressed: () {
              setState(() {
                _showReadNotifications = !_showReadNotifications;
              });
              _loadNotifications();
            },
            tooltip:
                _showReadNotifications
                    ? 'Hide read notifications'
                    : 'Show read notifications',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'mark_all_read') {
                _markAllNotificationsAsRead();
              } else if (value == 'delete_all') {
                _showDeleteAllConfirmation();
              }
            },
            itemBuilder:
                (BuildContext context) => [
                  const PopupMenuItem<String>(
                    value: 'mark_all_read',
                    child: Text('Mark all as read'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete_all',
                    child: Text('Delete all notifications'),
                  ),
                ],
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _notifications.isEmpty
              ? _buildEmptyState()
              : _buildNotificationsList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadNotifications,
        backgroundColor: _primaryColor,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No notifications found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getEmptyStateSubtitle(),
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadNotifications,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _getEmptyStateSubtitle() {
    switch (_currentFilter) {
      case 'route':
        return 'No route notifications at the moment.\nCheck back later for updates on route activities.';
      case 'cleanliness':
        return 'No cleanliness issue notifications at the moment.\nCheck back later for updates on reported issues.';
      case 'breakdown':
        return 'No breakdown notifications at the moment.\nCheck back later for updates on vehicle breakdowns.';
      case 'all':
      default:
        return 'Your notification inbox is empty.\nCheck back later for updates.';
    }
  }

  Widget _buildNotificationsList() {
    return RefreshIndicator(
      onRefresh: _loadNotifications,
      color: _primaryColor,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: _notifications.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return _buildNotificationItem(notification);
        },
      ),
    );
  }

  Widget _buildNotificationItem(custom.NotificationModel notification) {
    final notificationType = notification.type;
    IconData iconData;
    Color iconColor;
    Color backgroundColor;

    // Determine icon and colors based on notification type
    if (notificationType.contains('route_')) {
      iconData = Icons.directions;
      iconColor = const Color(0xFF59A867);
      backgroundColor = const Color(0xFFE8F5E9);
    } else if (notificationType.contains('issue_') ||
        notificationType.contains('cleanliness_')) {
      iconData = Icons.cleaning_services;
      iconColor = Colors.blue;
      backgroundColor = const Color(0xFFE3F2FD);
    } else if (notificationType.contains('special_garbage')) {
      iconData = Icons.delete;
      iconColor = Colors.purple;
      backgroundColor = const Color(0xFFF3E5F5);
    } else if (notificationType.contains('breakdown')) {
      iconData = Icons.car_repair;
      iconColor = Colors.orange;
      backgroundColor = const Color(0xFFFFF8E1);
    } else {
      iconData = Icons.notifications;
      iconColor = Colors.grey;
      backgroundColor = Colors.grey[200]!;
    }

    return Dismissible(
      key: Key(notification.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmation(notification);
      },
      onDismissed: (direction) {
        _deleteNotification(notification.id);
      },
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
          ),
          child: Icon(iconData, color: iconColor),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight:
                notification.isRead ? FontWeight.normal : FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.body,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(notification.timestamp),
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
        trailing:
            notification.isRead
                ? null
                : Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => _showNotificationDetail(notification),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return DateFormat('MMM d, y').format(timestamp);
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  Future<bool> _showDeleteConfirmation(
    custom.NotificationModel notification,
  ) async {
    return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Delete Notification'),
              content: const Text(
                'Are you sure you want to delete this notification?',
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _showDeleteAllConfirmation() async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete All Notifications'),
          content: const Text(
            'Are you sure you want to delete all notifications? This action cannot be undone.',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Delete All',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (delete == true) {
      _deleteAllNotifications();
    }
  }
}
