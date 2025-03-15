class UserModel {
  final String uid;
  final String name;
  final String role; // 'resident', 'driver', or 'cityManagement'
  final String username;
  final String nic;
  final String address;
  final String contactNumber; // Must have exactly 10 digits
  final String email;

  UserModel({
    required this.uid,
    required this.name,
    required this.role,
    required this.username,
    required this.nic,
    required this.address,
    required this.contactNumber,
    required this.email,
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
      username: map['username'] ?? '',
      nic: map['nic'] ?? '',
      address: map['address'] ?? '',
      contactNumber: map['contactNumber'] ?? '',
      email: map['email'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'role': role,
      'username': username,
      'nic': nic,
      'address': address,
      'contactNumber': contactNumber,
      'email': email,
    };
  }
}
