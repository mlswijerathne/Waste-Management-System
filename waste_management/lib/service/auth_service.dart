import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:waste_management/models/userModel.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> isUserResident() async {
    try {
      UserModel? user = await getCurrentUser();
      return user?.role == 'resident';
    } catch (e) {
      print('Error checking user role: $e');
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

  // Sign up with email and password
  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String role, // 'resident', 'driver', or 'cityManagement'
    required String name,
    required String username,
    required String nic,
    required String address,
    required String contactNumber,
  }) async {
    try {
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
          username: username,
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
      return null;
    }
  }

  // Sign in with email and password

  // Sign out
}
