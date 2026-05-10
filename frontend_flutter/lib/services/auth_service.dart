import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';
import '../utils/constants.dart';
import 'firebase_service.dart';

/// Wraps Firebase Auth + user profile initialization in Firestore.
class AuthService {
  final FirebaseService firebaseService;
  
  AuthService({required this.firebaseService});

  Stream<User?> authStateChanges() {
    return firebaseService.auth.authStateChanges();
  }

  Future<UserCredential> signupWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    String role = AppConstants.rolePatient,
  }) async {
    final credential = await firebaseService.auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = credential.user?.uid;
    if (uid == null) throw FirebaseAuthException(code: 'unknown', message: 'User uid missing');

    await firebaseService.getUsersCollection().doc(uid).set({
      'name': name.trim(),
      'phone': phone.trim(),
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return credential;
  }

  Future<UserCredential> loginWithEmail({
    required String email,
    required String password,
  }) async {
    return firebaseService.auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async {
    await firebaseService.auth.signOut();
  }

  Future<UserModel?> fetchCurrentUserProfile() async {
    final uid = firebaseService.auth.currentUser?.uid;
    if (uid == null) return null;

    final doc = await firebaseService.getUsersCollection().doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  Future<void> sendPhoneOtp({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) codeSent,
    required Function(FirebaseAuthException e) verificationFailed,
  }) async {
    await firebaseService.auth.verifyPhoneNumber(
      phoneNumber: phoneNumber.trim(),
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          final result = await firebaseService.auth.signInWithCredential(credential);
          final uid = result.user?.uid;
          if (uid != null) {
            final doc = await firebaseService.getUsersCollection().doc(uid).get();
            if (!doc.exists) {
              await firebaseService.getUsersCollection().doc(uid).set({
                'name': 'Phone User',
                'phone': phoneNumber.trim(),
                'role': AppConstants.rolePatient,
                'createdAt': FieldValue.serverTimestamp(),
              });
            }
          }
        } catch (e) {
          // ignore
        }
      },
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<UserCredential> verifyCurrentPhoneOtp({
    required String verificationId,
    required String smsCode,
    required String phoneNumber,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode.trim(),
    );
    final result = await firebaseService.auth.signInWithCredential(credential);
    final uid = result.user?.uid;
    if (uid != null) {
      final doc = await firebaseService.getUsersCollection().doc(uid).get();
      if (!doc.exists) {
        await firebaseService.getUsersCollection().doc(uid).set({
          'name': 'Phone User',
          'phone': phoneNumber.trim(),
          'role': AppConstants.rolePatient,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
    return result;
  }
}

