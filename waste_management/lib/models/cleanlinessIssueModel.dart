/**
 * Core data model for tracking cleanliness issues throughout their complete lifecycle
 * Manages the workflow from initial resident reporting through driver assignment to final resolution
 * Supports geolocation tracking, status management, and resident feedback collection
 */
class CleanlinessIssueModel {
  final String id; // Primary key - UUID for database persistence and API references
  final String residentId; // Foreign key linking to the reporting user's account
  final String residentName; // Cached display name for UI without additional lookups
  final String description; // User-provided issue details for driver context
  final String location; // Street address or landmark description for human readability
  final double latitude; // WGS84 coordinate for precise mapping and navigation
  final double longitude; // WGS84 coordinate for precise mapping and navigation  
  final String imageUrl; // Cloud storage path for visual evidence of the issue
  final DateTime reportedTime; // System timestamp for SLA tracking and reporting
  
  // Workflow state management - drives UI behavior and business logic
  final String status; // State machine: pending → assigned → inProgress → resolved
  
  // Assignment tracking - populated when issue is delegated to cleanup crew
  final String? assignedDriverId; // Foreign key to driver account (null during pending state)
  final String? assignedDriverName; // Cached driver name for notification display
  final DateTime? assignedTime; // SLA start time for performance metrics
  
  // Resolution tracking - populated when work is completed
  final DateTime? resolvedTime; // Completion timestamp for SLA calculations
  final bool? residentConfirmed; // Quality assurance - resident verification of cleanup
  final String? residentFeedback; // Post-resolution comments for service improvement

  /**
   * Primary constructor with built-in data validation
   * Enforces business rules for status workflow and GPS coordinate boundaries
   * @throws ArgumentError for invalid status values or out-of-range coordinates
   */
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
    // Business rule enforcement: validate against defined workflow states
    if (!['pending', 'assigned', 'inProgress', 'resolved'].contains(status)) {
      throw ArgumentError(
        'Status must be pending, assigned, inProgress, or resolved',
      );
    }

    // Geospatial validation: ensure coordinates fall within Earth's valid ranges
    if (latitude < -90 || latitude > 90) { // Latitude bounds: South Pole to North Pole
      throw ArgumentError('Latitude must be between -90 and 90');
    }
    if (longitude < -180 || longitude > 180) { // Longitude bounds: International Date Line wrap
      throw ArgumentError('Longitude must be between -180 and 180');
    }
  }

  /**
   * Deserialization factory for creating instances from external data sources
   * Handles polymorphic DateTime parsing (objects vs ISO8601 strings)
   * Provides defensive defaults to prevent null pointer exceptions
   * Essential for API responses, database queries, and local storage retrieval
   */
  factory CleanlinessIssueModel.fromMap(Map<String, dynamic> map) {
    return CleanlinessIssueModel(
      id: map['id'] ?? '', // Fallback for missing primary keys
      residentId: map['residentId'] ?? '', // Fallback for missing foreign keys
      residentName: map['residentName'] ?? '', // Fallback for missing display names
      description: map['description'] ?? '', // Fallback to empty description
      location: map['location'] ?? '', // Fallback to empty location
      latitude: map['latitude'] ?? 0.0, // Default to equator if missing
      longitude: map['longitude'] ?? 0.0, // Default to prime meridian if missing
      imageUrl: map['imageUrl'] ?? '', // Fallback to empty image path
      
      // Robust DateTime parsing with multiple format support
      reportedTime:
          map['reportedTime'] != null
              ? (map['reportedTime'] is DateTime
                  ? map['reportedTime'] // Direct DateTime object
                  : DateTime.parse(map['reportedTime'])) // Parse ISO8601 string
              : DateTime.now(), // Default to current time if missing
      status: map['status'] ?? 'pending', // Default to initial workflow state
      
      // Optional assignment fields - remain null until populated
      assignedDriverId: map['assignedDriverId'], // Null until driver assigned
      assignedDriverName: map['assignedDriverName'], // Null until driver assigned
      
      // Flexible DateTime parsing for assignment tracking
      assignedTime:
          map['assignedTime'] != null
              ? (map['assignedTime'] is DateTime
                  ? map['assignedTime'] // Direct DateTime object
                  : DateTime.parse(map['assignedTime'])) // Parse ISO8601 string
              : null, // Null until assignment occurs
      
      // Flexible DateTime parsing for resolution tracking
      resolvedTime:
          map['resolvedTime'] != null
              ? (map['resolvedTime'] is DateTime
                  ? map['resolvedTime'] // Direct DateTime object
                  : DateTime.parse(map['resolvedTime'])) // Parse ISO8601 string
              : null, // Null until resolution occurs
      
      // Optional feedback fields - remain null until resident provides input
      residentConfirmed: map['residentConfirmed'], // Null until resident confirms
      residentFeedback: map['residentFeedback'], // Null until resident provides feedback
    );
  }

  /**
   * Serialization method for data persistence and API transmission
   * Converts all DateTime objects to ISO8601 strings for JSON compatibility
   * Creates a flat Map structure suitable for database storage and HTTP requests
   */
  Map<String, dynamic> toMap() {
    return {
      'id': id, // Primary key for database operations
      'residentId': residentId, // Foreign key reference
      'residentName': residentName, // Cached display name
      'description': description, // Issue details for drivers
      'location': location, // Human-readable address
      'latitude': latitude, // GPS coordinate for mapping
      'longitude': longitude, // GPS coordinate for navigation
      'imageUrl': imageUrl, // Cloud storage reference
      'reportedTime': reportedTime.toIso8601String(), // Standardized timestamp format
      'status': status, // Current workflow state
      'assignedDriverId': assignedDriverId, // Driver assignment (may be null)
      'assignedDriverName': assignedDriverName, // Driver name cache (may be null)
      'assignedTime': assignedTime?.toIso8601String(), // Assignment timestamp (may be null)
      'resolvedTime': resolvedTime?.toIso8601String(), // Resolution timestamp (may be null)
      'residentConfirmed': residentConfirmed, // Quality confirmation (may be null)
      'residentFeedback': residentFeedback, // Post-resolution comments (may be null)
    };
  }

  /**
   * Immutable update pattern for state management
   * Creates new instances with selective field modifications while preserving immutability
   * Critical for Redux-style state management and preventing accidental mutations
   * Commonly used for status updates, assignment changes, and resolution recording
   */
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
      id: id ?? this.id, // Preserve existing ID unless explicitly changed
      residentId: residentId ?? this.residentId, // Preserve reporter identity
      residentName: residentName ?? this.residentName, // Preserve cached name
      description: description ?? this.description, // Preserve issue details
      location: location ?? this.location, // Preserve location data
      latitude: latitude ?? this.latitude, // Preserve GPS coordinates
      longitude: longitude ?? this.longitude, // Preserve GPS coordinates
      imageUrl: imageUrl ?? this.imageUrl, // Preserve image reference
      reportedTime: reportedTime ?? this.reportedTime, // Preserve original timestamp
      status: status ?? this.status, // Allow status progression updates
      assignedDriverId: assignedDriverId ?? this.assignedDriverId, // Allow driver assignment
      assignedDriverName: assignedDriverName ?? this.assignedDriverName, // Allow driver name update
      assignedTime: assignedTime ?? this.assignedTime, // Allow assignment timestamp
      resolvedTime: resolvedTime ?? this.resolvedTime, // Allow resolution timestamp
      residentConfirmed: residentConfirmed ?? this.residentConfirmed, // Allow confirmation update
      residentFeedback: residentFeedback ?? this.residentFeedback, // Allow feedback addition
    );
  }
}