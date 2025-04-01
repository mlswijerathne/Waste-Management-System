import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:waste_management/models/cleanlinessIssueModel.dart';
import 'package:waste_management/models/userModel.dart';
import 'package:http/http.dart' as http;

class CleanlinessIssueService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'cleanlinessIssues';
  final Uuid _uuid = Uuid();

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
      
      return issue;
    } catch (e) {
      print('Error creating cleanliness issue: $e');
      rethrow;
    }
  }
  
  // Delete an issue (for admins only)
  Future<bool> deleteIssue(String issueId) async {
    try {
      // Delete from Firestore
      await _firestore.collection(_collection).doc(issueId).delete();
      return true;
    } catch (e) {
      print('Error deleting cleanliness issue: $e');
      return false;
    }
  }
  
  // Get all cleanliness issues
  Future<List<CleanlinessIssueModel>> getAllIssues() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection(_collection).orderBy('reportedTime', descending: true).get();
      
      return snapshot.docs.map((doc) {
        return CleanlinessIssueModel.fromMap(doc.data() as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      print('Error getting all cleanliness issues: $e');
      return [];
    }
  }
  
  // Get issues reported by a specific resident
  Future<List<CleanlinessIssueModel>> getResidentIssues(String residentId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('residentId', isEqualTo: residentId)
          .orderBy('reportedTime', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        return CleanlinessIssueModel.fromMap(doc.data() as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      print('Error getting resident cleanliness issues: $e');
      return [];
    }
  }
  
  // Get issues assigned to a specific driver
  Future<List<CleanlinessIssueModel>> getDriverAssignedIssues(String driverId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('assignedDriverId', isEqualTo: driverId)
          .where('status', whereIn: ['assigned', 'inProgress'])
          .orderBy('assignedTime', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        return CleanlinessIssueModel.fromMap(doc.data() as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      print('Error getting driver assigned cleanliness issues: $e');
      return [];
    }
  }
  
  // Get all pending issues (for city management)
  Future<List<CleanlinessIssueModel>> getPendingIssues() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: 'pending')
          .orderBy('reportedTime', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        return CleanlinessIssueModel.fromMap(doc.data() as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      print('Error getting pending cleanliness issues: $e');
      return [];
    }
  }
  
  // Get a specific issue by ID
  Future<CleanlinessIssueModel?> getIssueById(String issueId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection(_collection).doc(issueId).get();
      
      if (doc.exists) {
        return CleanlinessIssueModel.fromMap(doc.data() as Map<String, dynamic>);
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
      return true;
    } catch (e) {
      print('Error updating resident feedback: $e');
      return false;
    }
  }
  
  // Listen to real-time updates for a specific issue
  Stream<CleanlinessIssueModel?> getIssueStream(String issueId) {
    return _firestore
        .collection(_collection)
        .doc(issueId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        return CleanlinessIssueModel.fromMap(snapshot.data() as Map<String, dynamic>);
      }
      return null;
    });
  }
  
  // Listen to real-time updates for a resident's issues
  Stream<List<CleanlinessIssueModel>> getResidentIssuesStream(String residentId) {
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
}