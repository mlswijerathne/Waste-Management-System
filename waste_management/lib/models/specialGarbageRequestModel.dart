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
      requestedTime:
          map['requestedTime'] != null
              ? (map['requestedTime'] is DateTime
                  ? map['requestedTime']
                  : DateTime.parse(map['requestedTime']))
              : DateTime.now(),
      status: map['status'] ?? 'pending',
      assignedDriverId: map['assignedDriverId'],
      assignedDriverName: map['assignedDriverName'],
      assignedTime:
          map['assignedTime'] != null
              ? (map['assignedTime'] is DateTime
                  ? map['assignedTime']
                  : DateTime.parse(map['assignedTime']))
              : null,
      collectedTime:
          map['collectedTime'] != null
              ? (map['collectedTime'] is DateTime
                  ? map['collectedTime']
                  : DateTime.parse(map['collectedTime']))
              : null,
      residentConfirmed: map['residentConfirmed'],
      residentFeedback: map['residentFeedback'],
      estimatedWeight: map['estimatedWeight'],
      notes: map['notes'],
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
}