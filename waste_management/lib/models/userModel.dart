class UserModel {
  final String uid;
  final String name;
  final String role; // 'resident', 'driver', or 'cityManagement'
  final String nic;
  final String address;
  final String contactNumber; // Must have exactly 10 digits
  final String email;
  final double? latitude;    // New field for location
  final double? longitude; 


  UserModel({
    required this.uid,
    required this.name,
    required this.role,
    required this.nic,
    required this.address,
    required this.contactNumber,
    required this.email,
    this.latitude,   // Optional during creation
    this.longitude, 
    
  }) {
    // Validate contact number
    if (contactNumber.length != 10 ||
        !RegExp(r'^[0-9]+$').hasMatch(contactNumber)) {
      throw ArgumentError('Contact number must be exactly 10 digits.');
    }

    // Validate email
    if (!RegExp(
      r'^[\w-]+(\.[\w-]+)*@([\w-]+\.)+[a-zA-Z]{2,7}$',
    ).hasMatch(email)) {
      throw ArgumentError('Invalid email format.');
    }
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? '',
      nic: map['nic'] ?? '',
      address: map['address'] ?? '',
      contactNumber: map['contactNumber'] ?? '',
      email: map['email'] ?? '',
      latitude: map['latitude'],
      longitude: map['longitude'],
   
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'role': role,
      'nic': nic,
      'address': address,
      'contactNumber': contactNumber,
      'email': email,
      'latitude': latitude,
      'longitude': longitude,
    
    };
  }
}
