import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:waste_management/models/specialGarbageRequestModel.dart';
import 'package:waste_management/models/userModel.dart';
import 'package:waste_management/service/notification_service.dart';

class SpecialGarbageRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'specialGarbageRequests';
  final Uuid _uuid = Uuid();
  final NotificationService _notificationService = NotificationService();

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
      await _firestore
          .collection(_collection)
          .doc(requestId)
          .set(request.toMap());

      // Send notification to admin/city management
      await _notificationService.sendSpecialGarbageNotification(
        title: 'New Special Garbage Request',
        body: '$garbageType disposal requested at $location',
        type: 'new_special_garbage_request',
        roles: ['cityManagement'],
        requestId: requestId,
      );

      return request;
    } catch (e) {
      print('Error creating special garbage request: $e');
      rethrow;
    }
  }

  // Get all requests (for admins)
  Future<List<SpecialGarbageRequestModel>> getAllRequests() async {
    try {
      QuerySnapshot snapshot =
          await _firestore
              .collection(_collection)
              .orderBy('requestedTime', descending: true)
              .get();

      return snapshot.docs.map((doc) {
        return SpecialGarbageRequestModel.fromMap(
          doc.data() as Map<String, dynamic>,
        );
      }).toList();
    } catch (e) {
      print('Error getting all special garbage requests: $e');
      return [];
    }
  }

  // Get requests submitted by a specific resident
  Future<List<SpecialGarbageRequestModel>> getResidentRequests(
    String residentId,
  ) async {
    try {
      QuerySnapshot snapshot =
          await _firestore
              .collection(_collection)
              .where('residentId', isEqualTo: residentId)
              .orderBy('requestedTime', descending: true)
              .get();

      return snapshot.docs.map((doc) {
        return SpecialGarbageRequestModel.fromMap(
          doc.data() as Map<String, dynamic>,
        );
      }).toList();
    } catch (e) {
      print('Error getting resident special garbage requests: $e');
      return [];
    }
  }

  // Get requests assigned to a specific driver (only assigned status)
  Future<List<SpecialGarbageRequestModel>> getDriverAssignedRequests(
    String driverId,
  ) async {
    try {
      QuerySnapshot snapshot =
          await _firestore
              .collection(_collection)
              .where('assignedDriverId', isEqualTo: driverId)
              .where('status', isEqualTo: 'assigned')
              .get();

      return snapshot.docs.map((doc) {
        return SpecialGarbageRequestModel.fromMap(
          doc.data() as Map<String, dynamic>,
        );
      }).toList();
    } catch (e) {
      print('Error getting driver assigned garbage requests: $e');
      return [];
    }
  }

  // Get only assigned and collected requests for driver (optimized)
  Future<List<SpecialGarbageRequestModel>> getDriverOnlyActiveRequests(
    String driverId,
  ) async {
    try {
      QuerySnapshot snapshot =
          await _firestore
              .collection(_collection)
              .where('assignedDriverId', isEqualTo: driverId)
              .where('status', whereIn: ['assigned', 'collected'])
              .get();

      return snapshot.docs.map((doc) {
        return SpecialGarbageRequestModel.fromMap(
          doc.data() as Map<String, dynamic>,
        );
      }).toList();
    } catch (e) {
      print('Error getting driver active garbage requests: $e');
      return [];
    }
  }

  // Get all pending requests (for admin)
  Future<List<SpecialGarbageRequestModel>> getPendingRequests() async {
    try {
      QuerySnapshot snapshot =
          await _firestore
              .collection(_collection)
              .where('status', isEqualTo: 'pending')
              .orderBy('requestedTime', descending: true)
              .get();

      return snapshot.docs.map((doc) {
        return SpecialGarbageRequestModel.fromMap(
          doc.data() as Map<String, dynamic>,
        );
      }).toList();
    } catch (e) {
      print('Error getting pending special garbage requests: $e');
      return [];
    }
  }

  // Get a specific request by ID
  Future<SpecialGarbageRequestModel?> getRequestById(String requestId) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection(_collection).doc(requestId).get();

      if (doc.exists) {
        return SpecialGarbageRequestModel.fromMap(
          doc.data() as Map<String, dynamic>,
        );
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

      // Get request details for notification
      SpecialGarbageRequestModel? request = await getRequestById(requestId);
      if (request != null) {
        // Notify the assigned driver
        await _notificationService.sendNotificationToUser(
          userId: driverId,
          title: 'New Special Collection Assigned',
          body:
              'You have been assigned a special garbage collection at ${request.location}',
          channelKey: NotificationService.specialGarbageChannelKey,
          type: 'special_garbage_assigned',
          referenceId: requestId,
        );

        // Notify the resident who made the request
        await _notificationService.sendNotificationToUser(
          userId: request.residentId,
          title: 'Special Collection Update',
          body:
              'Your special garbage collection request has been assigned to a driver',
          channelKey: NotificationService.specialGarbageChannelKey,
          type: 'special_garbage_status_update',
          referenceId: requestId,
        );

        // Notify admins
        await _notificationService.sendSpecialGarbageNotification(
          title: 'Special Collection Assigned',
          body:
              'Special garbage collection has been assigned to driver $driverName',
          type: 'special_garbage_assigned',
          roles: ['cityManagement'],
          requestId: requestId,
        );
      }

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

      await _firestore
          .collection(_collection)
          .doc(requestId)
          .update(updateData);

      // Get request details for notification
      SpecialGarbageRequestModel? request = await getRequestById(requestId);
      if (request != null) {
        // Notify the resident that their garbage has been collected
        await _notificationService.sendNotificationToUser(
          userId: request.residentId,
          title: 'Special Collection Completed',
          body:
              'Your special garbage has been collected. Please confirm collection was done properly.',
          channelKey: NotificationService.specialGarbageChannelKey,
          type: 'special_garbage_collected',
          referenceId: requestId,
        );

        // Notify the driver who collected the garbage (confirmation of action)
        if (request.assignedDriverId != null) {
          await _notificationService.sendNotificationToUser(
            userId: request.assignedDriverId!,
            title: 'Collection Confirmed',
            body:
                'You have successfully marked the special garbage as collected.',
            channelKey: NotificationService.specialGarbageChannelKey,
            type: 'special_garbage_collected_confirmation',
            referenceId: requestId,
          );
        }

        // Notify admins
        await _notificationService.sendSpecialGarbageNotification(
          title: 'Special Collection Completed',
          body:
              'Driver ${request.assignedDriverName} has collected special garbage from ${request.location}',
          type: 'special_garbage_collected',
          roles: ['cityManagement'],
          requestId: requestId,
        );
      }

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

      // Get request details for notification
      SpecialGarbageRequestModel? request = await getRequestById(requestId);
      if (request != null) {
        // If there was a driver assigned, notify them about the confirmation
        if (request.assignedDriverId != null) {
          String feedbackMsg =
              confirmed
                  ? 'The resident has confirmed that the special garbage collection was completed successfully'
                  : 'The resident has reported an issue with the special garbage collection';

          await _notificationService.sendNotificationToUser(
            userId: request.assignedDriverId!,
            title: 'Resident Feedback',
            body: feedbackMsg,
            channelKey: NotificationService.specialGarbageChannelKey,
            type:
                confirmed
                    ? 'special_garbage_confirmed'
                    : 'special_garbage_issue',
            referenceId: requestId,
          );
        }

        // Notify admins
        String feedbackMsg =
            confirmed
                ? 'Resident has confirmed successful completion of special garbage collection'
                : 'Resident has reported an issue with special garbage collection';

        await _notificationService.sendSpecialGarbageNotification(
          title: 'Resident Feedback on Special Collection',
          body: feedbackMsg,
          type:
              confirmed ? 'special_garbage_confirmed' : 'special_garbage_issue',
          roles: ['cityManagement'],
          requestId: requestId,
        );
      }

      return true;
    } catch (e) {
      print('Error updating resident feedback for special garbage request: $e');
      return false;
    }
  }

  // Get completed requests for a specific driver
  Future<List<SpecialGarbageRequestModel>> getDriverCompletedRequests(
    String driverId,
  ) async {
    try {
      QuerySnapshot snapshot =
          await _firestore
              .collection(_collection)
              .where('assignedDriverId', isEqualTo: driverId)
              .where('status', isEqualTo: 'completed')
              .orderBy('requestedTime', descending: true)
              .get();

      return snapshot.docs.map((doc) {
        return SpecialGarbageRequestModel.fromMap(
          doc.data() as Map<String, dynamic>,
        );
      }).toList();
    } catch (e) {
      print('Error getting driver completed garbage requests: $e');
      return [];
    }
  }

  // Delete a request (for admins only)
  Future<bool> deleteRequest(String requestId) async {
    try {
      // Get request details before deletion
      SpecialGarbageRequestModel? request = await getRequestById(requestId);

      await _firestore.collection(_collection).doc(requestId).delete();

      if (request != null) {
        // Notify the resident that their request was deleted
        await _notificationService.sendNotificationToUser(
          userId: request.residentId,
          title: 'Request Deleted',
          body: 'Your special garbage collection request has been deleted',
          channelKey: NotificationService.specialGarbageChannelKey,
          type: 'special_garbage_deleted',
          referenceId: null, // No reference since it's deleted
        );

        // If a driver was assigned, notify them too
        if (request.assignedDriverId != null) {
          await _notificationService.sendNotificationToUser(
            userId: request.assignedDriverId!,
            title: 'Collection Request Cancelled',
            body:
                'A special garbage collection request you were assigned has been deleted',
            channelKey: NotificationService.specialGarbageChannelKey,
            type: 'special_garbage_deleted',
            referenceId: null, // No reference since it's deleted
          );
        }
      }

      return true;
    } catch (e) {
      print('Error deleting special garbage request: $e');
      return false;
    }
  }

  // Listen to real-time updates for a specific request
  Stream<SpecialGarbageRequestModel?> getRequestStream(String requestId) {
    return _firestore.collection(_collection).doc(requestId).snapshots().map((
      snapshot,
    ) {
      if (snapshot.exists) {
        return SpecialGarbageRequestModel.fromMap(
          snapshot.data() as Map<String, dynamic>,
        );
      }
      return null;
    });
  }

  // Listen to real-time updates for a resident's requests
  Stream<List<SpecialGarbageRequestModel>> getResidentRequestsStream(
    String residentId,
  ) {
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
  Stream<List<SpecialGarbageRequestModel>> getDriverRequestsStream(
    String driverId,
  ) {
    return _firestore
        .collection(_collection)
        .where('assignedDriverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'assigned') // Only assigned, not collected
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return SpecialGarbageRequestModel.fromMap(doc.data());
          }).toList();
        });
  }

  // Get requests by status
  Future<List<SpecialGarbageRequestModel>> getRequestsByStatus(
    String status,
  ) async {
    try {
      QuerySnapshot snapshot =
          await _firestore
              .collection(_collection)
              .where('status', isEqualTo: status)
              .orderBy('requestedTime', descending: true)
              .get();

      return snapshot.docs.map((doc) {
        return SpecialGarbageRequestModel.fromMap(
          doc.data() as Map<String, dynamic>,
        );
      }).toList();
    } catch (e) {
      print('Error getting special garbage requests by status: $e');
      return [];
    }
  }

  // Cancel a request (for residents or admins)
  Future<bool> cancelRequest(
    String requestId, {
    required String cancelledBy,
    String? reason,
  }) async {
    try {
      await _firestore.collection(_collection).doc(requestId).update({
        'status': 'cancelled',
        'cancelledTime': DateTime.now().toIso8601String(),
        'cancelledBy': cancelledBy,
        if (reason != null) 'cancellationReason': reason,
      });

      // Get request details for notifications
      SpecialGarbageRequestModel? request = await getRequestById(requestId);
      if (request != null) {
        // If cancelled by admin and not the resident themselves
        if (cancelledBy != request.residentId) {
          await _notificationService.sendNotificationToUser(
            userId: request.residentId,
            title: 'Request Cancelled',
            body:
                'Your special garbage collection request has been cancelled${reason != null ? ': $reason' : ''}',
            channelKey: NotificationService.specialGarbageChannelKey,
            type: 'special_garbage_cancelled',
            referenceId: requestId,
          );
        }

        // If a driver was assigned, notify them
        if (request.assignedDriverId != null) {
          await _notificationService.sendNotificationToUser(
            userId: request.assignedDriverId!,
            title: 'Collection Cancelled',
            body:
                'A special garbage collection you were assigned has been cancelled${reason != null ? ': $reason' : ''}',
            channelKey: NotificationService.specialGarbageChannelKey,
            type: 'special_garbage_cancelled',
            referenceId: requestId,
          );
        }

        // Notify admins if cancelled by resident
        if (cancelledBy == request.residentId) {
          await _notificationService.sendSpecialGarbageNotification(
            title: 'Request Cancelled by Resident',
            body:
                'A resident has cancelled their special garbage collection request${reason != null ? ': $reason' : ''}',
            type: 'special_garbage_cancelled_by_resident',
            roles: ['cityManagement'],
            requestId: requestId,
          );
        }
      }

      return true;
    } catch (e) {
      print('Error cancelling special garbage request: $e');
      return false;
    }
  }
}
