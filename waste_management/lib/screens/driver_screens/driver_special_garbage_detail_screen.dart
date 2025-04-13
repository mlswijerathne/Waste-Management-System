import 'package:flutter/material.dart';
import 'package:waste_management/models/specialGarbageRequestModel.dart';
import 'package:waste_management/service/special_Garbage_Request_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverSpecialGarbageDetailScreen extends StatefulWidget {
  final String requestId;

  const DriverSpecialGarbageDetailScreen({
    Key? key,
    required this.requestId,
  }) : super(key: key);

  @override
  State<DriverSpecialGarbageDetailScreen> createState() => _DriverSpecialGarbageDetailScreenState();
}

class _DriverSpecialGarbageDetailScreenState extends State<DriverSpecialGarbageDetailScreen> {
  final SpecialGarbageRequestService _requestService = SpecialGarbageRequestService();
  bool _isLoading = true;
  bool _isMarking = false;
  SpecialGarbageRequestModel? _request;
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadRequestDetails();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadRequestDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final request = await _requestService.getRequestById(widget.requestId);
      setState(() {
        _request = request;
        _isLoading = false;
        
        // Pre-fill weight field if available
        if (request?.estimatedWeight != null) {
          _weightController.text = request!.estimatedWeight.toString();
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading request details: $e')),
        );
      }
    }
  }

  Future<void> _markAsCollected() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isMarking = true;
    });

    try {
      double? weight;
      if (_weightController.text.isNotEmpty) {
        weight = double.tryParse(_weightController.text);
      }

      final success = await _requestService.markRequestCollected(
        requestId: widget.requestId,
        actualWeight: weight,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request marked as collected successfully')),
          );
          Navigator.pop(context, true);
        }
      } else {
        setState(() {
          _isMarking = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to mark request as collected')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isMarking = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _openMapsNavigation() async {
    if (_request == null) return;
    
    final lat = _request!.latitude;
    final lng = _request!.longitude;
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    
    try {
      if (await canLaunch(url)) {
        await launch(url);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch navigation')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Navigation error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRequestDetails,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _request == null
              ? const Center(child: Text('Request not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusCard(),
                      const SizedBox(height: 16),
                      _buildDetailsCard(),
                      const SizedBox(height: 16),
                      if (_request!.imageUrl != null && _request!.imageUrl!.isNotEmpty) ...[
                        _buildImageCard(),
                        const SizedBox(height: 16),
                      ],
                      _buildCollectionForm(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatusCard() {
    final DateFormat formatter = DateFormat('MMM dd, yyyy - hh:mm a');
    String assignedTime = "Not assigned";
    
    if (_request?.assignedTime != null) {
      try {
        assignedTime = formatter.format(_request!.assignedTime!);
      } catch (e) {
        assignedTime = "Invalid date";
      }
    }
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Request #${_request!.id.substring(0, 8)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _request!.status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Requested: ${formatter.format(_request!.requestedTime)}',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 4),
            Text(
              'Assigned: $assignedTime',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Request Details',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.category, 'Type', _request!.garbageType),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.description, 'Description', _request!.description),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.location_on,
              'Location',
              _request!.location,
              trailing: IconButton(
                icon: const Icon(Icons.directions, color: Colors.blue),
                onPressed: _openMapsNavigation,
                tooltip: 'Navigate',
              ),
            ),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.person, 'Resident', _request!.residentName),
            if (_request!.estimatedWeight != null) ...[
              const SizedBox(height: 8),
              _buildDetailRow(
                Icons.scale,
                'Estimated Weight',
                '${_request!.estimatedWeight} kg',
              ),
            ],
            if (_request!.notes != null && _request!.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildDetailRow(Icons.note, 'Notes', _request!.notes!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Widget? trailing}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildImageCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Garbage Image',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildImageWidget(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWidget() {
    try {
      // Try to decode the base64 image
      if (_request?.imageUrl != null && _request!.imageUrl!.isNotEmpty) {
        if (_request!.imageUrl!.startsWith('http')) {
          // It's a URL, not base64
          return Image.network(
            _request!.imageUrl!,
            fit: BoxFit.cover,
            height: 200,
            width: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                heightFactor: 2,
                child: Text('Failed to load image'),
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                heightFactor: 2,
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / 
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
          );
        } else {
          // Try to decode base64
          try {
            final uri = Uri.parse(_request!.imageUrl!);
            if (uri.data != null) {
              return Image.memory(
                uri.data!.contentAsBytes(),
                fit: BoxFit.cover,
                height: 200,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    heightFactor: 2,
                    child: Text('Failed to decode image'),
                  );
                },
              );
            }
          } catch (e) {
            print("Error decoding base64 image: $e");
          }
        }
      }
      
      // Fallback
      return const Center(
        heightFactor: 2,
        child: Text('Image unavailable'),
      );
    } catch (e) {
      print("Error displaying image: $e");
      return const Center(
        heightFactor: 2,
        child: Text('Error loading image'),
      );
    }
  }

  Widget _buildCollectionForm() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mark as Collected',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _weightController,
                decoration: const InputDecoration(
                  labelText: 'Actual Weight (kg)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.scale),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final weight = double.tryParse(value);
                    if (weight == null || weight <= 0) {
                      return 'Please enter a valid weight';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Collection Notes',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                  hintText: 'Optional notes about the collection',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isMarking ? null : _markAsCollected,
                  icon: _isMarking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle),
                  label: Text(_isMarking ? 'Processing...' : 'MARK AS COLLECTED'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}