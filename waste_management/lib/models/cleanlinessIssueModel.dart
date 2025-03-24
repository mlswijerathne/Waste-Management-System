class CleanlinessIssueModel {
  final String id;
  final String residentId;
  final String residentName;
  final String description;
  final String location;
  final double latitude;
  final double longitude;
  final String imageUrl;
  final DateTime reportedTime;
  final String status; // 'pending', 'assigned', 'inProgress', 'resolved'
  final String? assignedDriverId;
  final String? assignedDriverName;
  final DateTime? assignedTime;
  final DateTime? resolvedTime;
  final bool? residentConfirmed;
  final String? residentFeedback;

  CleanlinessIssueModel({
    required this.id,
    required this.residentId,
    required this.residentName,
    required this.description,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.imageUrl,
    required this.reportedTime,
    required this.status,
    this.assignedDriverId,
    this.assignedDriverName,
    this.assignedTime,
    this.resolvedTime,
    this.residentConfirmed,
    this.residentFeedback,
  }) {
    // Validate status
    if (!['pending', 'assigned', 'inProgress', 'resolved'].contains(status)) {
      throw ArgumentError(
        'Status must be pending, assigned, inProgress, or resolved',
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

  factory CleanlinessIssueModel.fromMap(Map<String, dynamic> map) {
    return CleanlinessIssueModel(
      id: map['id'] ?? '',
      residentId: map['residentId'] ?? '',
      residentName: map['residentName'] ?? '',
      description: map['description'] ?? '',
      location: map['location'] ?? '',
      latitude: map['latitude'] ?? 0.0,
      longitude: map['longitude'] ?? 0.0,
      imageUrl: map['imageUrl'] ?? '',
      reportedTime:
          map['reportedTime'] != null
              ? (map['reportedTime'] is DateTime
                  ? map['reportedTime']
                  : DateTime.parse(map['reportedTime']))
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
      resolvedTime:
          map['resolvedTime'] != null
              ? (map['resolvedTime'] is DateTime
                  ? map['resolvedTime']
                  : DateTime.parse(map['resolvedTime']))
              : null,
      residentConfirmed: map['residentConfirmed'],
      residentFeedback: map['residentFeedback'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'residentId': residentId,
      'residentName': residentName,
      'description': description,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrl': imageUrl,
      'reportedTime': reportedTime.toIso8601String(),
      'status': status,
      'assignedDriverId': assignedDriverId,
      'assignedDriverName': assignedDriverName,
      'assignedTime': assignedTime?.toIso8601String(),
      'resolvedTime': resolvedTime?.toIso8601String(),
      'residentConfirmed': residentConfirmed,
      'residentFeedback': residentFeedback,
    };
  }

  // Create a copy of the issue with updated fields
  CleanlinessIssueModel copyWith({
    String? id,
    String? residentId,
    String? residentName,
    String? description,
    String? location,
    double? latitude,
    double? longitude,
    String? imageUrl,
    DateTime? reportedTime,
    String? status,
    String? assignedDriverId,
    String? assignedDriverName,
    DateTime? assignedTime,
    DateTime? resolvedTime,
    bool? residentConfirmed,
    String? residentFeedback,
  }) {
    return CleanlinessIssueModel(
      id: id ?? this.id,
      residentId: residentId ?? this.residentId,
      residentName: residentName ?? this.residentName,
      description: description ?? this.description,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      imageUrl: imageUrl ?? this.imageUrl,
      reportedTime: reportedTime ?? this.reportedTime,
      status: status ?? this.status,
      assignedDriverId: assignedDriverId ?? this.assignedDriverId,
      assignedDriverName: assignedDriverName ?? this.assignedDriverName,
      assignedTime: assignedTime ?? this.assignedTime,
      resolvedTime: resolvedTime ?? this.resolvedTime,
      residentConfirmed: residentConfirmed ?? this.residentConfirmed,
      residentFeedback: residentFeedback ?? this.residentFeedback,
    );
  }
}
