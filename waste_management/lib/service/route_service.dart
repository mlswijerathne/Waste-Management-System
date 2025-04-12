import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:waste_management/models/routeModel.dart';
import 'package:waste_management/service/auth_service.dart';

class RouteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  
  // Google Maps Directions API key
  static const String _googleMapsApiKey = 'AIzaSyD00mAQSg43OFLt36seV57ZupP-RLgXtGQ';







    Future<RouteModel> saveScheduledRoute(
    String name,
    String description,
    LatLng start,
    LatLng end,
    {
      String? assignedDriverId,
      String? driverName,
      String? driverContact,
      String? truckId,
      String scheduleFrequency = 'once',
      List<int> scheduleDays = const [],
      TimeOfDay? scheduleStartTime,
      TimeOfDay? scheduleEndTime,
      String wasteCategory = 'mixed',
    }
  ) async {
    try {
      // Get current user ID for permission control
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Fetch route directions from Google Maps Directions API
      final directionsResponse = await _fetchRouteDirections(start, end);

      // Calculate total distance
      double totalDistance = directionsResponse['routes'][0]['legs'][0]['distance']['value'] / 1000;

      // Extract route points and actual direction path
      List<Map<String, double>> coveragePoints = _extractRouteCoveragePoints(directionsResponse);
      List<Map<String, double>> actualDirectionPath = _extractActualDirectionPath(directionsResponse);

      // Generate a schedule ID if this is a recurring route
      String scheduleId = '';
      if (scheduleFrequency != 'once') {
        scheduleId = 'schedule_${DateTime.now().millisecondsSinceEpoch}';
      }
      
      // Calculate next scheduled occurrence
      DateTime? nextScheduledStart = _calculateNextScheduledDate(
        scheduleFrequency, 
        scheduleDays, 
        scheduleStartTime
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
      await _firestore.collection('waste_routes').doc(route.id).set(route.toMap());

      // Initialize route progress data
      await _firestore.collection('route_progress').doc(route.id).set({
        'completionPercentage': 0.0,
        'totalEstimatedTimeMinutes': 0.0,
        'remainingTimeMinutes': 0.0,
      });

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
    TimeOfDay? startTime
  ) {
    if (frequency == 'once' || days.isEmpty || startTime == null) {
      return null;
    }
    
    final now = DateTime.now();
    final todayWeekday = now.weekday % 7; // Convert to 0-6 range where 0 is Sunday
    
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
           (startTime.hour == now.hour && startTime.minute > now.minute)))) {
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
      startTime.minute
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
          startTime.minute
        );
      }
    }
    
    return nextDate;
  }
  
  // Get driver's routes for specific day of week
  Future<List<RouteModel>> getDriverRoutesForDay(String driverId, int dayOfWeek) async {
    try {
      final snapshot = await _firestore
          .collection('waste_routes')
          .where('assignedDriverId', isEqualTo: driverId)
          .where('isCancelled', isEqualTo: false)
          .get();
      
      List<RouteModel> scheduledRoutes = [];
      
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data();
        
        // Convert timestamps
        data['createdAt'] = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        data['startedAt'] = (data['startedAt'] as Timestamp?)?.toDate();
        data['pausedAt'] = (data['pausedAt'] as Timestamp?)?.toDate();
        data['resumedAt'] = (data['resumedAt'] as Timestamp?)?.toDate();
        data['completedAt'] = (data['completedAt'] as Timestamp?)?.toDate();
        data['cancelledAt'] = (data['cancelledAt'] as Timestamp?)?.toDate();
        data['nextScheduledStart'] = (data['nextScheduledStart'] as Timestamp?)?.toDate();
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
  Future<Map<int, List<RouteModel>>> getDriverWeeklySchedule(String driverId) async {
    Map<int, List<RouteModel>> weeklySchedule = {};
    
    // Initialize empty lists for each day
    for (int i = 0; i < 7; i++) {
      weeklySchedule[i] = [];
    }
    
    try {
      final snapshot = await _firestore
          .collection('waste_routes')
          .where('assignedDriverId', isEqualTo: driverId)
          .where('isCancelled', isEqualTo: false)
          .get();
      
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data();
        
        // Convert timestamps
        data['createdAt'] = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        data['startedAt'] = (data['startedAt'] as Timestamp?)?.toDate();
        data['pausedAt'] = (data['pausedAt'] as Timestamp?)?.toDate();
        data['resumedAt'] = (data['resumedAt'] as Timestamp?)?.toDate();
        data['completedAt'] = (data['completedAt'] as Timestamp?)?.toDate();
        data['cancelledAt'] = (data['cancelledAt'] as Timestamp?)?.toDate();
        data['nextScheduledStart'] = (data['nextScheduledStart'] as Timestamp?)?.toDate();
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
            int hourCompare = a.scheduleStartTime.hour.compareTo(b.scheduleStartTime.hour);
            if (hourCompare != 0) {
              return hourCompare;
            } else {
              return a.scheduleStartTime.minute.compareTo(b.scheduleStartTime.minute);
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
      final snapshot = await _firestore
          .collection('waste_routes')
          .where('wasteCategory', isEqualTo: category)
          .orderBy('createdAt', descending: true)
          .get();
      
      List<RouteModel> routes = [];
      
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data();
        
        // Convert timestamps
        data['createdAt'] = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        data['startedAt'] = (data['startedAt'] as Timestamp?)?.toDate();
        data['pausedAt'] = (data['pausedAt'] as Timestamp?)?.toDate();
        data['resumedAt'] = (data['resumedAt'] as Timestamp?)?.toDate();
        data['completedAt'] = (data['completedAt'] as Timestamp?)?.toDate();
        data['cancelledAt'] = (data['cancelledAt'] as Timestamp?)?.toDate();
        data['nextScheduledStart'] = (data['nextScheduledStart'] as Timestamp?)?.toDate();
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
        route.scheduleStartTime
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
      
      final snapshot = await _firestore
          .collection('waste_routes')
          .where('nextScheduledStart', isGreaterThanOrEqualTo: today)
          .where('nextScheduledStart', isLessThan: tomorrow)
          .where('isCancelled', isEqualTo: false)
          .get();
      
      List<RouteModel> routes = [];
      
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data();
        
        // Convert timestamps
        data['createdAt'] = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        data['startedAt'] = (data['startedAt'] as Timestamp?)?.toDate();
        data['pausedAt'] = (data['pausedAt'] as Timestamp?)?.toDate();
        data['resumedAt'] = (data['resumedAt'] as Timestamp?)?.toDate();
        data['completedAt'] = (data['completedAt'] as Timestamp?)?.toDate();
        data['cancelledAt'] = (data['cancelledAt'] as Timestamp?)?.toDate();
        data['nextScheduledStart'] = (data['nextScheduledStart'] as Timestamp?)?.toDate();
        data['lastCompleted'] = (data['lastCompleted'] as Timestamp?)?.toDate();
        
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
      
      final snapshot = await _firestore
          .collection('waste_routes')
          .where('nextScheduledStart', isGreaterThanOrEqualTo: today)
          .where('nextScheduledStart', isLessThan: nextWeek)
          .where('isCancelled', isEqualTo: false)
          .get();
      
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data();
        
        // Convert timestamps
        data['createdAt'] = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        data['startedAt'] = (data['startedAt'] as Timestamp?)?.toDate();
        data['pausedAt'] = (data['pausedAt'] as Timestamp?)?.toDate();
        data['resumedAt'] = (data['resumedAt'] as Timestamp?)?.toDate();
        data['completedAt'] = (data['completedAt'] as Timestamp?)?.toDate();
        data['cancelledAt'] = (data['cancelledAt'] as Timestamp?)?.toDate();
        data['nextScheduledStart'] = (data['nextScheduledStart'] as Timestamp?)?.toDate();
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
            route.nextScheduledStart!.day
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
    LatLng end,
    {String? assignedDriverId,
    String? driverName,
    String? driverContact,
    String? truckId}
  ) async {
    try {
      // Get current user ID for permission control
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Fetch route directions from Google Maps Directions API
      final directionsResponse = await _fetchRouteDirections(start, end);

      // Calculate total distance
      double totalDistance = directionsResponse['routes'][0]['legs'][0]['distance']['value'] / 1000; // Convert to kilometers

      // Extract route points and actual direction path
      List<Map<String, double>> coveragePoints = _extractRouteCoveragePoints(directionsResponse);
      List<Map<String, double>> actualDirectionPath = _extractActualDirectionPath(directionsResponse);

      // Create RouteModel
      final route = RouteModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(), // Generate unique ID
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
        truckId: truckId, scheduleStartTime: TimeOfDay(hour: 0, minute: 0), scheduleEndTime: TimeOfDay(hour: 0, minute: 0),
      );

      // Save to Firestore
      await _firestore.collection('waste_routes').doc(route.id).set(route.toMap());

      // Initialize route progress data
    await _firestore.collection('route_progress').doc(route.id).set({
      'completionPercentage': 0.0,
      'totalEstimatedTimeMinutes': 0.0,
      'remainingTimeMinutes': 0.0,
    });

      return route;
    } catch (e) {
      print('Error saving route with directions: $e');
      throw Exception('Failed to save route: $e');
    }
  }

  // Fetch route directions from Google Maps Directions API
  Future<Map<String, dynamic>> _fetchRouteDirections(LatLng start, LatLng end) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json?'
      'origin=${start.latitude},${start.longitude}'
      '&destination=${end.latitude},${end.longitude}'
      '&key=$_googleMapsApiKey'
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
  List<Map<String, double>> _extractRouteCoveragePoints(Map<String, dynamic> directionsResponse) {
    List<Map<String, double>> points = [];

    // Extract points from the route's polyline
    final route = directionsResponse['routes'][0];
    final leg = route['legs'][0];
    final steps = leg['steps'];

    // Add start point
    points.add({
      'lat': steps[0]['start_location']['lat'],
      'lng': steps[0]['start_location']['lng']
    });

    // Add intermediate points from each step
    for (var step in steps) {
      points.add({
        'lat': step['end_location']['lat'],
        'lng': step['end_location']['lng']
      });
    }

    return points;
  }

  // Extract the actual direction path from the polyline
  List<Map<String, double>> _extractActualDirectionPath(Map<String, dynamic> directionsResponse) {
    List<Map<String, double>> points = [];
    
    // Extract the encoded polyline
    final route = directionsResponse['routes'][0];
    final encodedPolyline = route['overview_polyline']['points'];
    
    // Decode the polyline
    final List<LatLng> decodedPoints = _decodePolyline(encodedPolyline);
    
    // Convert to our map format
    for (var point in decodedPoints) {
      points.add({
        'lat': point.latitude,
        'lng': point.longitude
      });
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
            data['createdAt'] = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            data['startedAt'] = (data['startedAt'] as Timestamp?)?.toDate();
            data['pausedAt'] = (data['pausedAt'] as Timestamp?)?.toDate();
            data['resumedAt'] = (data['resumedAt'] as Timestamp?)?.toDate();
            data['completedAt'] = (data['completedAt'] as Timestamp?)?.toDate();
            data['cancelledAt'] = (data['cancelledAt'] as Timestamp?)?.toDate();
            
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

  // Helper method to convert point data
  void _convertPointsData(Map<String, dynamic> data, String field) {
    if (data[field] != null) {
      final points = data[field] as List<dynamic>;
      data[field] = points.map((point) {
        if (point is Map) {
          return {
            'lat': (point['lat'] is num) ? (point['lat'] as num).toDouble() : 0.0,
            'lng': (point['lng'] is num) ? (point['lng'] as num).toDouble() : 0.0,
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
      DocumentSnapshot doc = await _firestore.collection('waste_routes').doc(routeId).get();
      
      if (!doc.exists) return null;
      
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      
      // Convert timestamps to DateTime
      data['createdAt'] = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      data['startedAt'] = (data['startedAt'] as Timestamp?)?.toDate();
      data['pausedAt'] = (data['pausedAt'] as Timestamp?)?.toDate();
      data['resumedAt'] = (data['resumedAt'] as Timestamp?)?.toDate();
      data['completedAt'] = (data['completedAt'] as Timestamp?)?.toDate();
      data['cancelledAt'] = (data['cancelledAt'] as Timestamp?)?.toDate();
      
      // Fix points type conversion
      _convertPointsData(data, 'coveragePoints');
      _convertPointsData(data, 'actualDirectionPath');
      
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
      final snapshot = await _firestore
          .collection('waste_routes')
          .where('assignedDriverId', isEqualTo: currentUser.uid)
          .where('isCancelled', isEqualTo: false)
          .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data();
        
        // Convert timestamps to DateTime
        data['createdAt'] = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        data['startedAt'] = (data['startedAt'] as Timestamp?)?.toDate();
        data['pausedAt'] = (data['pausedAt'] as Timestamp?)?.toDate();
        data['resumedAt'] = (data['resumedAt'] as Timestamp?)?.toDate();
        data['completedAt'] = (data['completedAt'] as Timestamp?)?.toDate();
        
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
        'completedAt': null,  // Clear completion timestamp
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
    } catch (e) {
      print('Error cancelling route: $e');
      throw Exception('Failed to cancel route: $e');
    }
  }

  // Update route progress
  Future<void> updateRouteProgress(
    String routeId, 
    LatLng position, 
    {List<LatLng>? coveredPoints, 
    double? distanceCovered,
    double? completionPercentage,
    DateTime? startTime}) async {
    try {
      Map<String, dynamic> data = {
        'routeId': routeId,
        'currentLat': position.latitude,
        'currentLng': position.longitude,
        'timestamp': FieldValue.serverTimestamp(),
      };
      
      // Update the completion percentage on the main route document if provided
      if (completionPercentage != null) {
        await _firestore.collection('waste_routes').doc(routeId).update({
          'currentProgressPercentage': completionPercentage,
        });
      }
      
      // Add optional state data if provided
      if (coveredPoints != null) {
        data['coveredPoints'] = coveredPoints.map((point) => 
          {'lat': point.latitude, 'lng': point.longitude}).toList();
      }
      
      if (distanceCovered != null) {
        data['distanceCovered'] = distanceCovered;
      }
      
      if (completionPercentage != null) {
        data['completionPercentage'] = completionPercentage;
      }
      
      if (startTime != null) {
        data['startTime'] = Timestamp.fromDate(startTime);
      }
      
      await _firestore.collection('route_progress').doc(routeId).set(
        data, 
        SetOptions(merge: true)
      );
      
      // Add to progress history
      await _firestore.collection('route_progress_history').add({
        'routeId': routeId,
        'lat': position.latitude,
        'lng': position.longitude,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating route progress: $e');
    }
  }

  // Get active routes
  Stream<List<RouteModel>> getActiveRoutes() {
    return _firestore
        .collection('waste_routes')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data();
        
        // Convert timestamps to DateTime
        data['createdAt'] = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        data['startedAt'] = (data['startedAt'] as Timestamp?)?.toDate();
        data['pausedAt'] = (data['pausedAt'] as Timestamp?)?.toDate();
        data['resumedAt'] = (data['resumedAt'] as Timestamp?)?.toDate();
        data['completedAt'] = (data['completedAt'] as Timestamp?)?.toDate();
        data['cancelledAt'] = (data['cancelledAt'] as Timestamp?)?.toDate();
        
        // Fix points type conversion
        _convertPointsData(data, 'coveragePoints');
        _convertPointsData(data, 'actualDirectionPath');
        
        return RouteModel.fromMap(data);
      }).toList();
    });
  }

  // Get completed routes that can be restarted
  Stream<List<RouteModel>> getCompletedRestartableRoutes() {
    return _firestore
        .collection('waste_routes')
        .where('isActive', isEqualTo: false)
        .where('isCancelled', isEqualTo: false)
        .where('completedAt', isNull: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data();
        
        // Convert timestamps to DateTime
        data['createdAt'] = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        data['startedAt'] = (data['startedAt'] as Timestamp?)?.toDate();
        data['pausedAt'] = (data['pausedAt'] as Timestamp?)?.toDate();
        data['resumedAt'] = (data['resumedAt'] as Timestamp?)?.toDate();
        data['completedAt'] = (data['completedAt'] as Timestamp?)?.toDate();
        data['cancelledAt'] = (data['cancelledAt'] as Timestamp?)?.toDate();
        
        // Fix points type conversion
        _convertPointsData(data, 'coveragePoints');
        _convertPointsData(data, 'actualDirectionPath');
        
        return RouteModel.fromMap(data);
      }).toList();
    });
  }

  // Get route progress
  Stream<LatLng?> getRouteProgress(String routeId) {
    return _firestore
        .collection('route_progress')
        .doc(routeId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      
      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
      return LatLng(
        data['currentLat']?.toDouble() ?? 0.0,
        data['currentLng']?.toDouble() ?? 0.0,
      );
    });
  }

  // Get detailed route progress state
  Future<Map<String, dynamic>?> getRouteProgressState(String routeId) async {
    try {
      final doc = await _firestore.collection('route_progress').doc(routeId).get();
      
      if (!doc.exists) return null;
      
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      
      // Convert Firestore data to appropriate types
      if (data['coveredPoints'] != null) {
        List<dynamic> points = data['coveredPoints'];
        data['coveredPoints'] = points.map((point) => 
          LatLng(
            (point['lat'] is num) ? (point['lat'] as num).toDouble() : 0.0,
            (point['lng'] is num) ? (point['lng'] as num).toDouble() : 0.0
          )).toList();
      }
      
      if (data['startTime'] != null) {
        data['startTime'] = (data['startTime'] as Timestamp).toDate();
      }
      
      return data;
    } catch (e) {
      print('Error getting route progress state: $e');
      return null;
    }
  }

   // Get all routes in progress for residents to view
  Stream<List<Map<String, dynamic>>> getActiveRoutesWithDriverInfo() {
    return _firestore
        .collection('waste_routes')
        .where('isActive', isEqualTo: true)
        .where('isPaused', isEqualTo: false)
        .where('isCancelled', isEqualTo: false)
        .snapshots()
        .asyncMap((snapshot) async {
          List<Map<String, dynamic>> activeRoutesWithProgress = [];
          
          for (var doc in snapshot.docs) {
            try {
              RouteModel route = RouteModel.fromMap({
                ...doc.data(),
                'createdAt': (doc.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                'startedAt': (doc.data()['startedAt'] as Timestamp?)?.toDate(),
                'pausedAt': (doc.data()['pausedAt'] as Timestamp?)?.toDate(),
                'resumedAt': (doc.data()['resumedAt'] as Timestamp?)?.toDate(),
                'completedAt': (doc.data()['completedAt'] as Timestamp?)?.toDate(),
                'cancelledAt': (doc.data()['cancelledAt'] as Timestamp?)?.toDate(),
              });
              
              // Convert points data
              Map<String, dynamic> data = doc.data();
              _convertPointsData(data, 'coveragePoints');
              _convertPointsData(data, 'actualDirectionPath');
              
              // Get current truck position
              var progressDoc = await _firestore.collection('route_progress').doc(route.id).get();
              LatLng? currentPosition;
              double? completionPercentage;
              
              if (progressDoc.exists && progressDoc.data() != null) {
                var progressData = progressDoc.data() as Map<String, dynamic>;
                currentPosition = LatLng(
                  progressData['currentLat']?.toDouble() ?? 0.0,
                  progressData['currentLng']?.toDouble() ?? 0.0
                );
                completionPercentage = progressData['completionPercentage']?.toDouble();
              }
              
              // Add to results
              activeRoutesWithProgress.add({
                'route': route,
                'currentPosition': currentPosition,
                'completionPercentage': completionPercentage ?? route.currentProgressPercentage ?? 0.0,
              });
            } catch (e) {
              print('Error processing active route: $e');
            }
          }
          
          return activeRoutesWithProgress;
        });
  }

  // Get routes assigned to a specific driver
  Stream<List<RouteModel>> getDriverRoutes(String driverId) {
    return _firestore
        .collection('waste_routes')
        .where('assignedDriverId', isEqualTo: driverId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          List<RouteModel> routes = [];
          
          for (var doc in snapshot.docs) {
            try {
              Map<String, dynamic> data = doc.data();
              
              // Convert timestamps to DateTime
              data['createdAt'] = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
              data['startedAt'] = (data['startedAt'] as Timestamp?)?.toDate();
              data['pausedAt'] = (data['pausedAt'] as Timestamp?)?.toDate();
              data['resumedAt'] = (data['resumedAt'] as Timestamp?)?.toDate();
              data['completedAt'] = (data['completedAt'] as Timestamp?)?.toDate();
              data['cancelledAt'] = (data['cancelledAt'] as Timestamp?)?.toDate();
              
              // Handle coveragePoints and actualDirectionPath conversion
              _convertPointsData(data, 'coveragePoints');
              _convertPointsData(data, 'actualDirectionPath');
              
              final route = RouteModel.fromMap(data);
              routes.add(route);
            } catch (e) {
              print('Error parsing driver route: $e');
            }
          }
          
          return routes;
        });
  }

  // Get driver's completed routes that can be restarted 
  Stream<List<RouteModel>> getDriverCompletedRoutes(String driverId) {
    return _firestore
        .collection('waste_routes')
        .where('assignedDriverId', isEqualTo: driverId)
        .where('isActive', isEqualTo: false)
        .where('completedAt', isNull: false)
        .where('isCancelled', isEqualTo: false)
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          List<RouteModel> routes = [];
          
          for (var doc in snapshot.docs) {
            try {
              Map<String, dynamic> data = doc.data();
              
              // Convert timestamps to DateTime
              data['createdAt'] = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
              data['startedAt'] = (data['startedAt'] as Timestamp?)?.toDate();
              data['pausedAt'] = (data['pausedAt'] as Timestamp?)?.toDate();
              data['resumedAt'] = (data['resumedAt'] as Timestamp?)?.toDate();
              data['completedAt'] = (data['completedAt'] as Timestamp?)?.toDate();
              data['cancelledAt'] = (data['cancelledAt'] as Timestamp?)?.toDate();
              
              // Handle coveragePoints and actualDirectionPath conversion
              _convertPointsData(data, 'coveragePoints');
              _convertPointsData(data, 'actualDirectionPath');
              
              final route = RouteModel.fromMap(data);
              routes.add(route);
            } catch (e) {
              print('Error parsing driver completed route: $e');
            }
          }
          
          return routes;
        });
  }

  // Assign driver to route
  // Assign driver to route
  Future<void> assignDriverToRoute(String routeId, String driverId, String driverName, String driverContact, String truckId) async {
    try {
      await _firestore.collection('waste_routes').doc(routeId).update({
        'assignedDriverId': driverId,
        'driverName': driverName,
        'driverContact': driverContact,
        'truckId': truckId,
      });
      
      // Record assignment in history
      await _firestore.collection('route_history').add({
        'routeId': routeId,
        'action': 'assign_driver',
        'driverId': driverId,
        'driverName': driverName,
        'truckId': truckId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error assigning driver to route: $e');
      throw Exception('Failed to assign driver to route: $e');
    }
  }

  // Unassign driver from route
  Future<void> unassignDriverFromRoute(String routeId) async {
    try {
      await _firestore.collection('waste_routes').doc(routeId).update({
        'assignedDriverId': null,
        'driverName': null,
        'driverContact': null,
        'truckId': null,
      });
      
      // Record unassignment in history
      await _firestore.collection('route_history').add({
        'routeId': routeId,
        'action': 'unassign_driver',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error unassigning driver from route: $e');
      throw Exception('Failed to unassign driver from route: $e');
    }
  }

  // Get route history
  Stream<List<Map<String, dynamic>>> getRouteHistory(String routeId) {
    return _firestore
        .collection('route_history')
        .where('routeId', isEqualTo: routeId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            Map<String, dynamic> data = doc.data();
            
            // Convert timestamp to DateTime
            data['timestamp'] = (data['timestamp'] as Timestamp?)?.toDate();
            data['id'] = doc.id;
            
            return data;
          }).toList();
        });
  }

  // Get route progress history
  Stream<List<LatLng>> getRouteProgressHistory(String routeId) {
    return _firestore
        .collection('route_progress_history')
        .where('routeId', isEqualTo: routeId)
        .orderBy('timestamp')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            Map<String, dynamic> data = doc.data();
            
            return LatLng(
              data['lat']?.toDouble() ?? 0.0,
              data['lng']?.toDouble() ?? 0.0,
            );
          }).toList();
        });
  }

  // Delete a route and all related data
  Future<void> deleteRoute(String routeId) async {
    try {
      // Delete route progress data
      await _firestore.collection('route_progress').doc(routeId).delete();
      
      // Delete the route document
      await _firestore.collection('waste_routes').doc(routeId).delete();
      
      // Delete route history (in a batched operation)
      final historyDocs = await _firestore
          .collection('route_history')
          .where('routeId', isEqualTo: routeId)
          .get();
      
      final progressHistoryDocs = await _firestore
          .collection('route_progress_history')
          .where('routeId', isEqualTo: routeId)
          .get();
      
      // Delete in batches
      WriteBatch batch = _firestore.batch();
      
      for (var doc in historyDocs.docs) {
        batch.delete(doc.reference);
      }
      
      for (var doc in progressHistoryDocs.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
    } catch (e) {
      print('Error deleting route: $e');
      throw Exception('Failed to delete route: $e');
    }
  }

  // Get route analytics
  Future<Map<String, dynamic>> getRouteAnalytics(String routeId) async {
    try {
      // Get route data
      RouteModel? route = await getRoute(routeId);
      if (route == null) throw Exception('Route not found');
      
      // Get progress history
      final progressHistoryDocs = await _firestore
          .collection('route_progress_history')
          .where('routeId', isEqualTo: routeId)
          .orderBy('timestamp')
          .get();
      
      // Calculate analytics
      int totalPoints = progressHistoryDocs.docs.length;
      double? startLat, startLng, endLat, endLng;
      DateTime? startTime, endTime;
      
      if (totalPoints > 0) {
        // First point
        var firstDoc = progressHistoryDocs.docs.first;
        startLat = firstDoc.data()['lat'];
        startLng = firstDoc.data()['lng'];
        startTime = (firstDoc.data()['timestamp'] as Timestamp).toDate();
        
        // Last point
        var lastDoc = progressHistoryDocs.docs.last;
        endLat = lastDoc.data()['lat'];
        endLng = lastDoc.data()['lng'];
        endTime = (lastDoc.data()['timestamp'] as Timestamp).toDate();
      }
      
      // Calculate duration if applicable
      Duration? duration;
      if (startTime != null && endTime != null) {
        duration = endTime.difference(startTime);
      }
      
      return {
        'routeId': routeId,
        'routeName': route.name,
        'totalTrackedPoints': totalPoints,
        'startPosition': (startLat != null && startLng != null) 
            ? {'lat': startLat, 'lng': startLng} 
            : null,
        'endPosition': (endLat != null && endLng != null) 
            ? {'lat': endLat, 'lng': endLng} 
            : null,
        'startTime': startTime,
        'endTime': endTime,
        'durationInMinutes': duration?.inMinutes,
        'plannedDistance': route.distance,
        'isCompleted': route.completedAt != null,
        'completionPercentage': route.currentProgressPercentage ?? 0.0,
      };
    } catch (e) {
      print('Error getting route analytics: $e');
      throw Exception('Failed to get route analytics: $e');
    }
  }
  
  // Method to restart a completed route without closing
  Future<void> resetAndRestartRoute(String routeId) async {
    try {
      await _firestore.collection('waste_routes').doc(routeId).update({
        'isActive': true,
        'isPaused': false,
        'isCancelled': false,
        'startedAt': FieldValue.serverTimestamp(),
        'completedAt': null,  // Remove completion timestamp
        'currentProgressPercentage': 0.0, // Reset progress
      });
      
      // Record route reset in history
      await _firestore.collection('route_history').add({
        'routeId': routeId,
        'action': 'reset_and_restart',
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      // Reset route progress data
      await _firestore.collection('route_progress').doc(routeId).set({
        'routeId': routeId,
        'completionPercentage': 0.0,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error resetting and restarting route: $e');
      throw Exception('Failed to reset and restart route: $e');
    }
  }
  
  // Get all routes that can be started or restarted
  Future<List<RouteModel>> getStartableRoutes() async {
    try {
      // Get current user ID for permission control
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Query for routes assigned to this driver that are:
      // 1. Not active and not cancelled (new routes)
      // 2. Completed routes (for restarting)
      final snapshot = await _firestore
          .collection('waste_routes')
          .where('assignedDriverId', isEqualTo: currentUser.uid)
          .where('isCancelled', isEqualTo: false)
          .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data();
        
        // Convert timestamps to DateTime
        data['createdAt'] = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        data['startedAt'] = (data['startedAt'] as Timestamp?)?.toDate();
        data['pausedAt'] = (data['pausedAt'] as Timestamp?)?.toDate();
        data['resumedAt'] = (data['resumedAt'] as Timestamp?)?.toDate();
        data['completedAt'] = (data['completedAt'] as Timestamp?)?.toDate();
        
        // Fix points type conversion
        _convertPointsData(data, 'coveragePoints');
        _convertPointsData(data, 'actualDirectionPath');
        
        return RouteModel.fromMap(data);
      }).toList();
    } catch (e) {
      print('Error getting startable routes: $e');
      throw Exception('Failed to load startable routes: $e');
    }
  }

  Future<Map<String, dynamic>> getRouteTimeEstimation(String routeId) async {
  try {
    // Fetch route progress data from Firestore
    final progressDoc = await _firestore.collection('route_progress').doc(routeId).get();
    if (!progressDoc.exists) {
      // Return default values if progress data is not found
      return {
        'completionPercentage': 0.0,
        'totalEstimatedTimeMinutes': 0.0,
        'remainingTimeMinutes': 0.0,
        'estimatedCompletionTime': DateTime.now(),
      };
    }

    final progressData = progressDoc.data() as Map<String, dynamic>;

    // Calculate time estimation
    final double completionPercentage = progressData['completionPercentage'] ?? 0.0;
    final double totalEstimatedTimeMinutes = progressData['totalEstimatedTimeMinutes'] ?? 0.0;
    final double remainingTimeMinutes = totalEstimatedTimeMinutes * (1 - (completionPercentage / 100));

    // Return the estimation data
    return {
      'completionPercentage': completionPercentage,
      'totalEstimatedTimeMinutes': totalEstimatedTimeMinutes,
      'remainingTimeMinutes': remainingTimeMinutes,
      'estimatedCompletionTime': DateTime.now().add(Duration(minutes: remainingTimeMinutes.toInt())),
    };
  } catch (e) {
    print('Error fetching route time estimation: $e');
    throw Exception('Failed to fetch route time estimation: $e');
  }
}

Future<RouteModel?> getDriverActiveRoute(String driverId) async {
  try {
    final snapshot = await _firestore
        .collection('waste_routes')
        .where('assignedDriverId', isEqualTo: driverId)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      
      // Convert timestamps to DateTime
      data['createdAt'] = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      data['startedAt'] = (data['startedAt'] as Timestamp?)?.toDate();
      data['pausedAt'] = (data['pausedAt'] as Timestamp?)?.toDate();
      data['resumedAt'] = (data['resumedAt'] as Timestamp?)?.toDate();
      data['completedAt'] = (data['completedAt'] as Timestamp?)?.toDate();
      data['cancelledAt'] = (data['cancelledAt'] as Timestamp?)?.toDate();

      // Handle coveragePoints and actualDirectionPath conversion
      _convertPointsData(data, 'coveragePoints');
      _convertPointsData(data, 'actualDirectionPath');

      return RouteModel.fromMap(data);
    }
    return null;
  } catch (e) {
    print('Error fetching active route for driver: $e');
    throw Exception('Failed to fetch active route: $e');
  }
}
  
}