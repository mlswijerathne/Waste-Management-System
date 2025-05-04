import 'dart:convert';

class SpecialGarbageRequestModel {
  final String id;
  final String residentId;
  final String residentName;
  final String description;
  final String garbageType;
  final String location;
  final double latitude;
  final double longitude;
  final String? imageUrl;
  final DateTime requestedTime;
  final String status; // pending, assigned, collected, completed
  final String? assignedDriverId;
  final String? assignedDriverName;
  final DateTime? assignedTime;
  final DateTime? collectedTime;
  final double? estimatedWeight;
  final String? notes;
  final bool? residentConfirmed;
  final String? residentFeedback;
  final double? rating; // Added rating field

  SpecialGarbageRequestModel({
    required this.id,
    required this.residentId,
    required this.residentName,
    required this.description,
    required this.garbageType,
    required this.location,
    required this.latitude,
    required this.longitude,
    this.imageUrl,
    required this.requestedTime,
    required this.status,
    this.assignedDriverId,
    this.assignedDriverName,
    this.assignedTime,
    this.collectedTime,
    this.estimatedWeight,
    this.notes,
    this.residentConfirmed,
    this.residentFeedback,
    this.rating, // Initialize rating field
  });

  factory SpecialGarbageRequestModel.fromMap(Map<String, dynamic> map) {
    return SpecialGarbageRequestModel(
      id: map['id'] ?? '',
      residentId: map['residentId'] ?? '',
      residentName: map['residentName'] ?? '',
      description: map['description'] ?? '',
      garbageType: map['garbageType'] ?? '',
      location: map['location'] ?? '',
      latitude: map['latitude'] ?? 0.0,
      longitude: map['longitude'] ?? 0.0,
      imageUrl: map['imageUrl'],
      requestedTime: map['requestedTime'] != null
          ? map['requestedTime'] is DateTime
              ? map['requestedTime']
              : DateTime.parse(map['requestedTime'])
          : DateTime.now(),
      status: map['status'] ?? 'pending',
      assignedDriverId: map['assignedDriverId'],
      assignedDriverName: map['assignedDriverName'],
      assignedTime: map['assignedTime'] != null
          ? map['assignedTime'] is DateTime
              ? map['assignedTime']
              : DateTime.parse(map['assignedTime'])
          : null,
      collectedTime: map['collectedTime'] != null
          ? map['collectedTime'] is DateTime
              ? map['collectedTime']
              : DateTime.parse(map['collectedTime'])
          : null,
      estimatedWeight: map['estimatedWeight']?.toDouble(),
      notes: map['notes'],
      residentConfirmed: map['residentConfirmed'],
      residentFeedback: map['residentFeedback'],
      rating: map['rating']?.toDouble(), // Parse rating field
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'residentId': residentId,
      'residentName': residentName,
      'description': description,
      'garbageType': garbageType,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrl': imageUrl,
      'requestedTime': requestedTime.toIso8601String(),
      'status': status,
      'assignedDriverId': assignedDriverId,
      'assignedDriverName': assignedDriverName,
      'assignedTime': assignedTime?.toIso8601String(),
      'collectedTime': collectedTime?.toIso8601String(),
      'estimatedWeight': estimatedWeight,
      'notes': notes,
      'residentConfirmed': residentConfirmed,
      'residentFeedback': residentFeedback,
      'rating': rating, // Include rating in the map
    };
  }

  @override
  String toString() {
    return 'SpecialGarbageRequestModel{id: $id, status: $status, garbageType: $garbageType, location: $location}';
  }
}