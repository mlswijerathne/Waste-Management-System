import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:waste_management/models/specialGarbageRequestModel.dart';
import 'package:waste_management/models/userModel.dart';
import 'package:waste_management/service/special_Garbage_Request_service.dart';
import 'package:waste_management/service/auth_service.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:http/http.dart' as http;

class AdminAssignDriverScreen extends StatefulWidget {
  final String requestId;

  const AdminAssignDriverScreen({Key? key, required this.requestId})
    : super(key: key);

  @override
  State<AdminAssignDriverScreen> createState() =>
      _AdminAssignDriverScreenState();
}

class _AdminAssignDriverScreenState extends State<AdminAssignDriverScreen> {
  final SpecialGarbageRequestService _requestService =
      SpecialGarbageRequestService();
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  SpecialGarbageRequestModel? _request;
  List<UserModel> _drivers = [];
  UserModel? _selectedDriver;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load request details
      final request = await _requestService.getRequestById(widget.requestId);

      if (request == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Request not found')));
        Navigator.pop(context);
        return;
      }

      // Load all drivers using AuthService
      final List<UserModel> drivers = await _authService.getDrivers();

      setState(() {
        _request = request;
        _drivers = drivers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
    }
  }

  Future<void> _assignDriver() async {
    if (_selectedDriver == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a driver')));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final success = await _requestService.assignRequestToDriver(
        requestId: widget.requestId,
        driverId: _selectedDriver!.uid,
        driverName: _selectedDriver!.name,
      );

      setState(() {
        _isSubmitting = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driver assigned successfully')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to assign driver')),
        );
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error assigning driver: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assign Driver')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRequestDetails(),
                    const SizedBox(height: 24),
                    _buildDriverSelector(),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _assignDriver,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child:
                            _isSubmitting
                                ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Text(
                                  'ASSIGN DRIVER',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildRequestDetails() {
    if (_request == null) return const SizedBox();

    final DateFormat formatter = DateFormat('MMM dd, yyyy - hh:mm a');

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Request Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            const SizedBox(height: 8),
            _buildDetailRow('Request ID:', _request!.id.substring(0, 8)),
            _buildDetailRow('Status:', _request!.status.toUpperCase()),
            _buildDetailRow('Type:', _request!.garbageType),
            _buildDetailRow('Location:', _request!.location),
            _buildDetailRow(
              'Coordinates:',
              '${_request!.latitude}, ${_request!.longitude}',
            ),
            _buildDetailRow('Resident:', _request!.residentName),
            _buildDetailRow('Description:', _request!.description),
            _buildDetailRow(
              'Requested Time:',
              formatter.format(_request!.requestedTime),
            ),
            if (_request!.estimatedWeight != null)
              _buildDetailRow(
                'Est. Weight:',
                '${_request!.estimatedWeight} kg',
              ),
            if (_request!.notes != null && _request!.notes!.isNotEmpty)
              _buildDetailRow('Notes:', _request!.notes!),
            if (_request!.imageUrl != null &&
                _request!.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Image:'),
              const SizedBox(height: 8),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: FutureBuilder<Uint8List?>(
                  future: _getImageBytes(_request!.imageUrl!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, size: 64),
                            SizedBox(height: 8),
                            Text('Image could not be loaded', 
                               style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        snapshot.data!,
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverSelector() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Driver',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            const SizedBox(height: 8),
            if (_drivers.isEmpty)
              const Text('No drivers available')
            else
              DropdownButtonFormField<UserModel>(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  labelText: 'Select Driver',
                ),
                value: _selectedDriver,
                items:
                    _drivers.map((driver) {
                      return DropdownMenuItem<UserModel>(
                        value: driver,
                        child: Text(driver.name),
                      );
                    }).toList(),
                onChanged: (UserModel? value) {
                  setState(() {
                    _selectedDriver = value;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<Uint8List?> _getImageBytes(String imageUrl) async {
    try {
      // Debug logging - remove in production
      print('Loading image from: ${imageUrl.substring(0, min(50, imageUrl.length))}...');
      
      if (imageUrl.startsWith('http')) {
        // Handle network images
        try {
          final response = await http.get(Uri.parse(imageUrl));
          if (response.statusCode == 200) {
            return response.bodyBytes;
          } else {
            print('HTTP error: ${response.statusCode}');
            return null;
          }
        } catch (e) {
          print('Error fetching network image: $e');
          return null;
        }
      } else {
        // Handle base64 images
        try {
          // Remove data URI prefix if present
          String sanitized = imageUrl;
          if (imageUrl.contains(',')) {
            sanitized = imageUrl.split(',')[1];
          }
          
          // Try to decode directly first
          try {
            return base64Decode(sanitized);
          } catch (e) {
            print('Initial base64 decode failed: $e');
            
            // Try with padding
            while (sanitized.length % 4 != 0) {
              sanitized += '=';
            }
            
            // Try decoding again
            try {
              return base64Decode(sanitized);
            } catch (e) {
              print('Base64 decode with padding failed: $e');
              
              // One more attempt with URL-safe characters replaced
              sanitized = sanitized.replaceAll('-', '+').replaceAll('_', '/');
              while (sanitized.length % 4 != 0) {
                sanitized += '=';
              }
              return base64Decode(sanitized);
            }
          }
        } catch (e) {
          print('All base64 decode attempts failed: $e');
          return null;
        }
      }
    } catch (e) {
      print('Error processing image: $e');
      return null;
    }
  }
}