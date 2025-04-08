import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waste_management/models/userModel.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Admin credentials
  static const String adminEmail = "admin@wastemanagement.com";
  static const String adminPassword = "admin123456";

  Future<bool> isUserResident() async {
    try {
      UserModel? user = await getCurrentUser();
      return user?.role == 'resident';
    } catch (e) {
      print('Error checking user role: $e');
      return false;
    }
  }

  //get user location
  Future<bool> updateUserLocation(String userId, double latitude, double longitude) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'latitude': latitude,
        'longitude': longitude,
      });
      return true;
    } catch (e) {
      print('Error updating user location: $e');
      return false;
    }
  }


  // Get current user data
  Future<UserModel?> getCurrentUser() async {
    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot doc =
            await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          return UserModel.fromMap(doc.data() as Map<String, dynamic>);
        }
      }
      return null;
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  // Get all drivers
  Future<List<UserModel>> getDrivers() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'driver')
          .get();
          
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching drivers: $e');
      rethrow;
    }
  }
  
  // Get driver by ID
  Future<UserModel?> getDriverById(String driverId) async {
    try {
      final DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(driverId)
          .get();
          
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error fetching driver: $e');
      rethrow;
    }
  }

  // Sign up with email and password
  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String role, // Only 'resident' or 'driver' allowed
    required String name,
    required String nic,
    required String address,
    required String contactNumber,
  }) async {
    try {
      // Check if role is valid
      if (role != 'resident' && role != 'driver') {
        throw ArgumentError('Role must be either resident or driver');
      }

      // Validate contact number and email before proceeding
      if (contactNumber.length != 10 ||
          !RegExp(r'^[0-9]+$').hasMatch(contactNumber)) {
        throw ArgumentError('Contact number must be exactly 10 digits.');
      }
      if (!RegExp(
        r'^[\w-]+(\.[\w-]+)*@([\w-]+\.)+[a-zA-Z]{2,7}$',
      ).hasMatch(email)) {
        throw ArgumentError('Invalid email format.');
      }

      // Create user in Firebase Auth
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        // Create user model
        UserModel userModel = UserModel(
          uid: result.user!.uid,
          name: name,
          role: role,
          nic: nic,
          address: address,
          contactNumber: contactNumber,
          email: email,
        );

        // Save user data to Firestore
        await _firestore
            .collection('users')
            .doc(result.user!.uid)
            .set(userModel.toMap());

        return userModel;
      }
      return null;
    } catch (e) {
      print('Error during sign up: $e');
      rethrow; // Rethrow to handle in UI
    }
  }

  // Sign in with email and password
  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      // Check if attempting to sign in as admin
      if (email == adminEmail && password == adminPassword) {
        // Sign in with admin credentials
        UserCredential result = await _auth.signInWithEmailAndPassword(
          email: adminEmail,
          password: adminPassword,
        );
        
        // If admin doesn't exist in auth, create it
        if (result.user != null) {
          // Check if admin exists in Firestore
          DocumentSnapshot doc =
              await _firestore.collection('users').doc(result.user!.uid).get();
          
          if (!doc.exists) {
            // Create admin user model
            UserModel adminModel = UserModel(
              uid: result.user!.uid,
              name: "Administrator",
              role: "cityManagement",
              nic: "ADMIN",
              address: "City Management Office",
              contactNumber: "0000000000", // 10 digits as required
              email: adminEmail,
            );
            
            // Save admin data to Firestore
            await _firestore
                .collection('users')
                .doc(result.user!.uid)
                .set(adminModel.toMap());
                
            return adminModel;
          } else {
            return UserModel.fromMap(doc.data() as Map<String, dynamic>);
          }
        }
      } else {
        // Regular user sign in
        UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        if (result.user != null) {
          DocumentSnapshot doc =
              await _firestore.collection('users').doc(result.user!.uid).get();

          if (doc.exists) {
            return UserModel.fromMap(doc.data() as Map<String, dynamic>);
          }
        }
      }
      return null;
    } catch (e) {
      print('Error during sign in: $e');
      rethrow; // Rethrow to handle in UI
    }
  }

  // Forgot password - Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('Error sending password reset email: $e');
      rethrow; // Rethrow to handle in UI
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Error during sign out: $e');
      rethrow; // Rethrow to handle in UI
    }
  }

  //remember me function
  Future<void> saveLoginCredentials(String email, String password) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('email', email);
      await prefs.setString('password', password);
      await prefs.setBool('rememberMe', true);
    }

    Future<void> clearLoginCredentials() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('email');
      await prefs.remove('password');
      await prefs.setBool('rememberMe', false);
    }

    Future<Map<String, String?>> getSavedCredentials() async {
      final prefs = await SharedPreferences.getInstance();
      final bool rememberMe = prefs.getBool('rememberMe') ?? false;
      
      if (rememberMe) {
        return {
          'email': prefs.getString('email'),
          'password': prefs.getString('password'),
        };
      }
      
      return {'email': null, 'password': null};
    }



    // Update user profile with location
    Future<UserModel?> updateUserProfile({
      required String userId,
      String? name,
      String? address,
      String? contactNumber,
      double? latitude,
      double? longitude,
    }) async {
      try {
        Map<String, dynamic> updateData = {};
        
        if (name != null) updateData['name'] = name;
        if (address != null) updateData['address'] = address;
        if (contactNumber != null) {
          // Validate contact number
          if (contactNumber.length != 10 ||
              !RegExp(r'^[0-9]+$').hasMatch(contactNumber)) {
            throw ArgumentError('Contact number must be exactly 10 digits.');
          }
          updateData['contactNumber'] = contactNumber;
        }
        if (latitude != null) updateData['latitude'] = latitude;
        if (longitude != null) updateData['longitude'] = longitude;
        
        // Only update if we have data to update
        if (updateData.isNotEmpty) {
          await _firestore.collection('users').doc(userId).update(updateData);
          
          // Get updated user data
          DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
          if (doc.exists) {
            return UserModel.fromMap(doc.data() as Map<String, dynamic>);
          }
        }
        
        return null;
      } catch (e) {
        print('Error updating user profile: $e');
        rethrow;
      }
    }
  
  // Initialize admin account
  Future<bool> setupAdminAccount() async {
    try {
      // Try to sign in as admin
      try {
        await _auth.signInWithEmailAndPassword(
          email: adminEmail,
          password: adminPassword,
        );
        // If successful, admin already exists
        await _auth.signOut();
        return true;
      } on FirebaseAuthException catch (e) {
        // Admin doesn't exist, create it
        if (e.code == 'user-not-found') {
          UserCredential result = await _auth.createUserWithEmailAndPassword(
            email: adminEmail,
            password: adminPassword,
          );
          
          if (result.user != null) {
            // Create admin user model
            UserModel adminModel = UserModel(
              uid: result.user!.uid,
              name: "Administrator",
              role: "cityManagement",
              nic: "ADMIN",
              address: "City Management Office",
              contactNumber: "0000000000", // 10 digits as required
              email: adminEmail,
            );
            
            // Save admin data to Firestore
            await _firestore
                .collection('users')
                .doc(result.user!.uid)
                .set(adminModel.toMap());
                
            await _auth.signOut();
            return true;
          }
        }
        return false;
      }
    } catch (e) {
      print('Error setting up admin account: $e');
      return false;
    }
  }
}