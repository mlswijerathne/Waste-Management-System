import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:waste_management/models/routeModel.dart';
import 'package:waste_management/service/auth_service.dart';
import 'package:waste_management/service/notification_service.dart';

class RouteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();

  // Google Maps Directions API key
  static const String _googleMapsApiKey =
      'AIzaSyD00mAQSg43OFLt36seV57ZupP-RLgXtGQ';

  Future<RouteModel> saveScheduledRoute(
    String name,
    String description,
    LatLng start,
    LatLng end, {
    String? assignedDriverId,
    String? driverName,
    String? driverContact,
    String? truckId,
    String scheduleFrequency = 'once',
    List<int> scheduleDays = const [],
    TimeOfDay? scheduleStartTime,
    TimeOfDay? scheduleEndTime,
    String wasteCategory = 'mixed',
  }) async {
    try {
      // Get current user ID for permission control
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Fetch route directions from Google Maps Directions API
      final directionsResponse = await _fetchRouteDirections(start, end);

      // Calculate total distance
      double totalDistance =
          directionsResponse['routes'][0]['legs'][0]['distance']['value'] /
          1000;

      // Extract route points and actual direction path
      List<Map<String, double>> coveragePoints = _extractRouteCoveragePoints(
        directionsResponse,
      );
      List<Map<String, double>> actualDirectionPath =
          _extractActualDirectionPath(directionsResponse);

      // Generate a schedule ID if this is a recurring route
      String scheduleId = '';
      if (scheduleFrequency != 'once') {
        scheduleId = 'schedule_${DateTime.now().millisecondsSinceEpoch}';
      }

      // Calculate next scheduled occurrence
      DateTime? nextScheduledStart = _calculateNextScheduledDate(
        scheduleFrequency,
        scheduleDays,
        scheduleStartTime,
      );

      // Create RouteModel
      final route = RouteModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        description: description,
        startLat: start.latitude,
        startLng: start.longitude,
        endLat: end.latitude,
        endLng: end.longitude,
        distance: totalDistance,
        coveragePoints: coveragePoints,
        actualDirectionPath: actualDirectionPath,
        createdAt: DateTime.now(),
        isActive: false,
        isPaused: false,
        isCancelled: false,
        createdBy: currentUser.uid,
        assignedDriverId: assignedDriverId,
        driverName: driverName,
        driverContact: driverContact,
        truckId: truckId,
        // New scheduling fields
        scheduleFrequency: scheduleFrequency,
        scheduleDays: scheduleDays,
        scheduleStartTime: scheduleStartTime ?? TimeOfDay(hour: 0, minute: 0),
        scheduleEndTime: scheduleEndTime ?? TimeOfDay(hour: 0, minute: 0),
        wasteCategory: wasteCategory,
        scheduleId: scheduleId,
        nextScheduledStart: nextScheduledStart,
      );

      // Save to Firestore
      await _firestore
          .collection('waste_routes')
          .doc(route.id)
          .set(route.toMap());

      // Initialize route progress data
      await _firestore.collection('route_progress').doc(route.id).set({
        'completionPercentage': 0.0,
        'totalEstimatedTimeMinutes': 0.0,
        'remainingTimeMinutes': 0.0,
      });

      // Send notifications
      if (assignedDriverId != null) {
        // Notify the assigned driver
        await _notificationService.sendNotificationToUser(
          userId: assignedDriverId,
          title: 'New Route Assigned',
          body: 'You have been assigned a new waste collection route: ${name}',
          channelKey: NotificationService.routeChannelKey,
          type: 'route_assigned',
          referenceId: route.id,
        );
      }

      // Notify admins about new route
      await _notificationService.sendRouteNotification(
        title: 'New Route Created',
        body: 'A new waste collection route has been created: ${name}',
        type: 'route_created',
        roles: ['cityManagement'],
        routeId: route.id,
      );

      return route;
    } catch (e) {
      print('Error saving scheduled route: $e');
      throw Exception('Failed to save scheduled route: $e');
    }
  }

  // Calculate the next scheduled date based on frequency and days
  DateTime? _calculateNextScheduledDate(
    String frequency,
    List<int> days,
    TimeOfDay? startTime,
  ) {
    if (frequency == 'once' || days.isEmpty || startTime == null) {
      return null;
    }

    final now = DateTime.now();
    final todayWeekday =
        now.weekday % 7; // Convert to 0-6 range where 0 is Sunday

    // Sort days to find the next available day
    final sortedDays = List<int>.from(days)..sort();

    DateTime nextDate;

    // Find the next valid day
    int daysToAdd = 0;
    bool foundDay = false;

    // Check if we have a day later this week
    for (final day in sortedDays) {
      if (day > todayWeekday ||
          (day == todayWeekday &&
              (startTime.hour > now.hour ||
                  (startTime.hour == now.hour &&
                      startTime.minute > now.minute)))) {
        daysToAdd = day - todayWeekday;
        foundDay = true;
        break;
      }
    }

    // If no day found later this week, go to next week
    if (!foundDay) {
      daysToAdd = 7 - todayWeekday + sortedDays.first;
    }

    // Calculate next date
    nextDate = DateTime(
      now.year,
      now.month,
      now.day + daysToAdd,
      startTime.hour,
      startTime.minute,
    );

    // Adjust for frequency
    if (frequency == 'biweekly' && nextDate.difference(now).inDays < 14) {
      nextDate = nextDate.add(Duration(days: 7));
    } else if (frequency == 'monthly') {
      // For monthly, set to next month with the same day
      if (nextDate.difference(now).inDays < 28) {
        int targetDay = nextDate.day;
        int targetMonth = nextDate.month + 1;
        int targetYear = nextDate.year;

        if (targetMonth > 12) {
          targetMonth = 1;
          targetYear++;
        }

        // Handle month length issues
        final daysInMonth = DateTime(targetYear, targetMonth + 1, 0).day;
        if (targetDay > daysInMonth) {
          targetDay = daysInMonth;
        }

        nextDate = DateTime(
          targetYear,
          targetMonth,
          targetDay,
          startTime.hour,
          startTime.minute,
        );
      }
    }

    return nextDate;
  }

  // Get driver's routes for specific day of week
  Future<List<RouteModel>> getDriverRoutesForDay(
    String driverId,
    int dayOfWeek,
  ) async {
    try {
      final snapshot =
          await _firestore
              .collection('waste_routes')
              .where('assignedDriverId', isEqualTo: driverId)
              .where('isCancelled', isEqualTo: false)
              .get();

      List<RouteModel> scheduledRoutes = [];

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data();

        // Convert timestamps
        data['createdAt'] =
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        data['startedAt'] = (data['startedAt'] as Timestamp?)?.toDate();
        data['pausedAt'] = (data['pausedAt'] as Timestamp?)?.toDate();
        data['resumedAt'] = (data['resumedAt'] as Timestamp?)?.toDate();
        data['completedAt'] = (data['completedAt'] as Timestamp?)?.toDate();
        data['cancelledAt'] = (data['cancelledAt'] as Timestamp?)?.toDate();
        data['nextScheduledStart'] =
            (data['nextScheduledStart'] as Timestamp?)?.toDate();
        data['lastCompleted'] = (data['lastCompleted'] as Timestamp?)?.toDate();

        // Convert schedule times
        if (data['scheduleStartTime'] != null) {
          data['scheduleStartTime'] = {
            'hour': data['scheduleStartTime']['hour'] ?? 8,
            'minute': data['scheduleStartTime']['minute'] ?? 0,
          };
        }

        if (data['scheduleEndTime'] != null) {
          data['scheduleEndTime'] = {
            'hour': data['scheduleEndTime']['hour'] ?? 17,
            'minute': data['scheduleEndTime']['minute'] ?? 0,
          };
        }

        // Convert points
        _convertPointsData(data, 'coveragePoints');
        _convertPointsData(data, 'actualDirectionPath');

        final route = RouteModel.fromMap(data);

        // Check if this route is scheduled for the requested day
        if (route.scheduleDays.contains(dayOfWeek)) {
          scheduledRoutes.add(route);
        }
      }

      return scheduledRoutes;
    } catch (e) {
      print('Error getting driver routes for day: $e');
      throw Exception('Failed to load driver routes for day: $e');
    }
  }

  // Get driver's weekly schedule
  Future<Map<int, List<RouteModel>>> getDriverWeeklySchedule(
    String driverId,
  ) async {
    Map<int, List<RouteModel>> weeklySchedule = {};

    // Initialize empty lists for each day
    for (int i = 0; i < 7; i++) {
      weeklySchedule[i] = [];
    }

    try {
      final snapshot =
          await _firestore
              .collection('waste_routes')
              .where('assignedDriverId', isEqualTo: driverId)
              .where('isCancelled', isEqualTo: false)
              .get();

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data();

        // Convert timestamps
        data['createdAt'] =
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        data['startedAt'] = (data['startedAt'] as Timestamp?)?.toDate();
        data['pausedAt'] = (data['pausedAt'] as Timestamp?)?.toDate();
        data['resumedAt'] = (data['resumedAt'] as Timestamp?)?.toDate();
        data['completedAt'] = (data['completedAt'] as Timestamp?)?.toDate();
        data['cancelledAt'] = (data['cancelledAt'] as Timestamp?)?.toDate();
        data['nextScheduledStart'] =
            (data['nextScheduledStart'] as Timestamp?)?.toDate();
        data['lastCompleted'] = (data['lastCompleted'] as Timestamp?)?.toDate();

        // Convert schedule times
        if (data['scheduleStartTime'] != null) {
          data['scheduleStartTime'] = {
            'hour': data['scheduleStartTime']['hour'] ?? 8,
            'minute': data['scheduleStartTime']['minute'] ?? 0,
          };
        }

        if (data['scheduleEndTime'] != null) {
          data['scheduleEndTime'] = {
            'hour': data['scheduleEndTime']['hour'] ?? 17,
            'minute': data['scheduleEndTime']['minute'] ?? 0,
          };
        }

        // Convert points
        _convertPointsData(data, 'coveragePoints');
        _convertPointsData(data, 'actualDirectionPath');

        final route = RouteModel.fromMap(data);

        // Add route to each day it's scheduled for
        for (int day in route.scheduleDays) {
          weeklySchedule[day]?.add(route);
        }
      }

      // Sort each day's routes by scheduleStartTime
      weeklySchedule.forEach((day, routes) {
        routes.sort((a, b) {
          if (a.scheduleStartTime == null && b.scheduleStartTime == null) {
            return 0;
          } else if (a.scheduleStartTime == null) {
            return 1;
          } else if (b.scheduleStartTime == null) {
            return -1;
          } else {
            int hourCompare = a.scheduleStartTime.hour.compareTo(
              b.scheduleStartTime.hour,
            );
            if (hourCompare != 0) {
              return hourCompare;
            } else {
              return a.scheduleStartTime.minute.compareTo(
                b.scheduleStartTime.minute,
              );
            }
          }
        });
      });

      return weeklySchedule;
    } catch (e) {
      print('Error getting driver weekly schedule: $e');
      throw Exception('Failed to load driver weekly schedule: $e');
    }
  }

  // Get routes by waste category
  Future<List<RouteModel>> getRoutesByCategory(String category) async {
    try {
      final snapshot =
          await _firestore
              .collection('waste_routes')
              .where('wasteCategory', isEqualTo: category)
              .orderBy('createdAt', descending: true)
              .get();

      List<RouteModel> routes = [];

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data();

        // Convert timestamps
        data['createdAt'] =
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        data['startedAt'] = (data['startedAt'] as Timestamp?)?.toDate();
        data['pausedAt'] = (data['pausedAt'] as Timestamp?)?.toDate();
        data['resumedAt'] = (data['resumedAt'] as Timestamp?)?.toDate();
        data['completedAt'] = (data['completedAt'] as Timestamp?)?.toDate();
        data['cancelledAt'] = (data['cancelledAt'] as Timestamp?)?.toDate();
        data['nextScheduledStart'] =
            (data['nextScheduledStart'] as Timestamp?)?.toDate();
        data['lastCompleted'] = (data['lastCompleted'] as Timestamp?)?.toDate();

        // Convert points
        _convertPointsData(data, 'coveragePoints');
        _convertPointsData(data, 'actualDirectionPath');

        routes.add(RouteModel.fromMap(data));
      }

      return routes;
    } catch (e) {
      print('Error getting routes by category: $e');
      throw Exception('Failed to load routes by category: $e');
    }
  }

  // Update a route's next scheduled date after completion
  Future<void> updateNextScheduledDate(String routeId) async {
    try {
      // Get the route
      final route = await getRoute(routeId);
      if (route == null) {
        throw Exception('Route not found');
      }

      // Only update if it's a recurring route
      if (route.scheduleFrequency == 'once') {
        return;
      }

      // Calculate next occurrence
      DateTime? nextOccurrence = _calculateNextScheduledDate(
        route.scheduleFrequency,
        route.scheduleDays,
        route.scheduleStartTime,
      );

      if (nextOccurrence != null) {
        await _firestore.collection('waste_routes').doc(routeId).update({
          'nextScheduledStart': nextOccurrence,
          'lastCompleted': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error updating next scheduled date: $e');
      throw Exception('Failed to update next scheduled date: $e');
    }
  }

  // Complete a route and update scheduling
  Future<void> completeScheduledRoute(String routeId) async {
    try {
      // Mark as completed
      await completeRoute(routeId);

      // Update next scheduled date if it's a recurring route
      await updateNextScheduledDate(routeId);

      // Get the route details
      RouteModel? route = await getRoute(routeId);

      if (route != null && route.assignedDriverId != null) {
        // Notify driver about completion
        await _notificationService.sendNotificationToUser(
          userId: route.assignedDriverId!,
          title: 'Route Completed',
          body: 'Route "${route.name}" has been marked as completed',
          channelKey: NotificationService.routeChannelKey,
          type: 'route_completed',
          referenceId: routeId,
        );

        // Notify residents in the area about completed collection (if needed)
        // This would need to find residents in the area of the route

        // Notify admins about route completion
        await _notificationService.sendRouteNotification(
          title: 'Route Completed',
          body:
              'Route "${route.name}" has been completed by ${route.driverName ?? "a driver"}',
          type: 'route_completed',
          roles: ['cityManagement'],
          routeId: routeId,
        );
      }
    } catch (e) {
      print('Error completing scheduled route: $e');
      throw Exception('Failed to complete scheduled route: $e');
    }
  }

  // Get all routes that need to be started today
  Future<List<RouteModel>> getTodayScheduledRoutes() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(Duration(days: 1));

      final snapshot =
          await _firestore
              .collection('waste_routes')
              .where('nextScheduledStart', isGreaterThanOrEqualTo: today)
              .where('nextScheduledStart', isLessThan: tomorrow)
              .where('isCancelled', isEqualTo: false)
              // Removed incorrect isActive filter to include both active and inactive routes
              .get();

      List<RouteModel> routes = [];

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data();

        // Convert timestamps
        data['createdAt'] =
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        data['startedAt'] = (data['startedAt'] as Timestamp?)?.toDate();
        data['pausedAt'] = (data['pausedAt'] as Timestamp?)?.toDate();
        data['resumedAt'] = (data['resumedAt'] as Timestamp?)?.toDate();
        data['completedAt'] = (data['completedAt'] as Timestamp?)?.toDate();
        data['cancelledAt'] = (data['cancelledAt'] as Timestamp?)?.toDate();
        data['nextScheduledStart'] =
            (data['nextScheduledStart'] as Timestamp?)?.toDate();
        data['lastCompleted'] = (data['lastCompleted'] as Timestamp?)?.toDate();

        // Convert schedule times
        if (data['scheduleStartTime'] != null) {
          data['scheduleStartTime'] = {
            'hour': data['scheduleStartTime']['hour'] ?? 8,
            'minute': data['scheduleStartTime']['minute'] ?? 0,
          };
        }

        if (data['scheduleEndTime'] != null) {
          data['scheduleEndTime'] = {
            'hour': data['scheduleEndTime']['hour'] ?? 17,
            'minute': data['scheduleEndTime']['minute'] ?? 0,
          };
        }

        // Convert points
        _convertPointsData(data, 'coveragePoints');
        _convertPointsData(data, 'actualDirectionPath');

        routes.add(RouteModel.fromMap(data));
      }

      return routes;
    } catch (e) {
      print('Error getting today\'s scheduled routes: $e');
      throw Exception('Failed to load today\'s scheduled routes: $e');
    }
  }

  // Get upcoming routes for next 7 days
  Future<Map<DateTime, List<RouteModel>>> getUpcomingWeekSchedule() async {
    Map<DateTime, List<RouteModel>> weekSchedule = {};

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final nextWeek = today.add(Duration(days: 7));

      final snapshot =
          await _firestore
              .collection('waste_routes')
              .where('nextScheduledStart', isGreaterThanOrEqualTo: today)
              .where('nextScheduledStart', isLessThan: nextWeek)
              .where('isCancelled', isEqualTo: false)
              .get();

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data();

        // Convert timestamps
        data['createdAt'] =
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        data['startedAt'] = (data['startedAt'] as Timestamp?)?.toDate();
        data['pausedAt'] = (data['pausedAt'] as Timestamp?)?.toDate();
        data['resumedAt'] = (data['resumedAt'] as Timestamp?)?.toDate();
        data['completedAt'] = (data['completedAt'] as Timestamp?)?.toDate();
        data['cancelledAt'] = (data['cancelledAt'] as Timestamp?)?.toDate();
        data['nextScheduledStart'] =
            (data['nextScheduledStart'] as Timestamp?)?.toDate();
        data['lastCompleted'] = (data['lastCompleted'] as Timestamp?)?.toDate();

        // Convert points
        _convertPointsData(data, 'coveragePoints');
        _convertPointsData(data, 'actualDirectionPath');

        final route = RouteModel.fromMap(data);

        if (route.nextScheduledStart != null) {
          // Create date key without time
          final dateKey = DateTime(
            route.nextScheduledStart!.year,
            route.nextScheduledStart!.month,
            route.nextScheduledStart!.day,
          );

          if (!weekSchedule.containsKey(dateKey)) {
            weekSchedule[dateKey] = [];
          }

          weekSchedule[dateKey]!.add(route);
        }
      }

      // Sort each day's routes by start time
      weekSchedule.forEach((date, routes) {
        routes.sort((a, b) {
          if (a.nextScheduledStart == null && b.nextScheduledStart == null) {
            return 0;
          } else if (a.nextScheduledStart == null) {
            return 1;
          } else if (b.nextScheduledStart == null) {
            return -1;
          } else {
            return a.nextScheduledStart!.compareTo(b.nextScheduledStart!);
          }
        });
      });

      return weekSchedule;
    } catch (e) {
      print('Error getting upcoming week schedule: $e');
      throw Exception('Failed to load upcoming week schedule: $e');
    }
  }

  // Improved route saving method with detailed directions
  Future<RouteModel> saveRouteWithDirections(
    String name,
    String description,
    LatLng start,
    LatLng end, {
    String? assignedDriverId,
    String? driverName,
    String? driverContact,
    String? truckId,
  }) async {
    try {
      // Get current user ID for permission control
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Fetch route directions from Google Maps Directions API
      final directionsResponse = await _fetchRouteDirections(start, end);

      // Calculate total distance
      double totalDistance =
          directionsResponse['routes'][0]['legs'][0]['distance']['value'] /
          1000; // Convert to kilometers

      // Extract route points and actual direction path
      List<Map<String, double>> coveragePoints = _extractRouteCoveragePoints(
        directionsResponse,
      );
      List<Map<String, double>> actualDirectionPath =
          _extractActualDirectionPath(directionsResponse);

      // Create RouteModel
      final route = RouteModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        description: description,
        startLat: start.latitude,
        startLng: start.longitude,
        endLat: end.latitude,
        endLng: end.longitude,
        distance: totalDistance,
        coveragePoints: coveragePoints,
        actualDirectionPath: actualDirectionPath,
        createdAt: DateTime.now(),
        isActive: false,
        isPaused: false,
        isCancelled: false,
        createdBy: currentUser.uid,
        assignedDriverId: assignedDriverId,
        driverName: driverName,
        driverContact: driverContact,
        truckId: truckId,
        scheduleStartTime: TimeOfDay(hour: 0, minute: 0),
        scheduleEndTime: TimeOfDay(hour: 0, minute: 0),
      );

      // Save to Firestore
      await _firestore
          .collection('waste_routes')
          .doc(route.id)
          .set(route.toMap());

      // Initialize route progress data
      await _firestore.collection('route_progress').doc(route.id).set({
        'completionPercentage': 0.0,
        'totalEstimatedTimeMinutes': 0.0,
        'remainingTimeMinutes': 0.0,
      });

      // Send notifications
      if (assignedDriverId != null) {
        // Notify assigned driver
        await _notificationService.sendNotificationToUser(
          userId: assignedDriverId,
          title: 'New Route Assigned',
          body: 'You have been assigned a new waste collection route: ${name}',
          channelKey: NotificationService.routeChannelKey,
          type: 'route_assigned',
          referenceId: route.id,
        );
      }

      // Notify admins
      await _notificationService.sendRouteNotification(
        title: 'New Route Created',
        body: 'A new waste collection route has been created: ${name}',
        type: 'route_created',
        roles: ['cityManagement'],
        routeId: route.id,
      );

      return route;
    } catch (e) {
      print('Error saving route with directions: $e');
      throw Exception('Failed to save route: $e');
    }
  }

  // Fetch route directions from Google Maps Directions API
  Future<Map<String, dynamic>> _fetchRouteDirections(
    LatLng start,
    LatLng end,
  ) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json?'
      'origin=${start.latitude},${start.longitude}'
      '&destination=${end.latitude},${end.longitude}'
      '&key=$_googleMapsApiKey',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final directions = json.decode(response.body);

      if (directions['status'] == 'OK') {
        return directions;
      } else {
        throw Exception('Failed to fetch directions: ${directions['status']}');
      }
    } else {
      throw Exception('Failed to connect to Directions API');
    }
  }

  // Extract coverage points from the directions response
  List<Map<String, double>> _extractRouteCoveragePoints(
    Map<String, dynamic> directionsResponse,
  ) {
    List<Map<String, double>> points = [];

    // Extract points from the route's polyline
    final route = directionsResponse['routes'][0];
    final leg = route['legs'][0];
    final steps = leg['steps'];

    // Add start point
    points.add({
      'lat': steps[0]['start_location']['lat'],
      'lng': steps[0]['start_location']['lng'],
    });

    // Add intermediate points from each step
    for (var step in steps) {
      points.add({
        'lat': step['end_location']['lat'],
        'lng': step['end_location']['lng'],
      });
    }

    return points;
  }

  // Extract the actual direction path from the polyline
  List<Map<String, double>> _extractActualDirectionPath(
    Map<String, dynamic> directionsResponse,
  ) {
    List<Map<String, double>> points = [];

    // Extract the encoded polyline
    final route = directionsResponse['routes'][0];
    final encodedPolyline = route['overview_polyline']['points'];

    // Decode the polyline
    final List<LatLng> decodedPoints = _decodePolyline(encodedPolyline);

    // Convert to our map format
    for (var point in decodedPoints) {
      points.add({'lat': point.latitude, 'lng': point.longitude});
    }

    return points;
  }

  // Decode Google's encoded polyline
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      LatLng p = LatLng((lat / 1E5).toDouble(), (lng / 1E5).toDouble());
      poly.add(p);
    }

    return poly;
  }

  // Save a new route
  Future<void> saveRoute(RouteModel route) async {
    try {
      // Get current user ID for permission control
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _firestore.collection('waste_routes').doc(route.id).set({
        ...route.toMap(),
        'createdBy': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving route: $e');
      throw Exception('Failed to save route: $e');
    }
  }

  // Get all routes
  Stream<List<RouteModel>> getRoutes() {
    try {
      return _firestore
          .collection('waste_routes')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            List<RouteModel> routes = [];

            for (var doc in snapshot.docs) {
              try {
                Map<String, dynamic> data = doc.data();

                // Convert timestamps to DateTime
                data['createdAt'] =
                    (data['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime.now();
                data['startedAt'] = (data['startedAt'] as Timestamp?)?.toDate();
                data['pausedAt'] = (data['pausedAt'] as Timestamp?)?.toDate();
                data['resumedAt'] = (data['resumedAt'] as Timestamp?)?.toDate();
                data['completedAt'] =
                    (data['completedAt'] as Timestamp?)?.toDate();
                data['cancelledAt'] =
                    (data['cancelledAt'] as Timestamp?)?.toDate();
                data['nextScheduledStart'] =
                    (data['nextScheduledStart'] as Timestamp?)?.toDate();
                data['lastCompleted'] =
                    (data['lastCompleted'] as Timestamp?)?.toDate();

                // Convert schedule times
                if (data['scheduleStartTime'] != null) {
                  data['scheduleStartTime'] = {
                    'hour': data['scheduleStartTime']['hour'] ?? 8,
                    'minute': data['scheduleStartTime']['minute'] ?? 0,
                  };
                }

                if (data['scheduleEndTime'] != null) {
                  data['scheduleEndTime'] = {
                    'hour': data['scheduleEndTime']['hour'] ?? 17,
                    'minute': data['scheduleEndTime']['minute'] ?? 0,
                  };
                }

                // Handle coveragePoints and actualDirectionPath conversion
                _convertPointsData(data, 'coveragePoints');
                _convertPointsData(data, 'actualDirectionPath');

                final route = RouteModel.fromMap(data);
                routes.add(route);

                print('Successfully loaded route: ${route.id} - ${route.name}');
              } catch (e) {
                print('Error parsing document ${doc.id}: $e');
              }
            }

            print('Total routes loaded: ${routes.length}');
            return routes;
          });
    } catch (e) {
      print('Error getting routes stream: $e');
      return Stream.value([]);
    }
  }

  // Get active routes
  Stream<List<RouteModel>> getActiveRoutes() {
    try {
      return _firestore
          .collection('waste_routes')
          .where('isActive', isEqualTo: true)
          .where('isCancelled', isEqualTo: false)
          .snapshots()
          .map((snapshot) {
            List<RouteModel> routes = [];

            for (var doc in snapshot.docs) {
              try {
                Map<String, dynamic> data = doc.data();

                // Convert timestamps to DateTime
                data['createdAt'] =
                    (data['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime.now();
                data['startedAt'] = (data['startedAt'] as Timestamp?)?.toDate();
                data['pausedAt'] = (data['pausedAt'] as Timestamp?)?.toDate();
                data['resumedAt'] = (data['resumedAt'] as Timestamp?)?.toDate();
                data['completedAt'] =
                    (data['completedAt'] as Timestamp?)?.toDate();
                data['cancelledAt'] =
                    (data['cancelledAt'] as Timestamp?)?.toDate();
                data['nextScheduledStart'] =
                    (data['nextScheduledStart'] as Timestamp?)?.toDate();
                data['lastCompleted'] =
                    (data['lastCompleted'] as Timestamp?)?.toDate();

                // Convert schedule times
                if (data['scheduleStartTime'] != null) {
                  data['scheduleStartTime'] = {
                    'hour': data['scheduleStartTime']['hour'] ?? 8,
                    'minute': data['scheduleStartTime']['minute'] ?? 0,
                  };
                }

                if (data['scheduleEndTime'] != null) {
                  data['scheduleEndTime'] = {
                    'hour': data['scheduleEndTime']['hour'] ?? 17,
                    'minute': data['scheduleEndTime']['minute'] ?? 0,
                  };
                }

                // Handle coveragePoints and actualDirectionPath conversion
                _convertPointsData(data, 'coveragePoints');
                _convertPointsData(data, 'actualDirectionPath');

                routes.add(RouteModel.fromMap(data));
              } catch (e) {
                print('Error parsing route document: $e');
              }
            }

            return routes;
          });
    } catch (e) {
      print('Error getting active routes stream: $e');
      return Stream.value([]);
    }
  }

  // Helper method to convert point data
  void _convertPointsData(Map<String, dynamic> data, String field) {
    if (data[field] != null) {
      final points = data[field] as List<dynamic>;
      data[field] =
          points.map((point) {
            if (point is Map) {
              return {
                'lat':
                    (point['lat'] is num)
                        ? (point['lat'] as num).toDouble()
                        : 0.0,
                'lng':
                    (point['lng'] is num)
                        ? (point['lng'] as num).toDouble()
                        : 0.0,
              };
            } else {
              return {'lat': 0.0, 'lng': 0.0};
            }
          }).toList();
    } else {
      data[field] = [];
    }
  }

  // Get a specific route
  Future<RouteModel?> getRoute(String routeId) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('waste_routes').doc(routeId).get();

      if (!doc.exists) return null;

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      // Convert timestamps to DateTime
      data['createdAt'] =
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      data['startedAt'] = (data['startedAt'] as Timestamp?)?.toDate();
      data['pausedAt'] = (data['pausedAt'] as Timestamp?)?.toDate();
      data['resumedAt'] = (data['resumedAt'] as Timestamp?)?.toDate();
      data['completedAt'] = (data['completedAt'] as Timestamp?)?.toDate();
      data['cancelledAt'] = (data['cancelledAt'] as Timestamp?)?.toDate();
      data['nextScheduledStart'] =
          (data['nextScheduledStart'] as Timestamp?)?.toDate();
      data['lastCompleted'] = (data['lastCompleted'] as Timestamp?)?.toDate();

      // Fix points type conversion
      _convertPointsData(data, 'coveragePoints');
      _convertPointsData(data, 'actualDirectionPath');

      // Convert schedule times
      if (data['scheduleStartTime'] != null) {
        data['scheduleStartTime'] = {
          'hour': data['scheduleStartTime']['hour'] ?? 8,
          'minute': data['scheduleStartTime']['minute'] ?? 0,
        };
      }

      if (data['scheduleEndTime'] != null) {
        data['scheduleEndTime'] = {
          'hour': data['scheduleEndTime']['hour'] ?? 17,
          'minute': data['scheduleEndTime']['minute'] ?? 0,
        };
      }

      return RouteModel.fromMap(data);
    } catch (e) {
      print('Error getting route: $e');
      return null;
    }
  }

  // Get available routes for the current driver
  Future<List<RouteModel>> getAvailableRoutes() async {
    try {
      // Get current user ID for permission control
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Modified query to include both inactive and completed routes
      // as either can now be started/restarted
      final snapshot =
          await _firestore
              .collection('waste_routes')
              .where('assignedDriverId', isEqualTo: currentUser.uid)
              .where('isCancelled', isEqualTo: false)
              .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data();

        // Convert timestamps to DateTime
        data['createdAt'] =
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        data['startedAt'] = (data['startedAt'] as Timestamp?)?.toDate();
        data['pausedAt'] = (data['pausedAt'] as Timestamp?)?.toDate();
        data['resumedAt'] = (data['resumedAt'] as Timestamp?)?.toDate();
        data['completedAt'] = (data['completedAt'] as Timestamp?)?.toDate();
        data['cancelledAt'] = (data['cancelledAt'] as Timestamp?)?.toDate();
        data['nextScheduledStart'] =
            (data['nextScheduledStart'] as Timestamp?)?.toDate();
        data['lastCompleted'] = (data['lastCompleted'] as Timestamp?)?.toDate();

        // Convert schedule times
        if (data['scheduleStartTime'] != null) {
          data['scheduleStartTime'] = {
            'hour': data['scheduleStartTime']['hour'] ?? 8,
            'minute': data['scheduleStartTime']['minute'] ?? 0,
          };
        }

        if (data['scheduleEndTime'] != null) {
          data['scheduleEndTime'] = {
            'hour': data['scheduleEndTime']['hour'] ?? 17,
            'minute': data['scheduleEndTime']['minute'] ?? 0,
          };
        }

        // Fix points type conversion
        _convertPointsData(data, 'coveragePoints');
        _convertPointsData(data, 'actualDirectionPath');

        return RouteModel.fromMap(data);
      }).toList();
    } catch (e) {
      print('Error getting available routes: $e');
      throw Exception('Failed to load available routes: $e');
    }
  }

  // Start a route - now works for new, completed or inactive routes
  Future<void> startRoute(String routeId) async {
    try {
      await _firestore.collection('waste_routes').doc(routeId).update({
        'isActive': true,
        'isPaused': false,
        'isCancelled': false,
        'startedAt': FieldValue.serverTimestamp(),
        // Clear completedAt to indicate route is active again
        'completedAt': null,
        // Reset progress
        'currentProgressPercentage': 0.0,
      });

      // Record route start in history
      await _firestore.collection('route_history').add({
        'routeId': routeId,
        'action': 'start',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Clear previous route progress data
      await _firestore.collection('route_progress').doc(routeId).set({
        'routeId': routeId,
        'completionPercentage': 0.0,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Get route details for notifications
      RouteModel? route = await getRoute(routeId);
      if (route != null) {
        // If the route has an assigned driver, notify them
        if (route.assignedDriverId != null) {
          await _notificationService.sendNotificationToUser(
            userId: route.assignedDriverId!,
            title: 'Route Started',
            body: 'Route "${route.name}" has been started.',
            channelKey: NotificationService.routeChannelKey,
            type: 'route_started',
            referenceId: routeId,
          );
        }

        // Notify admins
        await _notificationService.sendRouteNotification(
          title: 'Route Started',
          body:
              'Route "${route.name}" has been started by ${route.driverName ?? "a driver"}',
          type: 'route_started',
          roles: ['cityManagement'],
          routeId: routeId,
        );

        // Notify residents in the area that collection is coming
        // This would require additional logic to find residents in the route area
        // You could implement this using geocoding and distance calculations
      }
    } catch (e) {
      print('Error starting route: $e');
      throw Exception('Failed to start route: $e');
    }
  }

  // Complete a route - but allow it to be restarted later
  Future<void> completeRoute(String routeId) async {
    try {
      await _firestore.collection('waste_routes').doc(routeId).update({
        'isActive': false,
        'isPaused': false,
        'completedAt': FieldValue.serverTimestamp(),
        'currentProgressPercentage': 100.0,
      });

      // Record route completion in history
      await _firestore.collection('route_history').add({
        'routeId': routeId,
        'action': 'complete',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Get route details for notifications
      RouteModel? route = await getRoute(routeId);
      if (route != null) {
        // If the route has an assigned driver, notify them
        if (route.assignedDriverId != null) {
          await _notificationService.sendNotificationToUser(
            userId: route.assignedDriverId!,
            title: 'Route Completed',
            body: 'Route "${route.name}" has been completed.',
            channelKey: NotificationService.routeChannelKey,
            type: 'route_completed',
            referenceId: routeId,
          );
        }

        // Notify admins
        await _notificationService.sendRouteNotification(
          title: 'Route Completed',
          body:
              'Route "${route.name}" has been completed by ${route.driverName ?? "a driver"}',
          type: 'route_completed',
          roles: ['cityManagement'],
          routeId: routeId,
        );
      }
    } catch (e) {
      print('Error completing route: $e');
      throw Exception('Failed to complete route: $e');
    }
  }

  // New method to restart a completed route without closing
  Future<void> restartCompletedRoute(String routeId) async {
    try {
      await _firestore.collection('waste_routes').doc(routeId).update({
        'isActive': true,
        'isPaused': false,
        'isCancelled': false,
        'completedAt': null, // Clear completion timestamp
        'currentProgressPercentage': 0.0, // Reset progress
        'startedAt': FieldValue.serverTimestamp(), // Update started time
      });

      // Record route restart in history
      await _firestore.collection('route_history').add({
        'routeId': routeId,
        'action': 'restart',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Reset route progress data
      await _firestore.collection('route_progress').doc(routeId).set({
        'routeId': routeId,
        'completionPercentage': 0.0,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error restarting completed route: $e');
      throw Exception('Failed to restart completed route: $e');
    }
  }

  // Restart a completed route
  Future<void> restartRoute(String routeId) async {
    try {
      await _firestore.collection('waste_routes').doc(routeId).update({
        'isActive': true,
        'isPaused': false,
        'isCancelled': false,
        'startedAt': FieldValue.serverTimestamp(),
        // Clear completedAt to indicate route is active again
        'completedAt': null,
        // Reset progress
        'currentProgressPercentage': 0.0,
      });

      // Record route restart in history
      await _firestore.collection('route_history').add({
        'routeId': routeId,
        'action': 'restart',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Clear previous route progress data
      await _firestore.collection('route_progress').doc(routeId).set({
        'routeId': routeId,
        'completionPercentage': 0.0,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Get route details for notifications
      RouteModel? route = await getRoute(routeId);
      if (route != null) {
        // If the route has an assigned driver, notify them
        if (route.assignedDriverId != null) {
          await _notificationService.sendNotificationToUser(
            userId: route.assignedDriverId!,
            title: 'Route Restarted',
            body: 'Route "${route.name}" has been restarted.',
            channelKey: NotificationService.routeChannelKey,
            type: 'route_restarted',
            referenceId: routeId,
          );
        }

        // Notify admins
        await _notificationService.sendRouteNotification(
          title: 'Route Restarted',
          body:
              'Route "${route.name}" has been restarted by ${route.driverName ?? "a driver"}',
          type: 'route_restarted',
          roles: ['cityManagement'],
          routeId: routeId,
        );
      }
    } catch (e) {
      print('Error restarting route: $e');
      throw Exception('Failed to restart route: $e');
    }
  }

  // Pause a route
  Future<void> pauseRoute(String routeId) async {
    try {
      await _firestore.collection('waste_routes').doc(routeId).update({
        'isPaused': true,
        'pausedAt': FieldValue.serverTimestamp(),
      });

      // Record route pause in history
      await _firestore.collection('route_history').add({
        'routeId': routeId,
        'action': 'pause',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Get route details for notifications
      RouteModel? route = await getRoute(routeId);
      if (route != null) {
        // If the route has an assigned driver, notify them
        if (route.assignedDriverId != null) {
          await _notificationService.sendNotificationToUser(
            userId: route.assignedDriverId!,
            title: 'Route Paused',
            body: 'Route "${route.name}" has been paused.',
            channelKey: NotificationService.routeChannelKey,
            type: 'route_paused',
            referenceId: routeId,
          );
        }

        // Notify admins
        await _notificationService.sendRouteNotification(
          title: 'Route Paused',
          body:
              'Route "${route.name}" has been paused by ${route.driverName ?? "a driver"}',
          type: 'route_paused',
          roles: ['cityManagement'],
          routeId: routeId,
        );
      }
    } catch (e) {
      print('Error pausing route: $e');
      throw Exception('Failed to pause route: $e');
    }
  }

  // Resume a route
  Future<void> resumeRoute(String routeId) async {
    try {
      await _firestore.collection('waste_routes').doc(routeId).update({
        'isPaused': false,
        'resumedAt': FieldValue.serverTimestamp(),
      });

      // Record route resume in history
      await _firestore.collection('route_history').add({
        'routeId': routeId,
        'action': 'resume',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Get route details for notifications
      RouteModel? route = await getRoute(routeId);
      if (route != null) {
        // If the route has an assigned driver, notify them
        if (route.assignedDriverId != null) {
          await _notificationService.sendNotificationToUser(
            userId: route.assignedDriverId!,
            title: 'Route Resumed',
            body: 'Route "${route.name}" has been resumed.',
            channelKey: NotificationService.routeChannelKey,
            type: 'route_resumed',
            referenceId: routeId,
          );
        }

        // Notify admins
        await _notificationService.sendRouteNotification(
          title: 'Route Resumed',
          body:
              'Route "${route.name}" has been resumed by ${route.driverName ?? "a driver"}',
          type: 'route_resumed',
          roles: ['cityManagement'],
          routeId: routeId,
        );
      }
    } catch (e) {
      print('Error resuming route: $e');
      throw Exception('Failed to resume route: $e');
    }
  }

  // Cancel a route
  Future<void> cancelRoute(String routeId) async {
    try {
      await _firestore.collection('waste_routes').doc(routeId).update({
        'isActive': false,
        'isPaused': false,
        'isCancelled': true,
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      // Record route cancellation in history
      await _firestore.collection('route_history').add({
        'routeId': routeId,
        'action': 'cancel',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Get route details for notifications
      RouteModel? route = await getRoute(routeId);
      if (route != null) {
        // If the route has an assigned driver, notify them
        if (route.assignedDriverId != null) {
          await _notificationService.sendNotificationToUser(
            userId: route.assignedDriverId!,
            title: 'Route Cancelled',
            body: 'Route "${route.name}" has been cancelled.',
            channelKey: NotificationService.routeChannelKey,
            type: 'route_cancelled',
            referenceId: routeId,
          );
        }

        // Notify admins
        await _notificationService.sendRouteNotification(
          title: 'Route Cancelled',
          body: 'Route "${route.name}" has been cancelled',
          type: 'route_cancelled',
          roles: ['cityManagement'],
          routeId: routeId,
        );
      }
    } catch (e) {
      print('Error cancelling route: $e');
      throw Exception('Failed to cancel route: $e');
    }
  }

  // Update route progress
  Future<void> updateRouteProgress(
    String routeId,
    LatLng position, {
    List<LatLng>? coveredPoints,
    double? distanceCovered,
    double? completionPercentage,
    DateTime? startTime,
  }) async {
    try {
      // Skip obviously invalid coordinates
      if (position.latitude == 0.0 && position.longitude == 0.0) {
        print(
          'Warning: Skipping update with invalid coordinates (0,0) for route $routeId',
        );
        return;
      }

      print(
        'Updating route progress for $routeId at position: ${position.latitude}, ${position.longitude}',
      );

      Map<String, dynamic> data = {
        'routeId': routeId,
        'currentLat': position.latitude,
        'currentLng': position.longitude,
        'timestamp': FieldValue.serverTimestamp(),
        'lastUpdated':
            DateTime.now()
                .toIso8601String(), // Add ISO timestamp for easier debugging
      };

      if (coveredPoints != null && coveredPoints.isNotEmpty) {
        // Convert to serializable format
        List<Map<String, double>> serializedPoints =
            coveredPoints
                .map((point) => {'lat': point.latitude, 'lng': point.longitude})
                .toList();
        data['coveredPoints'] = serializedPoints;
      }

      if (distanceCovered != null) {
        data['distanceCovered'] = distanceCovered;
      }

      if (completionPercentage != null) {
        data['completionPercentage'] = completionPercentage;
        print(
          'Setting completion percentage for route $routeId: $completionPercentage%',
        );

        // Also update the route document with the completion percentage
        await _firestore.collection('waste_routes').doc(routeId).update({
          'currentProgressPercentage': completionPercentage,
        });
      }

      // Calculate and update remaining time if startTime is provided
      if (startTime != null) {
        final now = DateTime.now();
        final elapsedMinutes = now.difference(startTime).inMinutes;

        if (completionPercentage != null && completionPercentage > 0) {
          // Estimate total time based on elapsed time and completion percentage
          final estimatedTotalMinutes =
              (elapsedMinutes / completionPercentage) * 100;
          final remainingMinutes = estimatedTotalMinutes - elapsedMinutes;

          data['totalEstimatedTimeMinutes'] = estimatedTotalMinutes;
          data['remainingTimeMinutes'] = remainingMinutes;

          print(
            'Estimated completion time for route $routeId: $remainingMinutes minutes remaining',
          );
        }
      }

      // Update the progress document
      await _firestore
          .collection('route_progress')
          .doc(routeId)
          .set(data, SetOptions(merge: true));

      print('Successfully updated progress for route $routeId');

      // If progress is 100%, automatically mark the route as completed
      if (completionPercentage != null && completionPercentage >= 100.0) {
        await completeRoute(routeId);
      }
    } catch (e) {
      print('Error updating route progress: $e');
      throw Exception('Failed to update route progress: $e');
    }
  }

  // Get route time estimation
  Future<Map<String, dynamic>> getRouteTimeEstimation(String routeId) async {
    try {
      // Get the current progress data
      DocumentSnapshot progressDoc =
          await _firestore.collection('route_progress').doc(routeId).get();

      // Get the route data
      RouteModel? route = await getRoute(routeId);

      if (!progressDoc.exists || route == null) {
        return {
          'completionPercentage': 0.0,
          'remainingTimeMinutes': 0,
          'totalEstimatedTimeMinutes': 0,
          'estimatedCompletionTime': DateTime.now().add(Duration(hours: 1)),
        };
      }

      Map<String, dynamic> progressData =
          progressDoc.data() as Map<String, dynamic>;

      // Get completion percentage
      double completionPercentage =
          progressData['completionPercentage'] != null
              ? (progressData['completionPercentage'] as num).toDouble()
              : 0.0;

      // Get time estimates
      double totalEstimatedTimeMinutes =
          progressData['totalEstimatedTimeMinutes'] != null
              ? (progressData['totalEstimatedTimeMinutes'] as num).toDouble()
              : 60.0; // Default 1 hour

      double remainingTimeMinutes =
          progressData['remainingTimeMinutes'] != null
              ? (progressData['remainingTimeMinutes'] as num).toDouble()
              : totalEstimatedTimeMinutes; // Default to total time

      // Calculate estimated completion time
      DateTime now = DateTime.now();
      DateTime estimatedCompletionTime = now.add(
        Duration(minutes: remainingTimeMinutes.round()),
      );

      // If the route is active and has a start time, use that for more accurate estimates
      if (route.isActive && route.startedAt != null) {
        final elapsedMinutes = now.difference(route.startedAt!).inMinutes;

        if (completionPercentage > 0) {
          // Recalculate total time based on current progress and elapsed time
          totalEstimatedTimeMinutes =
              (elapsedMinutes / completionPercentage) * 100;
          remainingTimeMinutes = totalEstimatedTimeMinutes - elapsedMinutes;

          // Update estimated completion time
          estimatedCompletionTime = now.add(
            Duration(minutes: remainingTimeMinutes.round()),
          );
        }
      }

      return {
        'completionPercentage': completionPercentage,
        'remainingTimeMinutes': remainingTimeMinutes,
        'totalEstimatedTimeMinutes': totalEstimatedTimeMinutes,
        'estimatedCompletionTime': estimatedCompletionTime,
        'lastUpdated':
            progressData['timestamp'] != null
                ? (progressData['timestamp'] as Timestamp).toDate()
                : now,
      };
    } catch (e) {
      print('Error getting route time estimation: $e');
      // Return default values if there's an error
      return {
        'completionPercentage': 0.0,
        'remainingTimeMinutes': 0,
        'totalEstimatedTimeMinutes': 0,
        'estimatedCompletionTime': DateTime.now().add(Duration(hours: 1)),
        'error': e.toString(),
      };
    }
  }

  // Get real-time route progress updates
  Stream<LatLng?> getRouteProgress(String routeId) {
    try {
      return _firestore
          .collection('route_progress')
          .doc(routeId)
          .snapshots()
          .map((snapshot) {
            if (snapshot.exists && snapshot.data() != null) {
              final data = snapshot.data() as Map<String, dynamic>;

              // Check if we have valid coordinates
              if (data.containsKey('currentLat') &&
                  data.containsKey('currentLng') &&
                  data['currentLat'] != null &&
                  data['currentLng'] != null) {
                final lat = (data['currentLat'] as num).toDouble();
                final lng = (data['currentLng'] as num).toDouble();

                return LatLng(lat, lng);
              }
            }
            return null;
          });
    } catch (e) {
      print('Error getting route progress: $e');
      return Stream.value(null);
    }
  }

  // Get active routes with driver information
  Stream<List<Map<String, dynamic>>> getActiveRoutesWithDriverInfo() {
    try {
      // Create a controller to manage our async operations properly
      final controller = StreamController<List<Map<String, dynamic>>>();

      // Subscribe to the route changes
      final subscription = _firestore
          .collection('waste_routes')
          .where('isActive', isEqualTo: true)
          .where('isCancelled', isEqualTo: false)
          .snapshots()
          .listen(
            (snapshot) async {
              try {
                List<Map<String, dynamic>> activeRoutes = [];

                // Process each document
                for (var doc in snapshot.docs) {
                  try {
                    Map<String, dynamic> data = doc.data();

                    // Convert timestamps
                    data['createdAt'] =
                        (data['createdAt'] as Timestamp?)?.toDate() ??
                        DateTime.now();
                    data['startedAt'] =
                        (data['startedAt'] as Timestamp?)?.toDate();
                    data['pausedAt'] =
                        (data['pausedAt'] as Timestamp?)?.toDate();
                    data['resumedAt'] =
                        (data['resumedAt'] as Timestamp?)?.toDate();
                    data['completedAt'] =
                        (data['completedAt'] as Timestamp?)?.toDate();
                    data['cancelledAt'] =
                        (data['cancelledAt'] as Timestamp?)?.toDate();
                    data['nextScheduledStart'] =
                        (data['nextScheduledStart'] as Timestamp?)?.toDate();
                    data['lastCompleted'] =
                        (data['lastCompleted'] as Timestamp?)?.toDate();

                    // Convert points
                    _convertPointsData(data, 'coveragePoints');
                    _convertPointsData(data, 'actualDirectionPath');

                    // Convert schedule times
                    if (data['scheduleStartTime'] != null) {
                      data['scheduleStartTime'] = {
                        'hour': data['scheduleStartTime']['hour'] ?? 8,
                        'minute': data['scheduleStartTime']['minute'] ?? 0,
                      };
                    }

                    if (data['scheduleEndTime'] != null) {
                      data['scheduleEndTime'] = {
                        'hour': data['scheduleEndTime']['hour'] ?? 17,
                        'minute': data['scheduleEndTime']['minute'] ?? 0,
                      };
                    }

                    final route = RouteModel.fromMap(data);

                    // Get current progress data for this route
                    DocumentSnapshot routeDoc =
                        await _firestore
                            .collection('route_progress')
                            .doc(route.id)
                            .get();
                    double completionPercentage = 0.0;
                    LatLng? currentPosition;

                    if (routeDoc.exists && routeDoc.data() != null) {
                      final progressData =
                          routeDoc.data() as Map<String, dynamic>;

                      if (progressData['completionPercentage'] != null) {
                        completionPercentage =
                            (progressData['completionPercentage'] as num)
                                .toDouble();
                      }

                      if (progressData['currentLat'] != null &&
                          progressData['currentLng'] != null) {
                        final lat =
                            (progressData['currentLat'] as num).toDouble();
                        final lng =
                            (progressData['currentLng'] as num).toDouble();
                        currentPosition = LatLng(lat, lng);
                      }
                    }

                    // If no current position found, use the route start position
                    if (currentPosition == null) {
                      currentPosition = LatLng(route.startLat, route.startLng);
                    }

                    // Get time estimation for more accurate completion data
                    final timeEstimation = await getRouteTimeEstimation(
                      route.id,
                    );

                    activeRoutes.add({
                      'route': route,
                      'currentPosition': currentPosition,
                      'completionPercentage': completionPercentage,
                      'estimatedCompletionTime':
                          timeEstimation['estimatedCompletionTime'],
                      'remainingTimeMinutes':
                          timeEstimation['remainingTimeMinutes'],
                    });
                  } catch (e) {
                    print('Error parsing document ${doc.id}: $e');
                  }
                }

                // Add results to the stream if the controller is still active
                if (!controller.isClosed) {
                  controller.add(activeRoutes);
                }
              } catch (e) {
                print('Error processing route documents: $e');
                if (!controller.isClosed) {
                  controller.addError(e);
                }
              }
            },
            onError: (e) {
              print('Error in Firestore query: $e');
              if (!controller.isClosed) {
                controller.addError(e);
              }
            },
          );

      // Make sure to clean up when the stream is cancelled
      controller.onCancel = () {
        subscription.cancel();
      };

      return controller.stream;
    } catch (e) {
      print('Error setting up active routes stream: $e');
      return Stream.value([]);
    }
  }

  // Get driver's active route
  Future<RouteModel?> getDriverActiveRoute(String driverId) async {
    try {
      final snapshot =
          await _firestore
              .collection('waste_routes')
              .where('assignedDriverId', isEqualTo: driverId)
              .where('isActive', isEqualTo: true)
              .where('isCancelled', isEqualTo: false)
              .limit(1)
              .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      Map<String, dynamic> data = snapshot.docs.first.data();

      // Convert timestamps
      data['createdAt'] =
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      data['startedAt'] = (data['startedAt'] as Timestamp?)?.toDate();
      data['pausedAt'] = (data['pausedAt'] as Timestamp?)?.toDate();
      data['resumedAt'] = (data['resumedAt'] as Timestamp?)?.toDate();
      data['completedAt'] = (data['completedAt'] as Timestamp?)?.toDate();
      data['cancelledAt'] = (data['cancelledAt'] as Timestamp?)?.toDate();
      data['nextScheduledStart'] =
          (data['nextScheduledStart'] as Timestamp?)?.toDate();
      data['lastCompleted'] = (data['lastCompleted'] as Timestamp?)?.toDate();

      // Convert schedule times
      if (data['scheduleStartTime'] != null) {
        data['scheduleStartTime'] = {
          'hour': data['scheduleStartTime']['hour'] ?? 8,
          'minute': data['scheduleStartTime']['minute'] ?? 0,
        };
      }

      if (data['scheduleEndTime'] != null) {
        data['scheduleEndTime'] = {
          'hour': data['scheduleEndTime']['hour'] ?? 17,
          'minute': data['scheduleEndTime']['minute'] ?? 0,
        };
      }

      // Convert points
      _convertPointsData(data, 'coveragePoints');
      _convertPointsData(data, 'actualDirectionPath');

      return RouteModel.fromMap(data);
    } catch (e) {
      print('Error getting driver active route: $e');
      return null;
    }
  }

  // Get route progress state
  Future<Map<String, dynamic>?> getRouteProgressState(String routeId) async {
    try {
      print('Fetching route progress state for routeId: $routeId');
      DocumentSnapshot doc =
          await _firestore.collection('route_progress').doc(routeId).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;

        // Log the position data for debugging
        if (data.containsKey('currentLat') && data.containsKey('currentLng')) {
          final lat = data['currentLat'];
          final lng = data['currentLng'];
          print('Found position for route $routeId: $lat, $lng');

          // Validate coordinates
          if (lat == 0.0 && lng == 0.0) {
            print('Warning: Zero coordinates found for route $routeId');
          }

          // Check for last update timestamp
          final timestamp = data['lastUpdated'];
          if (timestamp != null) {
            final lastUpdate = DateTime.parse(timestamp);
            final now = DateTime.now();
            final difference = now.difference(lastUpdate);
            print('Position is ${difference.inSeconds} seconds old');

            // Flag potentially stale data
            if (difference.inMinutes > 10) {
              print('WARNING: Position data is more than 10 minutes old!');
            }
          }
        } else {
          print('Position data missing for route $routeId');
        }

        return data;
      } else {
        print('No progress document found for route $routeId');
      }

      return null;
    } catch (e) {
      print('Error getting route progress state for route $routeId: $e');
      return null;
    }
  }

  // Listen for real-time updates to route progress
  Stream<Map<String, dynamic>?> listenToRouteProgress(String routeId) {
    print('Setting up real-time listener for route progress: $routeId');

    return _firestore.collection('route_progress').doc(routeId).snapshots().map(
      (snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;

          // Log the position data for debugging
          if (data.containsKey('currentLat') &&
              data.containsKey('currentLng')) {
            final lat = data['currentLat'];
            final lng = data['currentLng'];
            print('Real-time update for route $routeId: $lat, $lng');

            // Validate coordinates
            if (lat == 0.0 && lng == 0.0) {
              print(
                'Warning: Ignoring zero coordinates update for route $routeId',
              );
              // Return null to indicate invalid data
              return null;
            }
          } else {
            print(
              'Position data missing in real-time update for route $routeId',
            );
            return null;
          }

          return data;
        }

        print('No document in real-time update for route $routeId');
        return null;
      },
    );
  }
}
