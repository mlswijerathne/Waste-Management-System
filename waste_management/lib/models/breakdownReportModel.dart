class BreakdownReport {
  final String id;
  final String userId; // Link to UserModel
  final BreakdownIssueType issueType;
  final String description;
  final BreakdownDelay delay;
  final BreakdownStatus status;
  final DateTime createdAt;
  final String? vehicleId;
  final String? location;

  BreakdownReport({
    required this.id,
    required this.userId,
    required this.issueType,
    required this.description,
    required this.delay,
    this.status = BreakdownStatus.pending,
    DateTime? createdAt,
    this.vehicleId,
    this.location,
  }) : createdAt = createdAt ?? DateTime.now();

  factory BreakdownReport.fromMap(Map<String, dynamic> map) {
    return BreakdownReport(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      issueType: _parseIssueType(map['issueType'] ?? ''),
      description: map['description'] ?? '',
      delay: BreakdownDelay.fromMap(map['delay'] ?? {}),
      status: _parseStatus(map['status'] ?? ''),
      createdAt:
          map['createdAt'] is String
              ? DateTime.parse(map['createdAt'])
              : map['createdAt'] ?? DateTime.now(),
      vehicleId: map['vehicleId'],
      location: map['location'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'issueType': issueType.value,
      'description': description,
      'delay': delay.toMap(),
      'status': status.value,
      'createdAt': createdAt.toIso8601String(),
      'vehicleId': vehicleId,
      'location': location,
    };
  }

  // Helper methods for parsing
  static BreakdownIssueType _parseIssueType(String value) {
    return BreakdownIssueType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => BreakdownIssueType.other,
    );
  }

  static BreakdownStatus _parseStatus(String value) {
    return BreakdownStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => BreakdownStatus.pending,
    );
  }
}

// Detailed delay class with validation
class BreakdownDelay {
  final int hours;
  final int minutes;

  BreakdownDelay({this.hours = 0, this.minutes = 0}) {
    // Validate delay
    if (hours < 0 || minutes < 0 || minutes > 59) {
      throw ArgumentError(
        'Invalid delay. Hours must be non-negative, '
        'minutes must be between 0 and 59.',
      );
    }
  }

  factory BreakdownDelay.fromMap(Map<String, dynamic> map) {
    return BreakdownDelay(
      hours: map['hours'] ?? 0,
      minutes: map['minutes'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {'hours': hours, 'minutes': minutes};
  }

  Duration toDuration() => Duration(hours: hours, minutes: minutes);
}

// Enums with value property for serialization
enum BreakdownIssueType {
  breakIssue('break_issue'),
  engineFailure('engine_failure'),
  tirePuncture('tire_puncture'),
  runningOutOfFuel('running_out_of_fuel'),
  hydraulicLeak('hydraulic_leak'),
  compressorJam('compressor_jam'),
  other('other');

  final String value;
  const BreakdownIssueType(this.value);
}

enum BreakdownStatus {
  pending('pending'),
  inProgress('in_progress'),
  resolved('resolved'),
  cancelled('cancelled');

  final String value;
  const BreakdownStatus(this.value);
}
