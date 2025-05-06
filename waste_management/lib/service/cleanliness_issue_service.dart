import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:waste_management/models/cleanlinessIssueModel.dart';
import 'package:waste_management/models/userModel.dart';
import 'package:waste_management/service/notification_service.dart';
import 'package:http/http.dart' as http;

class CleanlinessIssueService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'cleanlinessIssues';
  final Uuid _uuid = Uuid();
  final NotificationService _notificationService = NotificationService();

  // Create a new cleanliness issue report with base64 image
  Future<CleanlinessIssueModel> createIssueWithBase64Image({
    required UserModel resident,
    required String description,
    required String location,
    required double latitude,
    required double longitude,
    required String base64Image,
  }) async {
    try {
      // Generate a unique ID for the issue
      String issueId = _uuid.v4();

      // Create new cleanliness issue model
      CleanlinessIssueModel issue = CleanlinessIssueModel(
        id: issueId,
        residentId: resident.uid,
        residentName: resident.name,
        description: description,
        location: location,
        latitude: latitude,
        longitude: longitude,
        imageUrl: base64Image, // Store base64 string directly
        reportedTime: DateTime.now(),
        status: 'pending',
      );

      // Save to Firestore
      await _firestore.collection(_collection).doc(issueId).set(issue.toMap());

      // Send notification to city management/admin
      await _notificationService.sendCleanlinessIssueNotification(
        title: 'New Cleanliness Issue',
        body: 'A new cleanliness issue has been reported at $location',
        type: 'new_cleanliness_issue',
        roles: ['cityManagement'],
        issueId: issueId,
      );

      return issue;
    } catch (e) {
      print('Error creating cleanliness issue: $e');
      rethrow;
    }
  }

  // Delete an issue (for admins only)
  Future<bool> deleteIssue(String issueId) async {
    try {
      // Get the issue before deleting (to know who reported it)
      CleanlinessIssueModel? issue = await getIssueById(issueId);

      // Delete from Firestore
      await _firestore.collection(_collection).doc(issueId).delete();

      // Notify the resident who reported the issue
      if (issue != null) {
        await _notificationService.sendNotificationToUser(
          userId: issue.residentId,
          title: 'Issue Deleted',
          body:
              'Your cleanliness issue report has been removed by administration',
          channelKey: NotificationService.cleanlinessIssueChannelKey,
          type: 'cleanliness_issue_deleted',
          referenceId: issueId,
        );
      }

      return true;
    } catch (e) {
      print('Error deleting cleanliness issue: $e');
      return false;
    }
  }

  // Get all cleanliness issues
  Future<List<CleanlinessIssueModel>> getAllIssues() async {
    try {
      QuerySnapshot snapshot =
          await _firestore
              .collection(_collection)
              .orderBy('reportedTime', descending: true)
              .get();

      return snapshot.docs.map((doc) {
        return CleanlinessIssueModel.fromMap(
          doc.data() as Map<String, dynamic>,
        );
      }).toList();
    } catch (e) {
      print('Error getting all cleanliness issues: $e');
      return [];
    }
  }

  // Get issues reported by a specific resident
  Future<List<CleanlinessIssueModel>> getResidentIssues(
    String residentId,
  ) async {
    try {
      QuerySnapshot snapshot =
          await _firestore
              .collection(_collection)
              .where('residentId', isEqualTo: residentId)
              .orderBy('reportedTime', descending: true)
              .get();

      return snapshot.docs.map((doc) {
        return CleanlinessIssueModel.fromMap(
          doc.data() as Map<String, dynamic>,
        );
      }).toList();
    } catch (e) {
      print('Error getting resident cleanliness issues: $e');
      return [];
    }
  }

  // Get issues assigned to a specific driver
  Future<List<CleanlinessIssueModel>> getDriverAssignedIssues(
    String driverId,
  ) async {
    try {
      QuerySnapshot snapshot =
          await _firestore
              .collection(_collection)
              .where('assignedDriverId', isEqualTo: driverId)
              .where('status', whereIn: ['assigned', 'inProgress'])
              .orderBy('assignedTime', descending: true)
              .get();

      return snapshot.docs.map((doc) {
        return CleanlinessIssueModel.fromMap(
          doc.data() as Map<String, dynamic>,
        );
      }).toList();
    } catch (e) {
      print('Error getting driver assigned cleanliness issues: $e');
      return [];
    }
  }

  // Get all pending issues (for city management)
  Future<List<CleanlinessIssueModel>> getPendingIssues() async {
    try {
      QuerySnapshot snapshot =
          await _firestore
              .collection(_collection)
              .where('status', isEqualTo: 'pending')
              .orderBy('reportedTime', descending: true)
              .get();

      return snapshot.docs.map((doc) {
        return CleanlinessIssueModel.fromMap(
          doc.data() as Map<String, dynamic>,
        );
      }).toList();
    } catch (e) {
      print('Error getting pending cleanliness issues: $e');
      return [];
    }
  }

  // Get a specific issue by ID
  Future<CleanlinessIssueModel?> getIssueById(String issueId) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection(_collection).doc(issueId).get();

      if (doc.exists) {
        return CleanlinessIssueModel.fromMap(
          doc.data() as Map<String, dynamic>,
        );
      }
      return null;
    } catch (e) {
      print('Error getting cleanliness issue by ID: $e');
      return null;
    }
  }

  // Update issue status (for admins and drivers)
  Future<bool> updateIssueStatus({
    required String issueId,
    required String newStatus,
    String? driverId,
    String? driverName,
  }) async {
    try {
      Map<String, dynamic> updateData = {'status': newStatus};

      if (newStatus == 'assigned' && driverId != null && driverName != null) {
        updateData['assignedDriverId'] = driverId;
        updateData['assignedDriverName'] = driverName;
        updateData['assignedTime'] = DateTime.now().toIso8601String();
      } else if (newStatus == 'resolved') {
        updateData['resolvedTime'] = DateTime.now().toIso8601String();
      }

      await _firestore.collection(_collection).doc(issueId).update(updateData);

      // Get the issue to know who to notify
      CleanlinessIssueModel? issue = await getIssueById(issueId);

      if (issue != null) {
        // When issue is assigned to a driver
        if (newStatus == 'assigned' && driverId != null && driverName != null) {
          // Notify the assigned driver
          await _notificationService.sendNotificationToUser(
            userId: driverId,
            title: 'New Issue Assignment',
            body:
                'You have been assigned a cleanliness issue at ${issue.location}',
            channelKey: NotificationService.cleanlinessIssueChannelKey,
            type: 'issue_assigned',
            referenceId: issueId,
          );

          // Notify the resident who reported the issue
          await _notificationService.sendNotificationToUser(
            userId: issue.residentId,
            title: 'Issue Update',
            body: 'Your reported cleanliness issue is now assigned to a worker',
            channelKey: NotificationService.cleanlinessIssueChannelKey,
            type: 'issue_status_update',
            referenceId: issueId,
          );

          // Notify admins
          await _notificationService.sendCleanlinessIssueNotification(
            title: 'Issue Assigned',
            body: 'Cleanliness issue has been assigned to $driverName',
            type: 'issue_assigned',
            roles: ['cityManagement'],
            issueId: issueId,
          );
        }
        // When issue is in progress
        else if (newStatus == 'inProgress') {
          // Notify resident
          await _notificationService.sendNotificationToUser(
            userId: issue.residentId,
            title: 'Issue In Progress',
            body: 'Work has begun on your reported cleanliness issue',
            channelKey: NotificationService.cleanlinessIssueChannelKey,
            type: 'issue_in_progress',
            referenceId: issueId,
          );

          // Notify admin
          await _notificationService.sendCleanlinessIssueNotification(
            title: 'Issue In Progress',
            body: 'Work has begun on cleanliness issue at ${issue.location}',
            type: 'issue_in_progress',
            roles: ['cityManagement'],
            issueId: issueId,
          );
        }
        // When issue is resolved
        else if (newStatus == 'resolved') {
          // Notify resident to confirm resolution
          await _notificationService.sendNotificationToUser(
            userId: issue.residentId,
            title: 'Issue Resolved',
            body:
                'Your reported cleanliness issue has been marked as resolved. Please confirm.',
            channelKey: NotificationService.cleanlinessIssueChannelKey,
            type: 'issue_resolved',
            referenceId: issueId,
          );

          // If there was an assigned driver, notify them too
          if (issue.assignedDriverId != null) {
            await _notificationService.sendNotificationToUser(
              userId: issue.assignedDriverId!,
              title: 'Issue Marked Resolved',
              body:
                  'The cleanliness issue you were working on has been marked as resolved',
              channelKey: NotificationService.cleanlinessIssueChannelKey,
              type: 'issue_resolved',
              referenceId: issueId,
            );
          }

          // Notify admin
          await _notificationService.sendCleanlinessIssueNotification(
            title: 'Issue Resolved',
            body:
                'Cleanliness issue at ${issue.location} has been marked as resolved',
            type: 'issue_resolved',
            roles: ['cityManagement'],
            issueId: issueId,
          );
        }
      }

      return true;
    } catch (e) {
      print('Error updating cleanliness issue status: $e');
      return false;
    }
  }

  // Update resident confirmation and feedback
  Future<bool> updateResidentFeedback({
    required String issueId,
    required bool confirmed,
    String? feedback,
  }) async {
    try {
      await _firestore.collection(_collection).doc(issueId).update({
        'residentConfirmed': confirmed,
        'residentFeedback': feedback,
        // If confirmed, also mark as fully completed
        if (confirmed) 'status': 'resolved',
      });

      // Get the issue details
      CleanlinessIssueModel? issue = await getIssueById(issueId);

      if (issue != null) {
        // If there was a driver assigned, notify them about the confirmation
        if (issue.assignedDriverId != null) {
          String feedbackMsg =
              confirmed
                  ? 'The resident has confirmed that the issue was resolved successfully'
                  : 'The resident has indicated that the issue is not fully resolved yet';

          await _notificationService.sendNotificationToUser(
            userId: issue.assignedDriverId!,
            title: 'Resident Feedback',
            body: feedbackMsg,
            channelKey: NotificationService.cleanlinessIssueChannelKey,
            type: confirmed ? 'issue_confirmed' : 'issue_not_confirmed',
            referenceId: issueId,
          );
        }

        // Notify city management
        String feedbackMsg =
            confirmed
                ? 'A resolved cleanliness issue has been confirmed by the resident'
                : 'A resident has reported that an issue marked as resolved is not actually fixed';

        await _notificationService.sendCleanlinessIssueNotification(
          title: 'Resident Feedback',
          body: feedbackMsg,
          type: confirmed ? 'issue_confirmed' : 'issue_not_confirmed',
          roles: ['cityManagement'],
          issueId: issueId,
        );
      }

      return true;
    } catch (e) {
      print('Error updating resident feedback: $e');
      return false;
    }
  }

  // Listen to real-time updates for a specific issue
  Stream<CleanlinessIssueModel?> getIssueStream(String issueId) {
    return _firestore.collection(_collection).doc(issueId).snapshots().map((
      snapshot,
    ) {
      if (snapshot.exists) {
        return CleanlinessIssueModel.fromMap(
          snapshot.data() as Map<String, dynamic>,
        );
      }
      return null;
    });
  }

  // Listen to real-time updates for a resident's issues
  Stream<List<CleanlinessIssueModel>> getResidentIssuesStream(
    String residentId,
  ) {
    return _firestore
        .collection(_collection)
        .where('residentId', isEqualTo: residentId)
        .orderBy('reportedTime', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return CleanlinessIssueModel.fromMap(doc.data());
          }).toList();
        });
  }

  // Listen to real-time updates for a driver's assigned issues
  Stream<List<CleanlinessIssueModel>> getDriverIssuesStream(String driverId) {
    return _firestore
        .collection(_collection)
        .where('assignedDriverId', isEqualTo: driverId)
        .where('status', whereIn: ['assigned', 'inProgress'])
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return CleanlinessIssueModel.fromMap(doc.data());
          }).toList();
        });
  }

  // Listen to real-time updates for all issues
  Stream<List<CleanlinessIssueModel>> getAllIssuesStream() {
    return _firestore
        .collection(_collection)
        .orderBy('reportedTime', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return CleanlinessIssueModel.fromMap(doc.data());
          }).toList();
        });
  }

  // Mark an issue as resolved
  Future<void> markIssueResolved({
    required String issueId,
    String? notes,
  }) async {
    try {
      await _firestore.collection(_collection).doc(issueId).update({
        'status': 'resolved',
        'resolvedTime': DateTime.now().toIso8601String(),
        if (notes != null) 'resolutionNotes': notes,
      });

      // Get the issue to know who to notify
      CleanlinessIssueModel? issue = await getIssueById(issueId);

      if (issue != null) {
        // Notify resident
        await _notificationService.sendNotificationToUser(
          userId: issue.residentId,
          title: 'Issue Resolved',
          body:
              'Your reported cleanliness issue has been marked as resolved. Please confirm.',
          channelKey: NotificationService.cleanlinessIssueChannelKey,
          type: 'issue_resolved',
          referenceId: issueId,
        );

        // Notify admin
        await _notificationService.sendCleanlinessIssueNotification(
          title: 'Issue Marked as Resolved',
          body:
              'Cleanliness issue at ${issue.location} has been marked as resolved',
          type: 'issue_resolved',
          roles: ['cityManagement'],
          issueId: issueId,
        );
      }
    } catch (e) {
      print('Error marking issue as resolved: $e');
      rethrow;
    }
  }
}
