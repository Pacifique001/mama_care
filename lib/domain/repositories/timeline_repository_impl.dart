import 'package:firebase_auth/firebase_auth.dart';
import 'package:injectable/injectable.dart';
import 'package:mama_care/data/local/database_helper.dart';
import 'package:mama_care/data/repositories/timeline_repository.dart';
import 'package:mama_care/domain/entities/pregnancy_details.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mama_care/domain/entities/timeline_event.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

@Injectable(as: TimelineRepository)
class TimelineRepositoryImpl implements TimelineRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final DatabaseHelper _databaseHelper;
  final FirebaseMessaging _firebaseMessaging;

  TimelineRepositoryImpl(
    this._firebaseAuth,
    this._firestore,
    this._databaseHelper,
    this._firebaseMessaging,
  );

  @override
  @override
Future<PregnancyDetails?> getPregnancyDetails() async {
  try {
    final userId = _firebaseAuth.currentUser?.uid;
    if (userId == null) throw Exception("User not logged in");

    // Try local database first
    final localDetails = await _databaseHelper.query(
      'pregnancy_details',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    if (localDetails.isNotEmpty) {
      // Just take the first item if there are multiple
      return PregnancyDetails.fromJson(localDetails.first);
    }

    return null;
  } catch (e) {
    print("Error fetching pregnancy details: $e");
    return null;
  }
}

  @override
  Future<void> addTimelineEvent(TimelineEvent event) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await _firestore
            .collection('timeline_events')
            .doc(user.uid)
            .collection('events')
            .add(event.toJson());
        await _databaseHelper.insert('timeline_events', event.toJson());
      }
    } catch (e) {
      throw Exception('Failed to add timeline event: ${e.toString()}');
    }
  }

  @override
  Future<List<TimelineEvent>> getTimelineEvents() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) throw Exception("User not logged in");
      
      // Try to get from local database first
      final localEvents = await _databaseHelper.query(
        'timeline_events',
        where: 'user_id = ?',
        whereArgs: [user.uid],
      );
      
      if (localEvents.isNotEmpty) {
        return localEvents
            .map((event) => TimelineEvent.fromJson(event))
            .toList();
      }
      
      // If local database is empty, fetch from Firestore
      QuerySnapshot snapshot = await _firestore
          .collection('timeline_events')
          .doc(user.uid)
          .collection('events')
          .orderBy('createdAt', descending: true)
          .get();
          
      return snapshot.docs
          .map((doc) => TimelineEvent.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch timeline events: ${e.toString()}');
    }
  }

  @override
  Future<void> updateTimelineEvent(TimelineEvent event) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await _firestore
            .collection('timeline_events')
            .doc(user.uid)
            .collection('events')
            .doc(event.id)
            .update(event.toJson());
        await _databaseHelper.update(
          'timeline_events',
          event.toJson(),
          where: 'id = ?',
          whereArgs: [event.id],
        );
      }
    } catch (e) {
      throw Exception('Failed to update timeline event: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteTimelineEvent(String id) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await _firestore
            .collection('timeline_events')
            .doc(user.uid)
            .collection('events')
            .doc(id)
            .delete();
        await _databaseHelper.delete(
          'timeline_events',
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    } catch (e) {
      throw Exception('Failed to delete timeline event: ${e.toString()}');
    }
  }

  @override
  Future<void> sendTimelineUpdateNotification(String message) async {
    try {
      // Note: FirebaseMessaging.sendMessage is not available in the client SDK
      // You would typically use a server for this
      // Here's a simplified example assuming you have a custom implementation
      
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        // This is a placeholder - you would typically call your backend API here
        print('Would send notification with token: $token and message: $message');
      }
    } catch (e) {
      throw Exception('Failed to send notification: ${e.toString()}');
    }
  }
}