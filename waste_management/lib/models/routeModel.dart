class RouteModel {
  final String id;
  final String name;
  final String description;
  final double startLat;
  final double startLng;
  final double endLat;
  final double endLng;
  final double distance;
  final List<Map<String, double>> coveragePoints;
  final List<Map<String, double>> actualDirectionPath; // Added for actual Google directions path
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? pausedAt; // Added for pause functionality
  final DateTime? resumedAt; // Added to track resume time
  final DateTime? completedAt;
  final DateTime? cancelledAt; // Added for cancel functionality
  final bool isActive;
  final bool isPaused; // Added to track pause state
  final bool isCancelled; // Added to track cancel state
  final String? createdBy;
  final String? assignedDriverId;
  final String? driverName; // Added for displaying driver details
  final String? driverContact; // Added for displaying driver details
  final String? truckId; // Added for truck identification
  final double? currentProgressPercentage; // Added to track completion percentage

  RouteModel({
    required this.id,
    required this.name,
    this.description = '',
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
    this.distance = 0.0,
    required this.coveragePoints,
    this.actualDirectionPath = const [],
    required this.createdAt,
    this.startedAt,
    this.pausedAt,
    this.resumedAt,
    this.completedAt,
    this.cancelledAt,
    this.isActive = false,
    this.isPaused = false,
    this.isCancelled = false,
    this.createdBy,
    this.assignedDriverId,
    this.driverName,
    this.driverContact,
    this.truckId,
    this.currentProgressPercentage,
  });

  // Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'startLat': startLat,
      'startLng': startLng,
      'endLat': endLat,
      'endLng': endLng,
      'distance': distance,
      'coveragePoints': coveragePoints,
      'actualDirectionPath': actualDirectionPath,
      'createdAt': createdAt,
      'startedAt': startedAt,
      'pausedAt': pausedAt,
      'resumedAt': resumedAt,
      'completedAt': completedAt,
      'cancelledAt': cancelledAt,
      'isActive': isActive,
      'isPaused': isPaused,
      'isCancelled': isCancelled,
      'createdBy': createdBy,
      'assignedDriverId': assignedDriverId,
      'driverName': driverName,
      'driverContact': driverContact,
      'truckId': truckId,
      'currentProgressPercentage': currentProgressPercentage,
    };
  }

  // Create from Firestore document
  factory RouteModel.fromMap(Map<String, dynamic> map) {
    // Handle the coveragePoints conversion safely
    List<Map<String, double>> convertedCoveragePoints = [];
    List<Map<String, double>> convertedDirectionPath = [];
    
    if (map['coveragePoints'] != null) {
      final points = map['coveragePoints'] as List<dynamic>;
      
      convertedCoveragePoints = points.map<Map<String, double>>((point) {
        // Make sure we're creating a Map<String, double> with explicit conversion
        return {
          'lat': (point['lat'] is num) ? (point['lat'] as num).toDouble() : 0.0,
          'lng': (point['lng'] is num) ? (point['lng'] as num).toDouble() : 0.0,
        };
      }).toList();
    }
    
    if (map['actualDirectionPath'] != null) {
      final points = map['actualDirectionPath'] as List<dynamic>;
      
      convertedDirectionPath = points.map<Map<String, double>>((point) {
        return {
          'lat': (point['lat'] is num) ? (point['lat'] as num).toDouble() : 0.0,
          'lng': (point['lng'] is num) ? (point['lng'] as num).toDouble() : 0.0,
        };
      }).toList();
    }
    
    return RouteModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      startLat: map['startLat']?.toDouble() ?? 0.0,
      startLng: map['startLng']?.toDouble() ?? 0.0,
      endLat: map['endLat']?.toDouble() ?? 0.0,
      endLng: map['endLng']?.toDouble() ?? 0.0,
      distance: map['distance']?.toDouble() ?? 0.0,
      coveragePoints: convertedCoveragePoints,
      actualDirectionPath: convertedDirectionPath,
      createdAt: (map['createdAt'] as DateTime?) ?? DateTime.now(),
      startedAt: map['startedAt'] as DateTime?,
      pausedAt: map['pausedAt'] as DateTime?,
      resumedAt: map['resumedAt'] as DateTime?,
      completedAt: map['completedAt'] as DateTime?,
      cancelledAt: map['cancelledAt'] as DateTime?,
      isActive: map['isActive'] ?? false,
      isPaused: map['isPaused'] ?? false,
      isCancelled: map['isCancelled'] ?? false,
      createdBy: map['createdBy'],
      assignedDriverId: map['assignedDriverId'],
      driverName: map['driverName'],
      driverContact: map['driverContact'],
      truckId: map['truckId'],
      currentProgressPercentage: map['currentProgressPercentage']?.toDouble(),
    );
  }
  
  // Create a copy with updated fields
  RouteModel copyWith({
    String? id,
    String? name,
    String? description,
    double? startLat,
    double? startLng,
    double? endLat,
    double? endLng,
    double? distance,
    List<Map<String, double>>? coveragePoints,
    List<Map<String, double>>? actualDirectionPath,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? pausedAt,
    DateTime? resumedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    bool? isActive,
    bool? isPaused,
    bool? isCancelled,
    String? createdBy,
    String? assignedDriverId,
    String? driverName,
    String? driverContact,
    String? truckId,
    double? currentProgressPercentage,
  }) {
    return RouteModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      startLat: startLat ?? this.startLat,
      startLng: startLng ?? this.startLng,
      endLat: endLat ?? this.endLat,
      endLng: endLng ?? this.endLng,
      distance: distance ?? this.distance,
      coveragePoints: coveragePoints ?? this.coveragePoints,
      actualDirectionPath: actualDirectionPath ?? this.actualDirectionPath,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      pausedAt: pausedAt ?? this.pausedAt,
      resumedAt: resumedAt ?? this.resumedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      isActive: isActive ?? this.isActive,
      isPaused: isPaused ?? this.isPaused,
      isCancelled: isCancelled ?? this.isCancelled,
      createdBy: createdBy ?? this.createdBy,
      assignedDriverId: assignedDriverId ?? this.assignedDriverId,
      driverName: driverName ?? this.driverName,
      driverContact: driverContact ?? this.driverContact,
      truckId: truckId ?? this.truckId,
      currentProgressPercentage: currentProgressPercentage ?? this.currentProgressPercentage,
    );
  }
}