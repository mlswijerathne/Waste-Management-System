// CleanlinessIssueModel - Represents a cleanliness issue report in the system
// This model contains all the necessary fields for tracking and managing cleanliness issues

import 'package:cloud_firestore/cloud_firestore.dart';

class CleanlinessIssueModel {
  String id; // Unique identifier for the issue
  String reporterId; // UID of the user who reported the issue
  String location; // Location description of the issue
  String description; // Detailed description of the issue
  String? imageUrl; // URL of the uploaded image (optional)
  DateTime reportedAt; // When the issue was reported
  String status; // Current status of the issue (pending, in-progress, resolved)
  String? assignedTo; // UID of driver/worker assigned to resolve the issue (if any)
  String? resolvedBy; // UID of user who resolved the issue (if any)
  DateTime? resolvedAt; // When the issue was resolved (if applicable)
  List<String>? comments; // List of comments on this issue

  // Constructor
  CleanlinessIssueModel({
    required this.id,
    required this.reporterId,
    required this.location,
    required this.description,
    this.imageUrl,
    required this.reportedAt,
    required this.status,
    this.assignedTo,
    this.resolvedBy,
    this.resolvedAt,
    this.comments,
  });

  // Factory constructor to create a CleanlinessIssueModel from a Map
  factory CleanlinessIssueModel.fromMap(Map<String, dynamic> map) {
    return CleanlinessIssueModel(
      id: map['id'],
      reporterId: map['reporterId'],
      location: map['location'],
      description: map['description'],
      imageUrl: map['imageUrl'],
      reportedAt: (map['reportedAt'] as Timestamp).toDate(),
      status: map['status'],
      assignedTo: map['assignedTo'],
      resolvedBy: map['resolvedBy'],
      resolvedAt: map['resolvedAt'] != null
          ? (map['resolvedAt'] as Timestamp).toDate()
          : null,
      comments: map['comments'] != null
          ? List<String>.from(map['comments'])
          : null,
    );
  }

  // Convert CleanlinessIssueModel to a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reporterId': reporterId,
      'location': location,
      'description': description,
      'imageUrl': imageUrl,
      'reportedAt': Timestamp.fromDate(reportedAt),
      'status': status,
      'assignedTo': assignedTo,
      'resolvedBy': resolvedBy,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'comments': comments,
    };
  }
}