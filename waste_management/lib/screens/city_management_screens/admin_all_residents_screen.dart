import 'package:flutter/material.dart';
import 'package:waste_management/models/userModel.dart';
import 'package:waste_management/service/auth_service.dart';

class AdminAllResidentsScreen extends StatefulWidget {
  const AdminAllResidentsScreen({super.key});

  @override
  State<AdminAllResidentsScreen> createState() =>
      _AdminAllResidentsScreenState();
}

class _AdminAllResidentsScreenState extends State<AdminAllResidentsScreen> {
  final AuthService _authService = AuthService();
  List<UserModel> _residents = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadResidents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadResidents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Use the existing function in AuthService to get all residents
      // Create a query to Firestore to get all users with role 'resident'
      final snapshot = await _authService.getResidentsWithLocations();

      // Filter based on search query if needed
      if (_searchQuery.isNotEmpty) {
        _residents =
            snapshot
                .where(
                  (resident) =>
                      resident.name.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ) ||
                      resident.email.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ) ||
                      resident.address.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ),
                )
                .toList();
      } else {
        _residents = snapshot;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load residents: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
    });
    _loadResidents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'All Residents',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF59A867),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, email, or address',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: _onSearch,
            ),
          ),

          // List of residents
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF59A867),
                      ),
                    )
                    : _residents.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.people_alt_outlined,
                            size: 60,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? 'No residents found'
                                : 'No residents match your search',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: _loadResidents,
                      color: const Color(0xFF59A867),
                      child: ListView.builder(
                        itemCount: _residents.length,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemBuilder: (context, index) {
                          final resident = _residents[index];
                          return _buildResidentCard(resident);
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildResidentCard(UserModel resident) {
    final bool hasLocation =
        resident.latitude != null && resident.longitude != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF59A867).withOpacity(0.2),
                  child: const Icon(Icons.person, color: Color(0xFF59A867)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resident.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        resident.email,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                hasLocation
                    ? const Icon(Icons.location_on, color: Color(0xFF59A867))
                    : const Icon(Icons.location_off, color: Colors.grey),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(Icons.badge, 'NIC', resident.nic),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.phone, 'Contact', resident.contactNumber),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.home, 'Address', resident.address),
            const SizedBox(height: 8),
            if (hasLocation)
              _buildInfoRow(
                Icons.pin_drop,
                'GPS',
                'Lat: ${resident.latitude!.toStringAsFixed(6)}, Lng: ${resident.longitude!.toStringAsFixed(6)}',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(value, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }
}
