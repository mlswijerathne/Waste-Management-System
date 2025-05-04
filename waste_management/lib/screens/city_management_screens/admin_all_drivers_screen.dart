import 'package:flutter/material.dart';
import 'package:waste_management/models/userModel.dart';
import 'package:waste_management/service/auth_service.dart';

class AdminAllDriversScreen extends StatefulWidget {
  const AdminAllDriversScreen({super.key});

  @override
  State<AdminAllDriversScreen> createState() => _AdminAllDriversScreenState();
}

class _AdminAllDriversScreenState extends State<AdminAllDriversScreen> {
  final AuthService _authService = AuthService();
  List<UserModel> _drivers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDrivers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Use the existing function in AuthService to get all drivers
      final drivers = await _authService.getDrivers();

      // Filter based on search query if needed
      if (_searchQuery.isNotEmpty) {
        _drivers =
            drivers
                .where(
                  (driver) =>
                      driver.name.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ) ||
                      driver.email.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ) ||
                      driver.address.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ),
                )
                .toList();
      } else {
        _drivers = drivers;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load drivers: ${e.toString()}')),
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
    _loadDrivers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'All Drivers',
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

          // List of drivers
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF59A867),
                      ),
                    )
                    : _drivers.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.drive_eta_outlined,
                            size: 60,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? 'No drivers found'
                                : 'No drivers match your search',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: _loadDrivers,
                      color: const Color(0xFF59A867),
                      child: ListView.builder(
                        itemCount: _drivers.length,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemBuilder: (context, index) {
                          final driver = _drivers[index];
                          return _buildDriverCard(driver);
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverCard(UserModel driver) {
    final bool hasLocation =
        driver.latitude != null && driver.longitude != null;

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
                  child: const Icon(Icons.drive_eta, color: Color(0xFF59A867)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        driver.email,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(Icons.badge, 'NIC', driver.nic),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.phone, 'Contact', driver.contactNumber),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.home, 'Address', driver.address),
            const SizedBox(height: 8),
            if (hasLocation)
              _buildInfoRow(
                Icons.pin_drop,
                'GPS',
                'Lat: ${driver.latitude!.toStringAsFixed(6)}, Lng: ${driver.longitude!.toStringAsFixed(6)}',
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              
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
