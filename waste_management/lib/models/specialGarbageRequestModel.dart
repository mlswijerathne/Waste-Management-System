class SpecialGarbageRequestModel {
  final String id;
  final String residentId;
  final String residentName;
  final String description;
  final String garbageType; // Type of garbage for special collection
  final String location;
  final double latitude;
  final double longitude;
  final String? imageUrl;
  final DateTime requestedTime;
  final String status; // 'pending', 'assigned', 'collected', 'completed'
  final String? assignedDriverId;
  final String? assignedDriverName;
  final DateTime? assignedTime;
  final DateTime? collectedTime;
  final bool? residentConfirmed;
  final String? residentFeedback;
  final double? estimatedWeight;
  final String? notes;

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
    this.residentConfirmed,
    this.residentFeedback,
    this.estimatedWeight,
    this.notes,
  }) {
    // Validate status
    if (!['pending', 'assigned', 'collected', 'completed'].contains(status)) {
      throw ArgumentError(
        'Status must be pending, assigned, collected, or completed',
      );
    }

    // Validate coordinates
    if (latitude < -90 || latitude > 90) {
      throw ArgumentError('Latitude must be between -90 and 90');
    }
    if (longitude < -180 || longitude > 180) {
      throw ArgumentError('Longitude must be between -180 and 180');
    }
  }

  factory SpecialGarbageRequestModel.fromMap(Map<String, dynamic> map) {
    // Safely parse latitude and longitude values with proper null handling
    double? latitude;
    try {
      latitude =
          map['latitude'] != null ? (map['latitude'] as num).toDouble() : 0.0;
    } catch (e) {
      latitude = 0.0;
    }

    double? longitude;
    try {
      longitude =
          map['longitude'] != null ? (map['longitude'] as num).toDouble() : 0.0;
    } catch (e) {
      longitude = 0.0;
    }

    // Safely parse DateTime objects with try-catch
    DateTime? requestedTime;
    try {
      requestedTime =
          map['requestedTime'] != null
              ? (map['requestedTime'] is DateTime
                  ? map['requestedTime']
                  : DateTime.parse(map['requestedTime'].toString()))
              : DateTime.now();
    } catch (e) {
      requestedTime = DateTime.now();
    }

    DateTime? assignedTime;
    try {
      assignedTime =
          map['assignedTime'] != null
              ? (map['assignedTime'] is DateTime
                  ? map['assignedTime']
                  : DateTime.parse(map['assignedTime'].toString()))
              : null;
    } catch (e) {
      assignedTime = null;
    }

    DateTime? collectedTime;
    try {
      collectedTime =
          map['collectedTime'] != null
              ? (map['collectedTime'] is DateTime
                  ? map['collectedTime']
                  : DateTime.parse(map['collectedTime'].toString()))
              : null;
    } catch (e) {
      collectedTime = null;
    }

    return SpecialGarbageRequestModel(
      id: map['id']?.toString() ?? '',
      residentId: map['residentId']?.toString() ?? '',
      residentName: map['residentName']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      garbageType: map['garbageType']?.toString() ?? '',
      location: map['location']?.toString() ?? '',
      latitude: latitude,
      longitude: longitude,
      imageUrl: map['imageUrl']?.toString(),
      requestedTime: requestedTime ?? DateTime.now(),
      status: map['status']?.toString() ?? 'pending',
      assignedDriverId: map['assignedDriverId']?.toString(),
      assignedDriverName: map['assignedDriverName']?.toString(),
      assignedTime: assignedTime,
      collectedTime: collectedTime,
      residentConfirmed: map['residentConfirmed'] as bool?,
      residentFeedback: map['residentFeedback']?.toString(),
      estimatedWeight:
          map['estimatedWeight'] != null
              ? (map['estimatedWeight'] as num).toDouble()
              : null,
      notes: map['notes']?.toString(),
    );
  }

  // Create a copy of the request with updated fields
  SpecialGarbageRequestModel copyWith({
    String? id,
    String? residentId,
    String? residentName,
    String? description,
    String? garbageType,
    String? location,
    double? latitude,
    double? longitude,
    String? imageUrl,
    DateTime? requestedTime,
    String? status,
    String? assignedDriverId,
    String? assignedDriverName,
    DateTime? assignedTime,
    DateTime? collectedTime,
    bool? residentConfirmed,
    String? residentFeedback,
    double? estimatedWeight,
    String? notes,
  }) {
    return SpecialGarbageRequestModel(
      id: id ?? this.id,
      residentId: residentId ?? this.residentId,
      residentName: residentName ?? this.residentName,
      description: description ?? this.description,
      garbageType: garbageType ?? this.garbageType,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      imageUrl: imageUrl ?? this.imageUrl,
      requestedTime: requestedTime ?? this.requestedTime,
      status: status ?? this.status,
      assignedDriverId: assignedDriverId ?? this.assignedDriverId,
      assignedDriverName: assignedDriverName ?? this.assignedDriverName,
      assignedTime: assignedTime ?? this.assignedTime,
      collectedTime: collectedTime ?? this.collectedTime,
      residentConfirmed: residentConfirmed ?? this.residentConfirmed,
      residentFeedback: residentFeedback ?? this.residentFeedback,
      estimatedWeight: estimatedWeight ?? this.estimatedWeight,
      notes: notes ?? this.notes,
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
      'residentConfirmed': residentConfirmed,
      'residentFeedback': residentFeedback,
      'estimatedWeight': estimatedWeight,
      'notes': notes,
    };
  }
}
