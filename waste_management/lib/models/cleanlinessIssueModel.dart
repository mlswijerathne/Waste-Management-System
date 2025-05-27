/// Model class representing a cleanliness issue reported by residents
/// This class handles the complete lifecycle of a cleanliness issue from reporting to resolution
class CleanlinessIssueModel {
  /// Unique identifier for the cleanliness issue
  final String id;
  
  /// ID of the resident who reported the issue
  final String residentId;
  
  /// Full name of the resident who reported the issue
  final String residentName;
  
  /// Detailed description of the cleanliness issue
  final String description;
  
  /// Human-readable location/address where the issue was reported
  final String location;
  
  /// GPS latitude coordinate of the issue location (-90 to 90)
  final double latitude;
  
  /// GPS longitude coordinate of the issue location (-180 to 180)
  final double longitude;
  
  /// URL path to the image showing the cleanliness issue
  final String imageUrl;
  
  /// Timestamp when the issue was first reported
  final DateTime reportedTime;
  
  /// Current status of the issue workflow
  /// Valid values: 'pending', 'assigned', 'inProgress', 'resolved'
  final String status;
  
  /// ID of the driver assigned to handle this issue (nullable until assigned)
  final String? assignedDriverId;
  
  /// Full name of the assigned driver (nullable until assigned)
  final String? assignedDriverName;
  
  /// Timestamp when the issue was assigned to a driver (nullable until assigned)
  final DateTime? assignedTime;
  
  /// Timestamp when the issue was marked as resolved (nullable until resolved)
  final DateTime? resolvedTime;
  
  /// Whether the resident has confirmed the issue resolution (nullable until feedback given)
  final bool? residentConfirmed;
  
  /// Optional feedback text provided by the resident after resolution
  final String? residentFeedback;

  /// Constructor with validation for critical fields
  /// Throws ArgumentError if status or coordinates are invalid
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
    // Validate status against allowed workflow states
    if (!['pending', 'assigned', 'inProgress', 'resolved'].contains(status)) {
      throw ArgumentError(
        'Status must be pending, assigned, inProgress, or resolved',
      );
    }

    // Validate GPS coordinates are within valid ranges
    if (latitude < -90 || latitude > 90) {
      throw ArgumentError('Latitude must be between -90 and 90');
    }
    if (longitude < -180 || longitude > 180) {
      throw ArgumentError('Longitude must be between -180 and 180');
    }
  }

  /// Factory constructor to create CleanlinessIssueModel from Map data
  /// Handles type conversion and provides safe defaults for missing values
  /// Supports both DateTime objects and ISO8601 strings for date fields
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
      // Handle both DateTime objects and ISO8601 strings, default to current time
      reportedTime:
          map['reportedTime'] != null
              ? (map['reportedTime'] is DateTime
                  ? map['reportedTime']
                  : DateTime.parse(map['reportedTime']))
              : DateTime.now(),
      status: map['status'] ?? 'pending',
      assignedDriverId: map['assignedDriverId'],
      assignedDriverName: map['assignedDriverName'],
      // Parse assignedTime if present, supporting both DateTime and string formats
      assignedTime:
          map['assignedTime'] != null
              ? (map['assignedTime'] is DateTime
                  ? map['assignedTime']
                  : DateTime.parse(map['assignedTime']))
              : null,
      // Parse resolvedTime if present, supporting both DateTime and string formats
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

  /// Convert the model instance to a Map for serialization
  /// DateTime objects are converted to ISO8601 strings for storage/transmission
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

  /// Create a new instance with selected fields updated
  /// Useful for updating issue status, assignment, or resolution details
  /// Returns a new CleanlinessIssueModel instance with specified changes
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