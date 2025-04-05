import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:waste_management/models/specialGarbageRequestModel.dart';
import 'package:waste_management/models/userModel.dart';

class SpecialGarbageRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'specialGarbageRequests';
  final Uuid _uuid = Uuid();

  // Create a new special garbage collection request
  Future<SpecialGarbageRequestModel> createRequest({
    required UserModel resident,
    required String description,
    required String garbageType,
    required String location,
    required double latitude,
    required double longitude,
    String? base64Image,
    double? estimatedWeight,
    String? notes,
  }) async {
    try {
      // Generate a unique ID for the request
      String requestId = _uuid.v4();
      
      // Create new special garbage request model
      SpecialGarbageRequestModel request = SpecialGarbageRequestModel(
        id: requestId,
        residentId: resident.uid,
        residentName: resident.name,
        description: description,
        garbageType: garbageType,
        location: location,
        latitude: latitude,
        longitude: longitude,
        imageUrl: base64Image, // Optional image
        requestedTime: DateTime.now(),
        status: 'pending',
        estimatedWeight: estimatedWeight,
        notes: notes,
      );
      
      // Save to Firestore
      await _firestore.collection(_collection).doc(requestId).set(request.toMap());
      
      return request;
    } catch (e) {
      print('Error creating special garbage request: $e');
      rethrow;
    }
  }
  
  // Get all requests (for admins)
  Future<List<SpecialGarbageRequestModel>> getAllRequests() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .orderBy('requestedTime', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        return SpecialGarbageRequestModel.fromMap(doc.data() as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      print('Error getting all special garbage requests: $e');
      return [];
    }
  }
  
  // Get requests submitted by a specific resident
  Future<List<SpecialGarbageRequestModel>> getResidentRequests(String residentId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('residentId', isEqualTo: residentId)
          .orderBy('requestedTime', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        return SpecialGarbageRequestModel.fromMap(doc.data() as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      print('Error getting resident special garbage requests: $e');
      return [];
    }
  }
  
  // Get requests assigned to a specific driver
  Future<List<SpecialGarbageRequestModel>> getDriverAssignedRequests(String driverId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('assignedDriverId', isEqualTo: driverId)
          .where('status', whereIn: ['assigned'])
          .orderBy('assignedTime', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        return SpecialGarbageRequestModel.fromMap(doc.data() as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      print('Error getting driver assigned garbage requests: $e');
      return [];
    }
  }
  
  // Get all pending requests (for admin)
  Future<List<SpecialGarbageRequestModel>> getPendingRequests() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: 'pending')
          .orderBy('requestedTime', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        return SpecialGarbageRequestModel.fromMap(doc.data() as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      print('Error getting pending special garbage requests: $e');
      return [];
    }
  }
  
  // Get a specific request by ID
  Future<SpecialGarbageRequestModel?> getRequestById(String requestId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection(_collection).doc(requestId).get();
      
      if (doc.exists) {
        return SpecialGarbageRequestModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting special garbage request by ID: $e');
      return null;
    }
  }
  
  // Assign request to driver (for admin)
  Future<bool> assignRequestToDriver({
    required String requestId,
    required String driverId,
    required String driverName,
  }) async {
    try {
      await _firestore.collection(_collection).doc(requestId).update({
        'status': 'assigned',
        'assignedDriverId': driverId,
        'assignedDriverName': driverName,
        'assignedTime': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error assigning special garbage request to driver: $e');
      return false;
    }
  }
  
  // Mark request as collected (for driver)
  Future<bool> markRequestCollected({
    required String requestId,
    double? actualWeight,
    String? notes,
  }) async {
    try {
      Map<String, dynamic> updateData = {
        'status': 'collected',
        'collectedTime': DateTime.now().toIso8601String(),
      };
      
      if (actualWeight != null) {
        updateData['estimatedWeight'] = actualWeight;
      }
      
      if (notes != null) {
        updateData['notes'] = notes;
      }
      
      await _firestore.collection(_collection).doc(requestId).update(updateData);
      return true;
    } catch (e) {
      print('Error marking special garbage request as collected: $e');
      return false;
    }
  }
  
  // Update resident confirmation and feedback
  Future<bool> updateResidentFeedback({
    required String requestId,
    required bool confirmed,
    String? feedback,
  }) async {
    try {
      await _firestore.collection(_collection).doc(requestId).update({
        'residentConfirmed': confirmed,
        'residentFeedback': feedback,
        // If confirmed, also mark as fully completed
        if (confirmed) 'status': 'completed',
      });
      return true;
    } catch (e) {
      print('Error updating resident feedback for special garbage request: $e');
      return false;
    }
  }
  
  // Delete a request (for admins only)
  Future<bool> deleteRequest(String requestId) async {
    try {
      await _firestore.collection(_collection).doc(requestId).delete();
      return true;
    } catch (e) {
      print('Error deleting special garbage request: $e');
      return false;
    }
  }
  
  // Listen to real-time updates for a specific request
  Stream<SpecialGarbageRequestModel?> getRequestStream(String requestId) {
    return _firestore
        .collection(_collection)
        .doc(requestId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        return SpecialGarbageRequestModel.fromMap(snapshot.data() as Map<String, dynamic>);
      }
      return null;
    });
  }
  
  // Listen to real-time updates for a resident's requests
  Stream<List<SpecialGarbageRequestModel>> getResidentRequestsStream(String residentId) {
    return _firestore
        .collection(_collection)
        .where('residentId', isEqualTo: residentId)
        .orderBy('requestedTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return SpecialGarbageRequestModel.fromMap(doc.data());
      }).toList();
    });
  }
  
  // Listen to real-time updates for a driver's assigned requests
  Stream<List<SpecialGarbageRequestModel>> getDriverRequestsStream(String driverId) {
    return _firestore
        .collection(_collection)
        .where('assignedDriverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'assigned')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return SpecialGarbageRequestModel.fromMap(doc.data());
      }).toList();
    });
  }
}