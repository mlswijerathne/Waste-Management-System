import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final List<Map<String, double>> actualDirectionPath;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? pausedAt;
  final DateTime? resumedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final bool isActive;
  final bool isPaused;
  final bool isCancelled;
  final String? createdBy;
  final String? assignedDriverId;
  final String? driverName;
  final String? driverContact;
  final String? truckId;
  final double? currentProgressPercentage;
  final String scheduleFrequency;
  final List<int> scheduleDays;
  final TimeOfDay scheduleStartTime;
  final TimeOfDay scheduleEndTime;
  final String wasteCategory;
  final String scheduleId;
  final DateTime? nextScheduledStart;
  final DateTime? lastCompleted;

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
    this.scheduleFrequency = 'once',
    this.scheduleDays = const [],
    required this.scheduleStartTime,
    required this.scheduleEndTime,
    this.wasteCategory = 'mixed',
    this.scheduleId = '',
    this.nextScheduledStart,
    this.lastCompleted,
  });

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
      'scheduleFrequency': scheduleFrequency,
      'scheduleDays': scheduleDays,
      'scheduleStartTime': scheduleStartTime != null ? {'hour': scheduleStartTime.hour, 'minute': scheduleStartTime.minute} : null,
      'scheduleEndTime': scheduleEndTime != null ? {'hour': scheduleEndTime.hour, 'minute': scheduleEndTime.minute} : null,
      'wasteCategory': wasteCategory,
      'scheduleId': scheduleId,
      'nextScheduledStart': nextScheduledStart,
      'lastCompleted': lastCompleted,
    };
  }

  static DateTime? parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  factory RouteModel.fromMap(Map<String, dynamic> map) {
    List<Map<String, double>> convertedCoveragePoints = [];
    List<Map<String, double>> convertedDirectionPath = [];

    if (map['coveragePoints'] != null) {
      final points = map['coveragePoints'] as List<dynamic>;
      convertedCoveragePoints = points.map<Map<String, double>>((point) {
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

    TimeOfDay? startTime;
    if (map['scheduleStartTime'] != null) {
      startTime = TimeOfDay(
        hour: map['scheduleStartTime']['hour'] ?? 8,
        minute: map['scheduleStartTime']['minute'] ?? 0,
      );
    }

    TimeOfDay? endTime;
    if (map['scheduleEndTime'] != null) {
      endTime = TimeOfDay(
        hour: map['scheduleEndTime']['hour'] ?? 17,
        minute: map['scheduleEndTime']['minute'] ?? 0,
      );
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
      createdAt: parseDateTime(map['createdAt']) ?? DateTime.now(),
      startedAt: parseDateTime(map['startedAt']),
      pausedAt: parseDateTime(map['pausedAt']),
      resumedAt: parseDateTime(map['resumedAt']),
      completedAt: parseDateTime(map['completedAt']),
      cancelledAt: parseDateTime(map['cancelledAt']),
      isActive: map['isActive'] ?? false,
      isPaused: map['isPaused'] ?? false,
      isCancelled: map['isCancelled'] ?? false,
      createdBy: map['createdBy'],
      assignedDriverId: map['assignedDriverId'],
      driverName: map['driverName'],
      driverContact: map['driverContact'],
      truckId: map['truckId'],
      currentProgressPercentage: map['currentProgressPercentage']?.toDouble(),
      scheduleFrequency: map['scheduleFrequency'] ?? 'once',
      scheduleDays: map['scheduleDays'] != null ? List<int>.from(map['scheduleDays']) : [],
      scheduleStartTime: startTime ?? TimeOfDay(hour: 8, minute: 0),
      scheduleEndTime: endTime ?? TimeOfDay(hour: 17, minute: 0),
      wasteCategory: map['wasteCategory'] ?? 'mixed',
      scheduleId: map['scheduleId'] ?? '',
      nextScheduledStart: parseDateTime(map['nextScheduledStart']),
      lastCompleted: parseDateTime(map['lastCompleted']),
    );
  }

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
    String? scheduleFrequency,
    List<int>? scheduleDays,
    TimeOfDay? scheduleStartTime,
    TimeOfDay? scheduleEndTime,
    String? wasteCategory,
    String? scheduleId,
    DateTime? nextScheduledStart,
    DateTime? lastCompleted,
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
      scheduleFrequency: scheduleFrequency ?? this.scheduleFrequency,
      scheduleDays: scheduleDays ?? this.scheduleDays,
      scheduleStartTime: scheduleStartTime ?? this.scheduleStartTime,
      scheduleEndTime: scheduleEndTime ?? this.scheduleEndTime,
      wasteCategory: wasteCategory ?? this.wasteCategory,
      scheduleId: scheduleId ?? this.scheduleId,
      nextScheduledStart: nextScheduledStart ?? this.nextScheduledStart,
      lastCompleted: lastCompleted ?? this.lastCompleted,
    );
  }
}
