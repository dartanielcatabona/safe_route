import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart';
import '../models/auth_state.dart';
import 'incident_service.dart';
import 'route_history_service.dart';
import 'saved_route_service.dart';
import 'sos_service.dart';

class AuthService {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  Future<void>? _googleSignInInitialization;
  
  // Mock mode for testing without Firebase configuration
  static final bool _mockMode = false;
  static User? _mockUser;

  Stream<AuthState> get authStateChanges {
    if (_mockMode) {
      // Return a stream that immediately shows the mock user if logged in
      return Stream.value(_mockUser != null 
        ? AuthState(status: AuthStatus.authenticated, user: _mockUser)
        : const AuthState(status: AuthStatus.unauthenticated));
    }
    
    return _auth.authStateChanges().asyncMap((user) {
      if (user != null) {
        return _getUserData(user.uid).then((userData) {
          return AuthState(
            status: AuthStatus.authenticated,
            user: userData,
          );
        }).catchError((error) {
          return AuthState(
            status: AuthStatus.error,
            errorMessage: error.toString(),
          );
        });
      } else {
        return const AuthState(status: AuthStatus.unauthenticated);
      }
    });
  }

  Future<User?> getCurrentUser() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      return await _getUserData(currentUser.uid);
    }
    return null;
  }

  Future<AuthState> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      if (_mockMode) {
        // Mock sign-in - bypass Firebase configuration issues
        await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
        
        // Simple mock validation
        if (email.isEmpty || password.isEmpty) {
          return const AuthState(
            status: AuthStatus.error,
            errorMessage: 'Please enter email and password',
          );
        }
        
        if (password.length < 6) {
          return const AuthState(
            status: AuthStatus.error,
            errorMessage: 'Password must be at least 6 characters',
          );
        }
        
        _mockUser = User(
          id: 'mock_user_${DateTime.now().millisecondsSinceEpoch}',
          email: email,
          displayName: email.split('@')[0],
          createdAt: DateTime.now().subtract(const Duration(days: 30)),
          lastLoginAt: DateTime.now(),
          isEmailVerified: true,
          preferences: UserPreferences(),
        );
        
        return AuthState(
          status: AuthStatus.authenticated,
          user: _mockUser!,
        );
      }

      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        final userData = await _getUserData(result.user!.uid);

        // Update last login
        await _firestore.collection('users').doc(result.user!.uid).update({
          'lastLoginAt': Timestamp.now(),
        });

        return AuthState(
          status: AuthStatus.authenticated,
          user: userData,
        );
      }

      return const AuthState(status: AuthStatus.unauthenticated);
    } on firebase_auth.FirebaseAuthException catch (e) {
      return AuthState(
        status: AuthStatus.error,
        errorMessage: _getErrorMessage(e),
      );
    } catch (e) {
      return AuthState(
        status: AuthStatus.error,
        errorMessage: 'An unexpected error occurred: ${e.toString()}',
      );
    }
  }

  Future<AuthState> registerWithEmailAndPassword(
    String email,
    String password,
    String? displayName,
  ) async {
    try {
      if (_mockMode) {
        // Mock registration - bypass Firebase configuration issues
        await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
        
        _mockUser = User(
          id: 'mock_user_${DateTime.now().millisecondsSinceEpoch}',
          email: email,
          displayName: displayName ?? email.split('@')[0],
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
          isEmailVerified: true,
          preferences: UserPreferences(),
        );
        
        return AuthState(
          status: AuthStatus.authenticated,
          user: _mockUser!,
        );
      }

      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        // Create user document in Firestore
        final newUser = User(
          id: result.user!.uid,
          email: result.user!.email!,
          displayName: displayName,
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
          isEmailVerified: result.user!.emailVerified,
          preferences: UserPreferences(),
        );

        await _firestore
            .collection('users')
            .doc(result.user!.uid)
            .set(newUser.toMap());

        // Send email verification
        await result.user!.sendEmailVerification();

        return AuthState(
          status: AuthStatus.authenticated,
          user: newUser,
        );
      }

      return const AuthState(status: AuthStatus.unauthenticated);
    } on firebase_auth.FirebaseAuthException catch (e) {
      return AuthState(
        status: AuthStatus.error,
        errorMessage: _getErrorMessage(e),
      );
    } catch (e) {
      return AuthState(
        status: AuthStatus.error,
        errorMessage: 'An unexpected error occurred: ${e.toString()}',
      );
    }
  }

  Future<AuthState> signInWithGoogle() async {
    try {
      await _ensureGoogleSignInInitialized();

      // Sign out of any existing Google session
      await _googleSignIn.signOut();

      // Trigger Google Sign-In flow
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
      
      // Get authentication details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Create Firebase credential
      final firebase_auth.AuthCredential credential = 
          firebase_auth.GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final result = await _auth.signInWithCredential(credential);

      if (result.user != null) {
        // Check if user exists in Firestore
        final userDoc =
            await _firestore.collection('users').doc(result.user!.uid).get();

        User userData;

        if (userDoc.exists) {
          // Update last login
          await _firestore.collection('users').doc(result.user!.uid).update({
            'lastLoginAt': Timestamp.now(),
          });
          userData = User.fromFirebase(userDoc.data()!, result.user!.uid);
        } else {
          // Create new user document
          userData = User(
            id: result.user!.uid,
            email: result.user!.email!,
            displayName: result.user!.displayName,
            photoUrl: result.user!.photoURL,
            createdAt: DateTime.now(),
            lastLoginAt: DateTime.now(),
            isEmailVerified: result.user!.emailVerified,
            preferences: UserPreferences(),
          );

          await _firestore
              .collection('users')
              .doc(result.user!.uid)
              .set(userData.toMap());
        }

        return AuthState(
          status: AuthStatus.authenticated,
          user: userData,
        );
      }

      return const AuthState(status: AuthStatus.unauthenticated);
    } on firebase_auth.FirebaseAuthException catch (e) {
      return AuthState(
        status: AuthStatus.error,
        errorMessage: _getErrorMessage(e),
      );
    } catch (e) {
      return AuthState(
        status: AuthStatus.error,
        errorMessage: 'An unexpected error occurred: ${e.toString()}',
      );
    }
  }

  Future<void> signOut() async {
    if (_mockMode) {
      _mockUser = null;
      return;
    }
    await _ensureGoogleSignInInitialized();
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> _ensureGoogleSignInInitialized() {
    return _googleSignInInitialization ??= _googleSignIn.initialize();
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in');
    }

    final userId = user.uid;
    
    try {
      // Delete associated data - these are best-effort and shouldn't block account deletion
      await _deleteUserStoragePhotos(user);
    } catch (e) {
      debugPrint('Storage cleanup failed during account deletion: $e');
    }
    
    try {
      await _deleteAllUserFirestoreData(userId);
    } catch (e) {
      debugPrint('Firestore cleanup failed during account deletion: $e');
    }
    
    // Delete Firebase Auth account - this is critical
    try {
      await user.delete();
    } catch (e) {
      debugPrint('Failed to delete Firebase Auth account: $e');
      
      // Check if it's a requires-recent-login error
      if (e is firebase_auth.FirebaseAuthException && 
          e.code == 'requires-recent-login') {
        throw Exception(
          'Please log in again to confirm account deletion. This is a security requirement by Firebase.'
        );
      }
      
      rethrow; // Rethrow other errors
    }
    
    // Sign out from all providers
    try {
      await _ensureGoogleSignInInitialized();
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Failed to sign out from Google: $e');
    }
    
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Failed to sign out from Firebase: $e');
    }
  }

  Future<void> _deleteAllUserFirestoreData(String userId) async {
    await Future.wait([
      SavedRouteService.deleteAllUserRoutes(userId),
      RouteHistoryService.deleteAllUserHistory(userId),
      IncidentService.deleteAllUserIncidents(userId),
      SOSService.deleteAllUserSosAlerts(userId),
      _deleteDocumentIfExists('users', userId),
      _deleteDocumentIfExists('email_verifications', userId),
    ]);
  }

  Future<void> _deleteDocumentIfExists(String collection, String documentId) async {
    try {
      final docRef = _firestore.collection(collection).doc(documentId);
      final snapshot = await docRef.get();
      if (snapshot.exists) {
        await docRef.delete();
      }
    } catch (e) {
      debugPrint('Failed to delete $collection/$documentId: $e');
      // Don't rethrow - individual document deletions shouldn't block account deletion
    }
  }

  Future<void> _deleteUserStoragePhotos(firebase_auth.User user) async {
    try {
      final storage = FirebaseStorage.instance; // Always use default instance

      // Delete current photoURL if it exists
      final currentPhotoUrl = user.photoURL;
      if (currentPhotoUrl != null && currentPhotoUrl.isNotEmpty) {
        await _safeDeleteStorageRef(
          () => storage.refFromURL(currentPhotoUrl),
          label: 'current profile photo',
        );
      }

      // Delete all profile photos for this user
      try {
        final profileFolder = storage.ref().child('profile');
        final profileListing = await profileFolder.listAll();
        for (final item in profileListing.items) {
          if (item.name.startsWith('${user.uid}_')) {
            await _safeDeleteStorageRef(() => item, label: 'profile photo ${item.name}');
          }
        }
      } catch (e) {
        debugPrint('Failed to list profile photos: $e');
        // Continue even if listing fails
      }

      // Delete fallback profile photo
      await _safeDeleteStorageRef(
        () => storage.ref().child('images').child('${user.uid}.jpg'),
        label: 'fallback profile photo',
      );
    } catch (e) {
      debugPrint('Storage photo deletion error (non-fatal): $e');
      // Don't rethrow - Storage cleanup failures shouldn't block account deletion
    }
  }

  Future<void> _safeDeleteStorageRef(
    Reference Function() refBuilder, {
    required String label,
  }) async {
    try {
      await refBuilder().delete();
    } on FirebaseException catch (e) {
      // These are expected errors for non-existent files
      if (e.code == 'object-not-found' || e.code == 'permission-denied') {
        debugPrint('Skipping $label delete: ${e.code}');
        return;
      }
      // For other Firebase errors, log and continue
      debugPrint('Firebase error deleting $label: ${e.code} - ${e.message}');
    } catch (e) {
      // Catch all other exceptions to ensure deletion doesn't fail
      debugPrint('Error deleting $label: $e');
      // Don't rethrow - individual file deletions shouldn't block account deletion
    }
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      try {
        debugPrint('=== COMPREHENSIVE EMAIL VERIFICATION DEBUG ===');
        debugPrint('Current user: ${user.email}');
        debugPrint('User ID: ${user.uid}');
        debugPrint('Email verified: ${user.emailVerified}');
        debugPrint('Firebase Auth current user: ${_auth.currentUser?.email}');
        debugPrint('Firebase Auth project: ${_auth.app.options.projectId}');
        
        // Check if user is actually authenticated
        if (_auth.currentUser == null) {
          throw Exception('No authenticated user found');
        }
        
        debugPrint('Attempting to send email verification...');
        
        // Try sending email verification with detailed tracking
        await user.sendEmailVerification();
        debugPrint('✅ Email verification API call completed successfully');
        
        // Wait a moment to ensure the request is processed
        await Future.delayed(const Duration(seconds: 2));
        
        // Verify the user is still valid and check if anything changed
        await user.reload();
        debugPrint('User reloaded after email send');
        debugPrint('Email verified after reload: ${user.emailVerified}');
        
        // Additional verification check
        final refreshedUser = _auth.currentUser;
        debugPrint('Refreshed user email: ${refreshedUser?.email}');
        debugPrint('Refreshed user verified: ${refreshedUser?.emailVerified}');
        
      } catch (e) {
        debugPrint('=== EMAIL VERIFICATION FAILED ===');
        debugPrint('Error: $e');
        debugPrint('Error type: ${e.runtimeType}');
        debugPrint('Stack trace: ${StackTrace.current}');
        
        // Provide specific error analysis
        if (e.toString().contains('network')) {
          debugPrint('🔍 DIAGNOSIS: Network connectivity issue');
        } else if (e.toString().contains('permission')) {
          debugPrint('🔍 DIAGNOSIS: Firebase permission issue');
        } else if (e.toString().contains('disabled')) {
          debugPrint('🔍 DIAGNOSIS: Email provider disabled in Firebase');
        } else if (e.toString().contains('too-many-requests')) {
          debugPrint('🔍 DIAGNOSIS: Firebase rate limit triggered for this device');
        } else if (e.toString().contains('not-authorized')) {
          debugPrint('🔍 DIAGNOSIS: Firebase project not authorized for email');
        } else {
          debugPrint('🔍 DIAGNOSIS: Unknown Firebase error');
        }
        
        rethrow; // Re-throw for UI handling
      }
    } else {
      debugPrint('Email verification not needed - user is null or already verified');
    }
  }

  Future<bool> checkEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Reload the user to get the latest email verification status
        await user.reload();
        debugPrint('Email verification status: ${user.emailVerified}');
        return user.emailVerified;
      }
      return false;
    } catch (e) {
      debugPrint('Error checking email verification: $e');
      return false;
    }
  }

  Future<void> updateProfile({
    String? displayName,
    String? phoneNumber,
    String? photoUrl,
  }) async {
    final user = _auth.currentUser;
    if (user != null) {
      // Update Firebase Auth profile only for fields that were provided.
      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }
      if (photoUrl != null) {
        await user.updatePhotoURL(photoUrl);
      }

      await user.reload();

      // Update Firestore user document
      await _firestore.collection('users').doc(user.uid).update({
        if (displayName != null) 'displayName': displayName,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'lastLoginAt': Timestamp.now(),
      });
    }
  }

  Future<void> updateUserPreferences(String userId, UserPreferences preferences) async {
    await _firestore.collection('users').doc(userId).update({
      'preferences': preferences.toMap(),
      'lastLoginAt': Timestamp.now(),
    });
  }

  Future<User> _getUserData(String uid) async {
    await _syncEmailVerificationState(uid);

    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (userDoc.exists) {
      return User.fromFirebase(userDoc.data()!, uid);
    }
    
    // User document doesn't exist, create it from Firebase Auth user
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null && firebaseUser.uid == uid) {
      final newUser = User(
        id: uid,
        email: firebaseUser.email ?? '',
        displayName: firebaseUser.displayName ?? firebaseUser.email?.split('@')[0],
        photoUrl: firebaseUser.photoURL,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
        isEmailVerified: firebaseUser.emailVerified,
        preferences: UserPreferences(),
      );
      
      // Create user document in Firestore
      await _firestore.collection('users').doc(uid).set(newUser.toMap());
      return newUser;
    }
    
    throw Exception('User data not found and unable to create');
  }

  Future<void> _syncEmailVerificationState(String uid) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null || firebaseUser.uid != uid) {
      return;
    }

    await firebaseUser.reload();
    final refreshedUser = _auth.currentUser;
    if (refreshedUser == null) {
      return;
    }

    final userDoc = await _firestore.collection('users').doc(uid).get();
    final verified = refreshedUser.emailVerified;

    if (userDoc.exists) {
      final storedVerified = userDoc.data()?['isEmailVerified'] ?? false;
      if (storedVerified != verified) {
        await _firestore.collection('users').doc(uid).update({
          'isEmailVerified': verified,
        });
      }
    } else {
      await _firestore.collection('users').doc(uid).set({
        'email': refreshedUser.email ?? '',
        'displayName': refreshedUser.displayName ?? refreshedUser.email?.split('@')[0],
        'photoUrl': refreshedUser.photoURL,
        'createdAt': Timestamp.now(),
        'lastLoginAt': Timestamp.now(),
        'isEmailVerified': verified,
        'preferences': UserPreferences().toMap(),
      });
    }
  }

  String _getErrorMessage(firebase_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'user-not-found':
        return 'No user found for this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Try again later.';
      case 'operation-not-allowed':
        return 'Operation not allowed. Contact support.';
      default:
        return 'An authentication error occurred: ${e.message}';
    }
  }
}
