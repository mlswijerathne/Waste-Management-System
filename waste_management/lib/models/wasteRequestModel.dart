import 'package:cloud_firestore/cloud_firestore.dart';

class SpecialGarbageRequest {
  final String id;
  final String userId;
  final String userName;
  final String reason;
  final String description;
  final GeoPoint location;
  final String status; // 'pending', 'assigned', 'completed', 'cancelled'
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? assignedDriverId;
  final String? driverName;
  final String? imageUrl;

  SpecialGarbageRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.reason,
    required this.description,
    required this.location,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.assignedDriverId,
    this.driverName,
    this.imageUrl,
  });

  factory SpecialGarbageRequest.fromMap(Map<String, dynamic> map, String id) {
    return SpecialGarbageRequest(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      reason: map['reason'] ?? '',
      description: map['description'] ?? '',
      location: map['location'] ?? GeoPoint(0, 0),
      status: map['status'] ?? 'pending',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null ? (map['updatedAt'] as Timestamp).toDate() : null,
      assignedDriverId: map['assignedDriverId'],
      driverName: map['driverName'],
      imageUrl: map['imageUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'reason': reason,
      'description': description,
      'location': location,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'assignedDriverId': assignedDriverId,
      'driverName': driverName, 
      'imageUrl': imageUrl,
    };
  }

  SpecialGarbageRequest copyWith({
    String? id,
    String? userId,
    String? userName,
    String? reason,
    String? description,
    GeoPoint? location,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? assignedDriverId,
    String? driverName,
    String? imageUrl,
  }) {
    return SpecialGarbageRequest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      reason: reason ?? this.reason,
      description: description ?? this.description,
      location: location ?? this.location,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      assignedDriverId: assignedDriverId ?? this.assignedDriverId,
      driverName: driverName ?? this.driverName,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

// Define GeoPoint class if not already imported from Firebase
class GeoPoint {
  final double latitude;
  final double longitude;

  GeoPoint(this.latitude, this.longitude);
}