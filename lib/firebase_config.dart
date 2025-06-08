import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseConfig {
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      
      // Only enable persistence on web
      if (kIsWeb) {
        try {
          await FirebaseFirestore.instance.enablePersistence(
            const PersistenceSettings(synchronizeTabs: true),
          );
        } catch (e) {
          debugPrint('Warning: Could not enable persistence: $e');
        }
      }
      
      // Set Firestore settings
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      debugPrint('Error initializing Firebase: $e');
      rethrow;
    }
  }
  
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;
  static FirebaseAuth get auth => FirebaseAuth.instance;
}
