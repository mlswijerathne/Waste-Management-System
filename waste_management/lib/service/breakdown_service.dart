import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:waste_management/models/breakdownReportModel.dart'; // Assuming the model is in this file

class BreakdownService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

      return breakdownReport.id;
    } catch (e) {
      print('Error creating breakdown report: $e');
      rethrow;
    }
  }

  // Get a specific breakdown report by ID
  Future<BreakdownReport?> getBreakdownReport(String reportId) async {
    try {
      final doc = await _firestore
          .collection('breakdown_reports')
          .doc(reportId)
          .get();

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
        throw Exception('User not authenticated');
      }

      return _firestore
          .collection('breakdown_reports')
          .where('userId', isEqualTo: currentUser.uid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => BreakdownReport.fromMap(doc.data()))
              .toList());
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
      await _firestore
          .collection('breakdown_reports')
          .doc(reportId)
          .update({'status': newStatus.value});
    } catch (e) {
      print('Error updating breakdown report status: $e');
      rethrow;
    }
  }

  // Delete a breakdown report
  Future<void> deleteBreakdownReport(String reportId) async {
    try {
      await _firestore.collection('breakdown_reports').doc(reportId).delete();
    } catch (e) {
      print('Error deleting breakdown report: $e');
      rethrow;
    }
  }

  // Get breakdown reports filtered by issue type
  Stream<List<BreakdownReport>> getBreakdownReportsByIssueType(
      BreakdownIssueType issueType) {
    try {
      return _firestore
          .collection('breakdown_reports')
          .where('issueType', isEqualTo: issueType.value)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => BreakdownReport.fromMap(doc.data()))
              .toList());
    } catch (e) {
      print('Error fetching breakdown reports by issue type: $e');
      return Stream.value([]);
    }
  }

  // Get breakdown reports by status
  Stream<List<BreakdownReport>> getBreakdownReportsByStatus(
      BreakdownStatus status) {
    try {
      return _firestore
          .collection('breakdown_reports')
          .where('status', isEqualTo: status.value)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => BreakdownReport.fromMap(doc.data()))
              .toList());
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
            'comment': comment,
            'timestamp': FieldValue.serverTimestamp(),
          }
        ])
      });
    } catch (e) {
      print('Error adding comment to breakdown report: $e');
      rethrow;
    }
  }
}