import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  static FirebaseFirestore get firestore => FirebaseFirestore.instance;
  static FirebaseAuth get auth => FirebaseAuth.instance;

  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await _initializeAppCheck();
  }

  static Future<void> _initializeAppCheck() async {
    try {
      if (kDebugMode) {
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.debug,
          appleProvider: AppleProvider.debug,
        );
        debugPrint('Firebase App Check enabled with debug provider');
      } else {
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.playIntegrity,
          appleProvider: AppleProvider.appAttest,
        );
      }
    } catch (e) {
      debugPrint('Firebase App Check initialization failed: $e');
    }
  }

  static Future<String?> getCurrentUserId() async {
    return auth.currentUser?.uid;
  }

  static Future<String> signInAnonymously() async {
    try {
      final userCredential = await auth.signInAnonymously();
      return userCredential.user!.uid;
    } catch (e) {
      debugPrint('Anonymous sign-in failed: $e');
      return '';
    }
  }
}
