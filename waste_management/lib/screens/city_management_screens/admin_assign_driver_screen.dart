import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:waste_management/models/specialGarbageRequestModel.dart';
import 'package:waste_management/models/userModel.dart';
import 'package:waste_management/service/special_Garbage_Request_service.dart';
import 'package:waste_management/service/auth_service.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:typed_data';

class AdminAssignDriverScreen extends StatefulWidget {
  final String requestId;

  const AdminAssignDriverScreen({
    Key? key,
    required this.requestId,
  }) : super(key: key);

  @override
  State<AdminAssignDriverScreen> createState() => _AdminAssignDriverScreenState();
}

class _AdminAssignDriverScreenState extends State<AdminAssignDriverScreen> {
  final SpecialGarbageRequestService _requestService = SpecialGarbageRequestService();
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request not found')),
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    }
  }

  Future<void> _assignDriver() async {
    if (_selectedDriver == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a driver')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error assigning driver: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Driver'),
      ),
      body: _isLoading
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
                      child: _isSubmitting
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            _buildDetailRow('Request ID:', _request!.id.substring(0, 8)),
            _buildDetailRow('Status:', _request!.status.toUpperCase()),
            _buildDetailRow('Type:', _request!.garbageType),
            _buildDetailRow('Location:', _request!.location),
            _buildDetailRow('Coordinates:', '${_request!.latitude}, ${_request!.longitude}'),
            _buildDetailRow('Resident:', _request!.residentName),
            _buildDetailRow('Description:', _request!.description),
            _buildDetailRow('Requested Time:', formatter.format(_request!.requestedTime)),
            if (_request!.estimatedWeight != null)
              _buildDetailRow('Est. Weight:', '${_request!.estimatedWeight} kg'),
            if (_request!.notes != null && _request!.notes!.isNotEmpty)
              _buildDetailRow('Notes:', _request!.notes!),
            if (_request!.imageUrl != null && _request!.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Image:'),
              const SizedBox(height: 8),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _request!.imageUrl!.startsWith('data:image')
                    ? Image.memory(
                        _convertBase64ToUint8List(_request!.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        _request!.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, obj, trace) => const Center(
                          child: Icon(Icons.broken_image, size: 64),
                        ),
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
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            if (_drivers.isEmpty)
              const Text('No drivers available')
            else
              DropdownButtonFormField<UserModel>(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  labelText: 'Select Driver',
                ),
                value: _selectedDriver,
                items: _drivers.map((driver) {
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

  Uint8List _convertBase64ToUint8List(String base64String) {
    String sanitized = base64String;
    if (base64String.contains(',')) {
      sanitized = base64String.split(',')[1];
    }
    return base64Decode(sanitized);
  }
}