import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:waste_management/models/notificationModel.dart' as custom;

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // Channel IDs for different notification types (kept for backwards compatibility)
  static const String breakdownChannelKey = 'breakdown_notifications';
  static const String routeChannelKey = 'route_notifications';
  static const String specialGarbageChannelKey =
      'special_garbage_notifications';
  static const String cleanlinessIssueChannelKey =
      'cleanliness_issue_notifications';
  static const String generalChannelKey = 'general_notifications';
  static const String scheduledChannelKey = 'scheduled_notifications';
  static const String reminderChannelKey = 'reminder_notifications';

  // Initialize Firebase Cloud Messaging
  Future<void> initializeNotificationChannels() async {
    // Request permission for iOS
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print(
      'User notification permission status: ${settings.authorizationStatus}',
    );

    // Configure FCM to handle messages while the app is in the foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
      }
    });

    // Get the token for this device
    String? token = await _firebaseMessaging.getToken();
    print('Firebase Messaging Token: $token');

    // Save the token to the user's document in Firestore
    await _saveTokenToFirestore(token!);
    
    // Listen for token refreshes
    _firebaseMessaging.onTokenRefresh.listen(_saveTokenToFirestore);

    // Note: Background message handler is now registered in main.dart

    // Start automatic notification checking
    _initializeAutomaticNotifications();
  }

  // Initialize automatic notification systems
  void _initializeAutomaticNotifications() {
    // Start the notification schedulers
    _scheduleRouteNotifications();
    _scheduleReminderNotifications();
    _scheduleWasteCollectionReminders();
  }

  // Save FCM token to Firestore
  Future<void> _saveTokenToFirestore(String token) async {
    final User? user = _auth.currentUser;
    if (user != null) {
      try {
        // First check if the user document exists
        final docSnapshot =
            await _firestore.collection('users').doc(user.uid).get();

        if (docSnapshot.exists) {
          // If document exists, update it with the new token
          await _firestore.collection('users').doc(user.uid).update({
            'fcmTokens': FieldValue.arrayUnion([token]),
          });
        } else {
          // If document doesn't exist, create it with the token
          await _firestore.collection('users').doc(user.uid).set({
            'fcmTokens': [token],
            'uid': user.uid,
          }, SetOptions(merge: true));
        }
      } catch (e) {
        print('Error saving FCM token to Firestore: $e');
      }
    }
  }

  // Request permission for notifications
  Future<bool> requestNotificationPermissions() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  // Save notification to Firestore for history
  Future<void> saveNotificationToFirestore({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? referenceId,
  }) async {
    try {
      final notification = custom.NotificationModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        title: title,
        body: body,
        type: type,
        referenceId: referenceId,
        timestamp: DateTime.now(),
        isRead: false,
      );

      await _firestore
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toMap());
    } catch (e) {
      print('Error saving notification to Firestore: $e');
    }
  }

  // Send notification to a specific user
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    required String channelKey, // kept for compatibility
    required String type,
    String? referenceId,
  }) async {
    // Save to Firestore for history
    await saveNotificationToFirestore(
      userId: userId,
      title: title,
      body: body,
      type: type,
      referenceId: referenceId,
    );

    // Get user's FCM tokens
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        final fcmTokens = userData?['fcmTokens'] as List<dynamic>?;

        if (fcmTokens != null && fcmTokens.isNotEmpty) {
          // Send FCM message via Cloud Functions or your backend
          // For now, we'll create a Cloud Firestore document that can trigger a Cloud Function
          await _firestore.collection('fcmMessages').add({
            'tokens': fcmTokens,
            'title': title,
            'body': body,
            'type': type,
            'referenceId': referenceId,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print('Error sending FCM notification: $e');
    }

    // For current user, we'll just rely on the onMessage listener
  }

  // Send notification to all users with a specific role
  Future<void> sendNotificationToRole({
    required String role,
    required String title,
    required String body,
    required String channelKey, // kept for compatibility
    required String type,
    String? referenceId,
  }) async {
    try {
      // Get all users with the specified role
      final QuerySnapshot usersSnapshot =
          await _firestore
              .collection('users')
              .where('role', isEqualTo: role)
              .get();

      // Send notification to each user
      for (final userDoc in usersSnapshot.docs) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final userId = userData['uid'];

        await saveNotificationToFirestore(
          userId: userId,
          title: title,
          body: body,
          type: type,
          referenceId: referenceId,
        );

        // Get the user's FCM tokens
        final fcmTokens = userData['fcmTokens'] as List<dynamic>?;

        if (fcmTokens != null && fcmTokens.isNotEmpty) {
          // Send FCM message via Cloud Functions or your backend
          await _firestore.collection('fcmMessages').add({
            'tokens': fcmTokens,
            'title': title,
            'body': body,
            'type': type,
            'referenceId': referenceId,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print('Error sending notification to role: $e');
    }
  }

  // Send breakdown related notifications
  Future<void> sendBreakdownNotification({
    required String title,
    required String body,
    required String type,
    required List<String> roles,
    String? breakdownId,
  }) async {
    for (final role in roles) {
      await sendNotificationToRole(
        role: role,
        title: title,
        body: body,
        channelKey: breakdownChannelKey,
        type: type,
        referenceId: breakdownId,
      );
    }
  }

  // Send route related notifications
  Future<void> sendRouteNotification({
    required String title,
    required String body,
    required String type,
    required List<String> roles,
    String? routeId,
  }) async {
    for (final role in roles) {
      await sendNotificationToRole(
        role: role,
        title: title,
        body: body,
        channelKey: routeChannelKey,
        type: type,
        referenceId: routeId,
      );
    }
  }

  // Send special garbage request notifications
  Future<void> sendSpecialGarbageNotification({
    required String title,
    required String body,
    required String type,
    required List<String> roles,
    String? requestId,
  }) async {
    for (final role in roles) {
      await sendNotificationToRole(
        role: role,
        title: title,
        body: body,
        channelKey: specialGarbageChannelKey,
        type: type,
        referenceId: requestId,
      );
    }
  }

  // Send cleanliness issue notifications
  Future<void> sendCleanlinessIssueNotification({
    required String title,
    required String body,
    required String type,
    required List<String> roles,
    String? issueId,
  }) async {
    for (final role in roles) {
      await sendNotificationToRole(
        role: role,
        title: title,
        body: body,
        channelKey: cleanlinessIssueChannelKey,
        type: type,
        referenceId: issueId,
      );
    }
  }

  // Get user notifications from Firestore
  Stream<List<custom.NotificationModel>> getUserNotifications() {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: currentUser.uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return custom.NotificationModel.fromMap(doc.data());
          }).toList();
        });
  }

  // Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'isRead': true,
    });
  }

  // Mark all notifications as read for current user
  Future<void> markAllNotificationsAsRead() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final QuerySnapshot notificationsSnapshot =
        await _firestore
            .collection('notifications')
            .where('userId', isEqualTo: currentUser.uid)
            .where('isRead', isEqualTo: false)
            .get();

    final batch = _firestore.batch();
    for (final doc in notificationsSnapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  // Mark all notifications as read for a specific user
  Future<void> markAllUserNotificationsAsRead(String userId) async {
    final QuerySnapshot notificationsSnapshot =
        await _firestore
            .collection('notifications')
            .where('userId', isEqualTo: userId)
            .where('isRead', isEqualTo: false)
            .get();

    final batch = _firestore.batch();
    for (final doc in notificationsSnapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  // Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).delete();
  }

  // Clear all notifications for current user
  Future<void> clearAllNotifications() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final QuerySnapshot notificationsSnapshot =
        await _firestore
            .collection('notifications')
            .where('userId', isEqualTo: currentUser.uid)
            .get();

    final batch = _firestore.batch();
    for (final doc in notificationsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  // Clear all notifications for a specific user
  Future<void> clearAllUserNotifications(String userId) async {
    final QuerySnapshot notificationsSnapshot =
        await _firestore
            .collection('notifications')
            .where('userId', isEqualTo: userId)
            .get();

    final batch = _firestore.batch();
    for (final doc in notificationsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  // Set up notification handlers
  void setupNotificationHandlers({
    required Function(RemoteMessage) onMessageHandler,
  }) {
    // Set up foreground message handler
    FirebaseMessaging.onMessage.listen(onMessageHandler);
  }

  //======== AUTOMATIC NOTIFICATION SYSTEM ========//

  // Schedule route notifications - checks for upcoming routes and sends reminders
  Future<void> _scheduleRouteNotifications() async {
    try {
      // Create a periodic check for upcoming routes (runs every hour)
      Stream.periodic(Duration(hours: 1)).listen((_) async {
        await _checkUpcomingRoutes();
      });

      // Run immediately once
      await _checkUpcomingRoutes();
    } catch (e) {
      print('Error scheduling route notifications: $e');
    }
  }

  // Check for upcoming routes and send notifications
  Future<void> _checkUpcomingRoutes() async {
    try {
      final now = DateTime.now();
      final tomorrow = now.add(Duration(days: 1));
      final nextHour = now.add(Duration(hours: 1));

      // Get routes scheduled to start within the next hour
      final imminent =
          await _firestore
              .collection('waste_routes')
              .where('nextScheduledStart', isGreaterThan: now)
              .where('nextScheduledStart', isLessThan: nextHour)
              .where('isActive', isEqualTo: false)
              .where('isCancelled', isEqualTo: false)
              .get();

      // Get routes scheduled for tomorrow
      final upcoming =
          await _firestore
              .collection('waste_routes')
              .where(
                'nextScheduledStart',
                isGreaterThan: DateTime(
                  tomorrow.year,
                  tomorrow.month,
                  tomorrow.day,
                ),
              )
              .where(
                'nextScheduledStart',
                isLessThan: DateTime(
                  tomorrow.year,
                  tomorrow.month,
                  tomorrow.day,
                  23,
                  59,
                ),
              )
              .where('isActive', isEqualTo: false)
              .where('isCancelled', isEqualTo: false)
              .get();

      // Process imminent routes
      for (final doc in imminent.docs) {
        final data = doc.data();
        final routeId = doc.id;
        final routeName = data['name'] ?? 'Unknown Route';
        final driverId = data['assignedDriverId'];

        if (driverId != null) {
          // Send reminder notification to the assigned driver
          await sendNotificationToUser(
            userId: driverId,
            title: 'Route Starting Soon',
            body:
                'Your route "$routeName" is scheduled to start within the next hour.',
            channelKey: scheduledChannelKey,
            type: 'route_reminder_imminent',
            referenceId: routeId,
          );
        }
      }

      // Process tomorrow's routes
      for (final doc in upcoming.docs) {
        final data = doc.data();
        final routeId = doc.id;
        final routeName = data['name'] ?? 'Unknown Route';
        final driverId = data['assignedDriverId'];

        if (driverId != null) {
          // Send reminder notification to the assigned driver
          await sendNotificationToUser(
            userId: driverId,
            title: 'Upcoming Route Tomorrow',
            body:
                'Reminder: You have a waste collection route "$routeName" scheduled for tomorrow.',
            channelKey: scheduledChannelKey,
            type: 'route_reminder_tomorrow',
            referenceId: routeId,
          );
        }

        // Also notify residents in the area if route has waste category
        if (data['wasteCategory'] != null) {
          await _notifyResidentsAboutCollection(
            routeName,
            data['wasteCategory'],
            data['startLat'],
            data['startLng'],
            data['endLat'],
            data['endLng'],
            routeId,
          );
        }
      }
    } catch (e) {
      print('Error checking upcoming routes: $e');
    }
  }

  // Notify residents near a route about waste collection
  Future<void> _notifyResidentsAboutCollection(
    String routeName,
    String wasteCategory,
    double startLat,
    double startLng,
    double endLat,
    double endLng,
    String routeId,
  ) async {
    try {
      // Calculate a bounding box around the route
      final double latMin =
          [startLat, endLat].reduce((a, b) => a < b ? a : b) - 0.02;
      final double latMax =
          [startLat, endLat].reduce((a, b) => a > b ? a : b) + 0.02;
      final double lngMin =
          [startLng, endLng].reduce((a, b) => a < b ? a : b) - 0.02;
      final double lngMax =
          [startLng, endLng].reduce((a, b) => a > b ? a : b) + 0.02;

      // Find residents within this bounding box
      final residentsSnapshot =
          await _firestore
              .collection('users')
              .where('role', isEqualTo: 'resident')
              .get();

      for (final doc in residentsSnapshot.docs) {
        final data = doc.data();
        final latitude = data['latitude'];
        final longitude = data['longitude'];

        // Check if resident location is within the bounding box
        if (latitude != null && longitude != null) {
          if (latitude >= latMin &&
              latitude <= latMax &&
              longitude >= lngMin &&
              longitude <= lngMax) {
            // Send notification to this resident
            await sendNotificationToUser(
              userId: doc.id,
              title: 'Waste Collection Tomorrow',
              body:
                  'A $wasteCategory waste collection is scheduled in your area tomorrow. Please prepare your waste for collection.',
              channelKey: scheduledChannelKey,
              type: 'upcoming_collection_reminder',
              referenceId: routeId,
            );
          }
        }
      }
    } catch (e) {
      print('Error notifying residents about collection: $e');
    }
  }

  // Schedule reminders for pending user actions (feedback, pending issues)
  Future<void> _scheduleReminderNotifications() async {
    try {
      // Create a periodic check for pending user actions (runs every 6 hours)
      Stream.periodic(Duration(hours: 6)).listen((_) async {
        await _checkPendingResidentFeedbacks();
        await _checkLongPendingIssues();
        await _checkStaleBreakdownReports();
      });

      // Run immediately once
      await _checkPendingResidentFeedbacks();
      await _checkLongPendingIssues();
      await _checkStaleBreakdownReports();
    } catch (e) {
      print('Error scheduling reminder notifications: $e');
    }
  }

  // Check for pending resident feedbacks
  Future<void> _checkPendingResidentFeedbacks() async {
    try {
      final now = DateTime.now();

      // Check for completed special garbage collections awaiting resident confirmation
      final pendingGarbageConfirmations =
          await _firestore
              .collection('specialGarbageRequests')
              .where('status', isEqualTo: 'collected')
              .where('residentConfirmed', isEqualTo: null)
              .get();

      // Check for resolved cleanliness issues awaiting resident confirmation
      final pendingIssueConfirmations =
          await _firestore
              .collection('cleanlinessIssues')
              .where('status', isEqualTo: 'resolved')
              .where('residentConfirmed', isEqualTo: null)
              .get();

      // Process pending garbage confirmations
      for (final doc in pendingGarbageConfirmations.docs) {
        final data = doc.data();
        final requestId = doc.id;
        final residentId = data['residentId'];
        final collectedTime = data['collectedTime'];

        // Only remind if collected more than 24 hours ago
        if (collectedTime != null) {
          DateTime collectedDateTime;
          if (collectedTime is Timestamp) {
            collectedDateTime = collectedTime.toDate();
          } else if (collectedTime is String) {
            collectedDateTime = DateTime.parse(collectedTime);
          } else {
            continue;
          }

          if (now.difference(collectedDateTime).inHours >= 24) {
            await sendNotificationToUser(
              userId: residentId,
              title: 'Feedback Reminder',
              body:
                  'Please confirm if your special garbage collection was completed properly.',
              channelKey: reminderChannelKey,
              type: 'feedback_reminder_special_garbage',
              referenceId: requestId,
            );
          }
        }
      }

      // Process pending issue confirmations
      for (final doc in pendingIssueConfirmations.docs) {
        final data = doc.data();
        final issueId = doc.id;
        final residentId = data['residentId'];
        final resolvedTime = data['resolvedTime'];

        // Only remind if resolved more than 24 hours ago
        if (resolvedTime != null) {
          DateTime resolvedDateTime;
          if (resolvedTime is Timestamp) {
            resolvedDateTime = resolvedTime.toDate();
          } else if (resolvedTime is String) {
            resolvedDateTime = DateTime.parse(resolvedTime);
          } else {
            continue;
          }

          if (now.difference(resolvedDateTime).inHours >= 24) {
            await sendNotificationToUser(
              userId: residentId,
              title: 'Feedback Reminder',
              body:
                  'Please confirm if your reported cleanliness issue was resolved properly.',
              channelKey: reminderChannelKey,
              type: 'feedback_reminder_cleanliness_issue',
              referenceId: issueId,
            );
          }
        }
      }
    } catch (e) {
      print('Error checking pending resident feedbacks: $e');
    }
  }

  // Check for long pending issues that haven't been addressed
  Future<void> _checkLongPendingIssues() async {
    try {
      final now = DateTime.now();
      final threeDaysAgo = now.subtract(Duration(days: 3));

      // Check for cleanliness issues that have been pending for too long
      final pendingIssues =
          await _firestore
              .collection('cleanlinessIssues')
              .where('status', isEqualTo: 'pending')
              .get();

      // Check for special garbage requests that have been pending for too long
      final pendingRequests =
          await _firestore
              .collection('specialGarbageRequests')
              .where('status', isEqualTo: 'pending')
              .get();

      // Process pending issues
      for (final doc in pendingIssues.docs) {
        final data = doc.data();
        final issueId = doc.id;
        final reportedTime = data['reportedTime'];

        if (reportedTime != null) {
          DateTime reportedDateTime;
          if (reportedTime is Timestamp) {
            reportedDateTime = reportedTime.toDate();
          } else if (reportedTime is String) {
            reportedDateTime = DateTime.parse(reportedTime);
          } else {
            continue;
          }

          if (reportedDateTime.isBefore(threeDaysAgo)) {
            // Notify city management about long pending issues
            await sendCleanlinessIssueNotification(
              title: 'Long Pending Issue',
              body:
                  'A cleanliness issue has been pending for more than 3 days. Please review and assign.',
              type: 'long_pending_issue',
              roles: ['cityManagement'],
              issueId: issueId,
            );
          }
        }
      }

      // Process pending special garbage requests
      for (final doc in pendingRequests.docs) {
        final data = doc.data();
        final requestId = doc.id;
        final requestedTime = data['requestedTime'];

        if (requestedTime != null) {
          DateTime requestedDateTime;
          if (requestedTime is Timestamp) {
            requestedDateTime = requestedTime.toDate();
          } else if (requestedTime is String) {
            requestedDateTime = DateTime.parse(requestedTime);
          } else {
            continue;
          }

          if (requestedDateTime.isBefore(threeDaysAgo)) {
            // Notify city management about long pending requests
            await sendSpecialGarbageNotification(
              title: 'Long Pending Special Collection Request',
              body:
                  'A special garbage collection request has been pending for more than 3 days. Please review and assign.',
              type: 'long_pending_request',
              roles: ['cityManagement'],
              requestId: requestId,
            );
          }
        }
      }
    } catch (e) {
      print('Error checking long pending issues: $e');
    }
  }

  // Check for stale breakdown reports
  Future<void> _checkStaleBreakdownReports() async {
    try {
      final now = DateTime.now();
      final twoDaysAgo = now.subtract(Duration(days: 2));

      // Get breakdown reports that haven't been updated in a while
      final staleReports =
          await _firestore
              .collection('breakdown_reports')
              .where('status', whereIn: ['reported', 'inProgress'])
              .get();

      for (final doc in staleReports.docs) {
        final data = doc.data();
        final reportId = doc.id;
        final createdAt = data['createdAt'];

        if (createdAt != null) {
          DateTime createdAtDateTime;
          if (createdAt is Timestamp) {
            createdAtDateTime = createdAt.toDate();
          } else {
            continue;
          }

          if (createdAtDateTime.isBefore(twoDaysAgo)) {
            // Notify about stale breakdown reports
            await sendBreakdownNotification(
              title: 'Stale Breakdown Report',
              body:
                  'A breakdown report has not been updated for more than 2 days. Please check and update the status.',
              type: 'stale_breakdown_report',
              roles: ['cityManagement'],
              breakdownId: reportId,
            );
          }
        }
      }
    } catch (e) {
      print('Error checking stale breakdown reports: $e');
    }
  }

  // Schedule waste collection day reminders for residents
  Future<void> _scheduleWasteCollectionReminders() async {
    try {
      // Create a periodic check for waste collection days (runs once a day at 7 PM)
      Stream.periodic(Duration(days: 1)).listen((_) async {
        final now = DateTime.now();
        // Only run at around 7 PM
        if (now.hour == 19) {
          await _sendWasteCollectionReminders();
        }
      });

      // For demo purposes, also run it once immediately
      await _sendWasteCollectionReminders();
    } catch (e) {
      print('Error scheduling waste collection reminders: $e');
    }
  }

  // Send waste collection day reminders to residents
  Future<void> _sendWasteCollectionReminders() async {
    try {
      final now = DateTime.now();
      final tomorrow = now.add(Duration(days: 1));

      // Get all residents
      final residents =
          await _firestore
              .collection('users')
              .where('role', isEqualTo: 'resident')
              .get();

      // Get routes scheduled for tomorrow
      final routes =
          await _firestore
              .collection('waste_routes')
              .where(
                'nextScheduledStart',
                isGreaterThan: DateTime(
                  tomorrow.year,
                  tomorrow.month,
                  tomorrow.day,
                ),
              )
              .where(
                'nextScheduledStart',
                isLessThan: DateTime(
                  tomorrow.year,
                  tomorrow.month,
                  tomorrow.day,
                  23,
                  59,
                ),
              )
              .where('isActive', isEqualTo: false)
              .where('isCancelled', isEqualTo: false)
              .get();

      // Group routes by waste category
      final Map<String, List<Map<String, dynamic>>> routesByCategory = {};

      for (final doc in routes.docs) {
        final data = doc.data();
        final wasteCategory = data['wasteCategory'] as String? ?? 'mixed';

        if (!routesByCategory.containsKey(wasteCategory)) {
          routesByCategory[wasteCategory] = [];
        }

        routesByCategory[wasteCategory]!.add({
          'id': doc.id,
          'startLat': data['startLat'],
          'startLng': data['startLng'],
          'endLat': data['endLat'],
          'endLng': data['endLng'],
          'name': data['name'],
        });
      }

      // Send reminders to residents based on their location and the scheduled routes
      for (final resident in residents.docs) {
        final residentData = resident.data();
        final latitude = residentData['latitude'];
        final longitude = residentData['longitude'];

        if (latitude == null || longitude == null) continue;

        // Check if resident is in the vicinity of any route
        for (final category in routesByCategory.keys) {
          for (final route in routesByCategory[category]!) {
            final double latMin =
                [
                  route['startLat'],
                  route['endLat'],
                ].reduce((a, b) => a < b ? a : b) -
                0.02;
            final double latMax =
                [
                  route['startLat'],
                  route['endLat'],
                ].reduce((a, b) => a > b ? a : b) +
                0.02;
            final double lngMin =
                [
                  route['startLng'],
                  route['endLng'],
                ].reduce((a, b) => a < b ? a : b) -
                0.02;
            final double lngMax =
                [
                  route['startLng'],
                  route['endLng'],
                ].reduce((a, b) => a > b ? a : b) +
                0.02;

            if (latitude >= latMin &&
                latitude <= latMax &&
                longitude >= lngMin &&
                longitude <= lngMax) {
              // Send reminder to this resident
              await sendNotificationToUser(
                userId: resident.id,
                title: 'Waste Collection Tomorrow',
                body:
                    'Reminder: ${_formatWasteCategory(category)} waste collection in your area tomorrow. Please prepare your waste.',
                channelKey: scheduledChannelKey,
                type: 'waste_collection_reminder',
                referenceId: route['id'],
              );

              // Break after first match to avoid multiple notifications
              break;
            }
          }
        }
      }
    } catch (e) {
      print('Error sending waste collection reminders: $e');
    }
  }

  // Format waste category for display
  String _formatWasteCategory(String category) {
    switch (category.toLowerCase()) {
      case 'organic':
        return 'Organic';
      case 'recyclable':
        return 'Recyclable';
      case 'hazardous':
        return 'Hazardous';
      case 'electronic':
        return 'Electronic';
      case 'mixed':
        return 'General';
      default:
        return 'Waste';
    }
  }

  // Schedule automatic notifications for specific events
  Future<void> scheduleAutomaticNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    required DateTime scheduledTime,
    String? referenceId,
  }) async {
    try {
      // Save as a scheduled notification in Firestore
      await _firestore.collection('scheduledNotifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'referenceId': referenceId,
        'scheduledTime': scheduledTime,
        'sent': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error scheduling automatic notification: $e');
    }
  }

  // Process scheduled notifications (should be called regularly from a server-side process)
  Future<void> processScheduledNotifications() async {
    try {
      final now = DateTime.now();

      // Get all scheduled notifications that are due and not sent
      final snapshot =
          await _firestore
              .collection('scheduledNotifications')
              .where('sent', isEqualTo: false)
              .where('scheduledTime', isLessThanOrEqualTo: now)
              .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();

        // Send the notification
        await sendNotificationToUser(
          userId: data['userId'],
          title: data['title'],
          body: data['body'],
          channelKey: scheduledChannelKey,
          type: data['type'],
          referenceId: data['referenceId'],
        );

        // Mark as sent
        await doc.reference.update({'sent': true});
      }
    } catch (e) {
      print('Error processing scheduled notifications: $e');
    }
  }
}
