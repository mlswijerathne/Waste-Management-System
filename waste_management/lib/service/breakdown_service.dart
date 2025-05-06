import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:waste_management/models/breakdownReportModel.dart'; // Assuming the model is in this file
import 'package:waste_management/service/notification_service.dart';

class BreakdownService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  // Create a new breakdown report
  Future<String> createBreakdownReport({
    required BreakdownIssueType issueType,
    required String description,
    required BreakdownDelay delay,
    String? vehicleId,
    String? location,
  }) async {
    try {
      // Get current user
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Create a new breakdown report
      final breakdownReport = BreakdownReport(
        id: _firestore.collection('breakdown_reports').doc().id,
        userId: currentUser.uid,
        issueType: issueType,
        description: description,
        delay: delay,
        vehicleId: vehicleId,
        location: location,
      );

      // Save to Firestore
      await _firestore
          .collection('breakdown_reports')
          .doc(breakdownReport.id)
          .set(breakdownReport.toMap());

      // Send notification to administrators
      await _notificationService.sendBreakdownNotification(
        title: 'New Breakdown Report',
        body: 'A new breakdown has been reported: ${issueType.value}',
        type: 'new_breakdown',
        roles: ['cityManagement'],
        breakdownId: breakdownReport.id,
      );

      return breakdownReport.id;
    } catch (e) {
      print('Error creating breakdown report: $e');
      rethrow;
    }
  }

  // Get a specific breakdown report by ID
  Future<BreakdownReport?> getBreakdownReport(String reportId) async {
    try {
      final doc =
          await _firestore.collection('breakdown_reports').doc(reportId).get();

      if (!doc.exists) return null;

      return BreakdownReport.fromMap(doc.data()!);
    } catch (e) {
      print('Error fetching breakdown report: $e');
      return null;
    }
  }

  // Get all breakdown reports for the current user
  Stream<List<BreakdownReport>> getUserBreakdownReports() {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        return Stream.value([]);
      }

      return _firestore
          .collection('breakdown_reports')
          .where('userId', isEqualTo: currentUser.uid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => BreakdownReport.fromMap(doc.data()))
                .toList();
          });
    } catch (e) {
      print('Error fetching user breakdown reports: $e');
      return Stream.value([]);
    }
  }

  // Update breakdown report status
  Future<void> updateBreakdownReportStatus({
    required String reportId,
    required BreakdownStatus newStatus,
  }) async {
    try {
      await _firestore.collection('breakdown_reports').doc(reportId).update({
        'status': newStatus.value,
      });

      // Get the report to send notifications
      final report = await getBreakdownReport(reportId);
      if (report != null) {
        // Notification for the driver who reported the breakdown
        await _notificationService.sendNotificationToUser(
          userId: report.userId,
          title: 'Breakdown Status Updated',
          body:
              'Your breakdown report status has been updated to: ${newStatus.value}',
          channelKey: NotificationService.breakdownChannelKey,
          type: 'breakdown_status_update',
          referenceId: reportId,
        );

        // Notification for admins about the status change
        await _notificationService.sendBreakdownNotification(
          title: 'Breakdown Status Changed',
          body:
              'Breakdown #${reportId.substring(0, 8)} status changed to: ${newStatus.value}',
          type: 'breakdown_status_change',
          roles: ['cityManagement'],
          breakdownId: reportId,
        );
      }
    } catch (e) {
      print('Error updating breakdown report status: $e');
      rethrow;
    }
  }

  // Delete a breakdown report
  Future<void> deleteBreakdownReport(String reportId) async {
    try {
      // Get the report before deletion to know the user
      final report = await getBreakdownReport(reportId);

      await _firestore.collection('breakdown_reports').doc(reportId).delete();

      // Notify the user who created the report
      if (report != null) {
        await _notificationService.sendNotificationToUser(
          userId: report.userId,
          title: 'Breakdown Report Deleted',
          body: 'Your breakdown report has been deleted by administration.',
          channelKey: NotificationService.breakdownChannelKey,
          type: 'breakdown_deleted',
          referenceId: reportId,
        );
      }
    } catch (e) {
      print('Error deleting breakdown report: $e');
      rethrow;
    }
  }

  // Get breakdown reports filtered by issue type
  Stream<List<BreakdownReport>> getBreakdownReportsByIssueType(
    BreakdownIssueType issueType,
  ) {
    try {
      return _firestore
          .collection('breakdown_reports')
          .where('issueType', isEqualTo: issueType.value)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => BreakdownReport.fromMap(doc.data()))
                .toList();
          });
    } catch (e) {
      print('Error fetching breakdown reports by issue type: $e');
      return Stream.value([]);
    }
  }

  // Get breakdown reports by status
  Stream<List<BreakdownReport>> getBreakdownReportsByStatus(
    BreakdownStatus status,
  ) {
    try {
      return _firestore
          .collection('breakdown_reports')
          .where('status', isEqualTo: status.value)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => BreakdownReport.fromMap(doc.data()))
                .toList();
          });
    } catch (e) {
      print('Error fetching breakdown reports by status: $e');
      return Stream.value([]);
    }
  }

  // Add a comment to a breakdown report (optional feature)
  Future<void> addCommentToReport({
    required String reportId,
    required String comment,
  }) async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _firestore.collection('breakdown_reports').doc(reportId).update({
        'comments': FieldValue.arrayUnion([
          {
            'userId': currentUser.uid,
            'userName': currentUser.displayName ?? 'User',
            'text': comment,
            'timestamp': DateTime.now().toIso8601String(),
          },
        ]),
      });

      // Get the report to know who to notify
      final report = await getBreakdownReport(reportId);
      if (report != null && report.userId != currentUser.uid) {
        // Notify the report creator that someone commented
        await _notificationService.sendNotificationToUser(
          userId: report.userId,
          title: 'New Comment on Your Breakdown Report',
          body: 'Someone has commented on your breakdown report.',
          channelKey: NotificationService.breakdownChannelKey,
          type: 'breakdown_comment',
          referenceId: reportId,
        );
      }

      // Notify admins about the comment
      if (currentUser.uid != report?.userId) {
        await _notificationService.sendBreakdownNotification(
          title: 'New Comment on Breakdown Report',
          body:
              'A new comment has been added to breakdown report #${reportId.substring(0, 8)}',
          type: 'breakdown_comment',
          roles: ['cityManagement'],
          breakdownId: reportId,
        );
      }
    } catch (e) {
      print('Error adding comment to breakdown report: $e');
      rethrow;
    }
  }
}
