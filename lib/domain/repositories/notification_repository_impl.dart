import 'dart:convert'; // For encoding/decoding payload
import 'dart:io'; // For Platform checks
import 'dart:math'; // For Random fallback ID
//import 'package:flutter/foundation.dart'; // For @pragma
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:mama_care/data/local/database_helper.dart';
import 'package:mama_care/data/repositories/notification_repository.dart'; // Interface path
import 'package:mama_care/domain/entities/notification_model.dart'; // Your notification entity
import 'package:mama_care/core/error/exceptions.dart'; // Your custom exceptions
import 'package:sqflite/sqflite.dart' as sqflite; // Import sqflite with prefix
import 'package:mama_care/navigation/navigation_service.dart'; // Import static navigation service
import 'package:mama_care/navigation/router.dart'; // Import route constants if needed
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth

// --- Background Message Handler ---
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final logger = Logger(printer: SimplePrinter());
  logger.i("Handling a background message: ${message.messageId}");
  final dbHelper = DatabaseHelper();

  try {
      await dbHelper.database;
      await _saveBackgroundNotification(dbHelper, message, logger);
  } on sqflite.DatabaseException catch (e, stackTrace) {
     logger.e("Background DB Error saving notification", error: e, stackTrace: stackTrace);
  } catch (e, stackTrace) {
     logger.e("Error handling background message", error: e, stackTrace: stackTrace);
  }
}

/// Helper to save notification in background
Future<void> _saveBackgroundNotification(DatabaseHelper dbHelper, RemoteMessage message, Logger logger) async {
   logger.d("Saving background notification to DB: ${message.messageId}");
   final notificationData = message.notification;
   final dataPayload = message.data;

   if (notificationData == null && (dataPayload['title'] == null || dataPayload['body'] == null)) {
       logger.w("Received background message without notification or relevant data payload. Skipping save.");
       return;
   }

    String title = dataPayload['title'] as String? ?? notificationData?.title ?? 'Notification';
    String body = dataPayload['body'] as String? ?? notificationData?.body ?? '';
    String id;
    if (message.messageId != null && message.messageId!.isNotEmpty) { id = message.messageId!; }
    else { final ts = DateTime.now().millisecondsSinceEpoch; final rand = Random().nextInt(99999).toString().padLeft(5, '0'); id = '${ts}_$rand'; logger.w("FCM message ID was null, generated fallback ID: $id"); }
    int timestamp = message.sentTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch;

   try {
     // Create Model instance to use its toMap() method
     final notificationToSave = NotificationModel(
        id: id,
        userId: null, // Cannot get userId reliably here
        title: title,
        body: body,
        timestamp: timestamp,
        isRead: false,
        payload: dataPayload.isNotEmpty ? dataPayload : null, // Assign map directly
        fcmMessageId: message.messageId,
     );
     await dbHelper.insert(
        'notifications',
        notificationToSave.toMap(), // Use toMap which encodes payload
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace
     );
     logger.i("Background notification saved: $id");
   } on sqflite.DatabaseException catch (e, stackTrace) {
      logger.e("Background DB Error saving notification $id", error: e, stackTrace: stackTrace);
   } catch(e, stackTrace) {
     logger.e("Failed to save background notification $id to DB", error: e, stackTrace: stackTrace);
   }
}


// --- Notification Repository Implementation ---
@Injectable(as: NotificationRepository)
class NotificationRepositoryImpl implements NotificationRepository {
  final FirebaseMessaging _firebaseMessaging;
  final DatabaseHelper _databaseHelper;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final Logger _logger;
  final FirebaseAuth _auth; // Injected FirebaseAuth

  // Define Android Notification Channel
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'mama_care_high_importance_channel', // Unique ID
    'MamaCare High Importance', // Name visible to user
    description: 'Channel for important MamaCare notifications.', // Description
    importance: Importance.high,
    playSound: true,
  );

  bool _isInitialized = false; // Initialization flag

  // Constructor with injected dependencies
  NotificationRepositoryImpl(
    this._firebaseMessaging,
    this._databaseHelper,
    this._logger,
    this._auth, // Receive injected FirebaseAuth
  ) : _localNotifications = FlutterLocalNotificationsPlugin();

  @override
  Future<void> initialize() async {
     if (_isInitialized) {
        _logger.d("NotificationRepository already initialized.");
        return;
     }
     _logger.i("Initializing NotificationRepository...");
    await _initializeLocalNotifications();
    await _configureFirebaseMessaging();
    await _handleInitialMessage();
    _isInitialized = true;
     _logger.i("NotificationRepository initialized successfully.");
  }

  /// Initializes FlutterLocalNotifications plugin and platform settings.
  Future<void> _initializeLocalNotifications() async {
     _logger.d("Initializing FlutterLocalNotifications...");
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher'); // Use default app icon

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: _onNotificationTapped,
    );

    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
       _logger.d("Android Notification Channel ensured.");
    }
  }

  /// Configures Firebase Messaging listeners and token handling.
  Future<void> _configureFirebaseMessaging() async {
     _logger.d("Configuring Firebase Messaging listeners...");
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    if (Platform.isIOS) {
      // Request permissions explicitly for iOS
      await _firebaseMessaging.requestPermission(
         alert: true, badge: true, sound: true, provisional: false,
      );
    }

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedApp);

    await _registerDeviceToken();
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      _logger.i("FCM Token refreshed.");
      await _saveDeviceToken(newToken);
    });
  }

  /// Gets and saves the initial FCM device token.
  Future<void> _registerDeviceToken() async {
    try {
        String? token = await _firebaseMessaging.getToken();
         _logger.d("Firebase initial token fetched: ${token != null}");
        await _saveDeviceToken(token!);
          } catch (e, stackTrace) {
       _logger.e("Failed to get initial FCM token", error: e, stackTrace: stackTrace);
       // Consider throwing ConfigurationException if token is essential
    }
  }

  /// Saves the FCM token to local DB, associating with the current user if logged in.
  Future<void> _saveDeviceToken(String token) async {
     _logger.d("Saving FCM token to local DB...");
     final String? userId = _auth.currentUser?.uid; // Use injected _auth
     try {
        await _databaseHelper.insert('fcm_tokens', {
           'token': token,
           'timestamp': DateTime.now().millisecondsSinceEpoch,
           'isActive': 1,
           'userId': userId, // Associate with user
         }, conflictAlgorithm: sqflite.ConflictAlgorithm.replace); // Use prefix
        _logger.i("FCM token saved locally ${userId != null ? 'for user $userId' : 'globally'}.");
     } on sqflite.DatabaseException catch (e, stackTrace) {
         _logger.e("Failed to save FCM token locally (DB Error)", error: e, stackTrace: stackTrace);
     } catch (e, stackTrace) {
         _logger.e("Failed to save FCM token locally (Other Error)", error: e, stackTrace: stackTrace);
     }
  }

  /// Checks if the app was opened from terminated state via notification.
  Future<void> _handleInitialMessage() async {
    final message = await _firebaseMessaging.getInitialMessage();
    if (message != null) {
       _logger.i("App opened from terminated state via notification: ${message.messageId}");
      await _processNotificationAndData(message, markAsRead: true);
       _onNotificationTappedLogic(message.data);
    }
  }

  /// Handles foreground FCM messages: Process, Save, Show Local Notification.
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    _logger.i("Foreground FCM message received: ${message.messageId}");
    await _processNotificationAndData(message); // Save notification to DB
    _showLocalNotification(message); // Show local notification overlay
  }

  /// Handles messages tapped when app is in background (not terminated).
  Future<void> _handleOpenedApp(RemoteMessage message) async {
    _logger.i("App opened from background via notification: ${message.messageId}");
    await _processNotificationAndData(message, markAsRead: true); // Mark as read
    _onNotificationTappedLogic(message.data); // Trigger action/navigation
  }

  /// Centralized method to save notification to DB and process data payload.
  Future<void> _processNotificationAndData(RemoteMessage message, {bool markAsRead = false}) async {
    _logger.d("Processing notification ${message.messageId}. Mark as read: $markAsRead");
    final notificationPayload = message.notification;
    final dataPayload = message.data; // This is Map<String, dynamic>

    if (notificationPayload == null && (dataPayload['title'] == null || dataPayload['body'] == null)) {
       _logger.w("Skipping DB save for message ${message.messageId}: No notification or relevant data.");
       if (dataPayload.isNotEmpty) _processNotificationDataActions(dataPayload);
       return;
    }

    // Generate ID if needed
    String id;
    if (message.messageId != null && message.messageId!.isNotEmpty) { id = message.messageId!; }
    else { final ts = DateTime.now().millisecondsSinceEpoch; final rand = Random().nextInt(99999).toString().padLeft(5, '0'); id = '${ts}_$rand'; _logger.w("FCM message ID was null, generated fallback ID: $id"); }

    final String title = dataPayload['title'] as String? ?? notificationPayload?.title ?? 'Notification';
    final String body = dataPayload['body'] as String? ?? notificationPayload?.body ?? '';
    final int timestamp = message.sentTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch;
    final String? userId = _auth.currentUser?.uid; // Use injected _auth

    // Create NotificationModel instance
    final notificationToSave = NotificationModel(
       id: id,
       userId: userId,
       title: title,
       body: body,
       timestamp: timestamp,
       isRead: markAsRead,
       payload: dataPayload.isNotEmpty ? dataPayload : null, // Assign the Map directly
       fcmMessageId: message.messageId,
    );

    try {
      // Use model's toMap() method which handles payload JSON encoding
      await _databaseHelper.insert(
        'notifications',
        notificationToSave.toMap(),
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace, // Use prefix
      );
      _logger.d("Notification $id saved to DB for user $userId.");
    } on sqflite.DatabaseException catch (e, stackTrace) {
        _logger.e("Failed to save notification $id to DB (DB Error)", error: e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
       _logger.e("Failed to save notification $id to DB (Other Error)", error: e, stackTrace: stackTrace);
    }

    // Process data payload actions separately
     _processNotificationDataActions(dataPayload);
  }

  /// Shows a local notification using FlutterLocalNotificationsPlugin.
  /// THIS METHOD WAS MISSING IN THE PREVIOUS SNIPPET AND IS NOW ADDED BACK.
  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    // Use data payload for title/body if notification payload is missing
    final String title = message.data['title'] as String? ?? notification?.title ?? 'Notification';
    final String body = message.data['body'] as String? ?? notification?.body ?? '';

    // Only show if there's something to display
    if (title == 'Notification' && body == '') {
       _logger.w("Skipping local notification for message ${message.messageId} due to empty content.");
       return;
    }

     _logger.d("Showing local notification for message ${message.messageId}");
    _localNotifications.show(
      message.hashCode, // Use message hashcode as unique integer ID
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          icon: '@mipmap/ic_launcher', // Default app icon
          importance: Importance.high, // Match channel importance
          priority: Priority.high, // Match channel priority
        ),
        iOS: const DarwinNotificationDetails(
           presentAlert: true, // Ensure alert/sound/badge are shown on iOS
           presentBadge: true,
           presentSound: true,
         ),
      ),
      // Pass data payload as JSON string to be available when notification is tapped
      payload: jsonEncode(message.data),
    );
  }


  /// Callback when a local notification is tapped (foreground, background, terminated).
  void _onNotificationTapped(NotificationResponse response) {
     _logger.i("Local notification tapped. Payload: ${response.payload}");
     if (response.payload != null && response.payload!.isNotEmpty) {
       try {
          // Decode the JSON string payload back into a Map
          final Map<String, dynamic> data = jsonDecode(response.payload!);
           _onNotificationTappedLogic(data); // Handle navigation/action
       } catch (e, stackTrace) {
          _logger.e("Error decoding notification payload", error: e, stackTrace: stackTrace);
       }
     }
  }

   /// Central logic for handling actions when a notification is tapped.
   void _onNotificationTappedLogic(Map<String, dynamic> data) {
      _logger.d("Processing notification tap logic with data: $data");
      final route = data['route'] as String?;
      final articleId = data['articleId'] as String?;
      // Extract other potential parameters like 'videoId', 'screenName', etc.

      // Use static NavigationService method for navigation
      if (route != null) {
         _logger.i("Navigating to route from notification data: $route");
         NavigationService.navigateTo(route, arguments: data); // Pass full data map as arguments
      } else if (articleId != null) {
         _logger.i("Navigating to article detail from notification data: $articleId");
          NavigationService.navigateTo(NavigationRoutes.article, arguments: articleId);
      }
      // Add more else if blocks for other specific actions based on data payload keys
      // else if (data['screen'] == 'profile') { ... }
   }

  /// Processes custom data payload for potential background actions (e.g., data refresh triggers).
  void _processNotificationDataActions(Map<String, dynamic> data) {
    _logger.d("Processing notification data payload for actions: $data");
    // Example: Trigger specific data refresh based on payload key
    // if (data['refresh_target'] == 'appointments') {
    //   _logger.i("Notification triggers appointment refresh.");
    //   locator<DashboardViewModel>().loadAppointments(); // Be careful with direct VM calls here
    // }
  }

  // --- Repository Interface Methods Implementation ---

  @override
  Future<void> saveNotification(NotificationModel notification) async {
     _logger.d("Repo: Saving notification explicitly: ${notification.id}");
     final String? currentUserId = _auth.currentUser?.uid;
     try {
       final finalNotification = notification.copyWith(userId: notification.userId ?? currentUserId);
       await _databaseHelper.insert(
         'notifications', finalNotification.toMap(), // Use toMap
         conflictAlgorithm: sqflite.ConflictAlgorithm.replace, // Use prefix
       );
     } on sqflite.DatabaseException catch (e, stackTrace) {
        _logger.e("Repo: DB Error saving notification ${notification.id}", error: e, stackTrace: stackTrace);
       throw DatabaseException("Failed to save notification.", cause: e, stackTrace: stackTrace);
     } catch (e, stackTrace) {
        _logger.e("Repo: Error saving notification ${notification.id}", error: e, stackTrace: stackTrace);
        throw DataProcessingException("Could not save notification.", cause: e, stackTrace: stackTrace);
     }
  }

  @override
  Future<List<NotificationModel>> getNotifications() async {
     _logger.d("Repo: Fetching notifications from DB...");
     final String? userId = _auth.currentUser?.uid;
     if (userId == null) {
         _logger.w("Repo: User not logged in, returning empty notification list.");
         return []; // Return empty list if no user logged in
     }
     try {
       final results = await _databaseHelper.query(
         'notifications',
         where: 'userId = ?', // Only fetch notifications for the current user
         whereArgs: [userId],
         orderBy: 'timestamp DESC',
       );
       // Use fromMap (which handles payload decoding)
       return results.map((map) => NotificationModel.fromMap(map)).toList();
     } on sqflite.DatabaseException catch (e, stackTrace) {
        _logger.e("Repo: DB Error fetching notifications", error: e, stackTrace: stackTrace);
       throw DatabaseException("Failed to load notifications.", cause: e, stackTrace: stackTrace);
     } catch (e, stackTrace) {
        _logger.e("Repo: Error fetching notifications", error: e, stackTrace: stackTrace);
        throw DataProcessingException("Could not process notification data.", cause: e, stackTrace: stackTrace);
     }
  }

  @override
  Future<void> markNotificationAsRead(String id) async {
     _logger.d("Repo: Marking notification $id as read.");
     try {
       final count = await _databaseHelper.update(
         'notifications', {'isRead': 1}, where: 'id = ?', whereArgs: [id],
       );
       if (count == 0) _logger.w("Repo: Notification $id not found to mark as read.");
     } on sqflite.DatabaseException catch (e, stackTrace) {
        _logger.e("Repo: DB Error marking notification $id as read", error: e, stackTrace: stackTrace);
       throw DatabaseException("Failed to update notification status.", cause: e, stackTrace: stackTrace);
     } catch (e, stackTrace) {
        _logger.e("Repo: Error marking notification $id as read", error: e, stackTrace: stackTrace);
        throw DataProcessingException("Could not update notification.", cause: e, stackTrace: stackTrace);
     }
  }

   @override
   Future<void> markAllNotificationsAsRead() async {
      _logger.d("Repo: Marking all notifications as read.");
      final String? userId = _auth.currentUser?.uid;
      if (userId == null) {
         _logger.w("Repo: Cannot mark all as read, user not logged in.");
         return;
      }
      try {
        final count = await _databaseHelper.update(
          'notifications', {'isRead': 1},
          where: 'isRead = ? AND userId = ?', // Scope to user and unread
          whereArgs: [0, userId],
        );
         _logger.d("Repo: Marked $count notifications as read for user $userId.");
      } on sqflite.DatabaseException catch (e, stackTrace) {
         _logger.e("Repo: DB Error marking all notifications as read", error: e, stackTrace: stackTrace);
        throw DatabaseException("Failed to update notifications.", cause: e, stackTrace: stackTrace);
      } catch (e, stackTrace) {
         _logger.e("Repo: Error marking all notifications as read", error: e, stackTrace: stackTrace);
        throw DataProcessingException("Could not update notifications.", cause: e, stackTrace: stackTrace);
      }
   }

  @override
  Future<int> getUnreadNotificationCount() async {
     _logger.d("Repo: Getting unread notification count...");
      final String? userId = _auth.currentUser?.uid;
      if (userId == null) {
         _logger.w("Repo: Cannot get unread count, user not logged in.");
         return 0;
      }
     try {
       final whereClause = 'isRead = ? AND userId = ?';
       final whereArgs = [0, userId];
       // Use count specific query if DatabaseHelper supports it, otherwise use rawQuery
       final countResult = await _databaseHelper.rawQuery(
           'SELECT COUNT(*) as count FROM notifications WHERE $whereClause', whereArgs);

       if (countResult.isNotEmpty) {
          return countResult.first['count'] as int? ?? 0;
       }
       return 0;
     } on sqflite.DatabaseException catch (e, stackTrace) {
        _logger.e("Repo: DB Error getting unread count", error: e, stackTrace: stackTrace);
        return 0; // Return 0 on DB error
     } catch (e, stackTrace) {
         _logger.e("Repo: Error getting unread count", error: e, stackTrace: stackTrace);
        return 0; // Return 0 on other errors
     }
  }

  @override
  Future<void> deleteNotification(String id) async {
     _logger.d("Repo: Deleting notification $id.");
     try {
       final count = await _databaseHelper.delete(
         'notifications', where: 'id = ?', whereArgs: [id],
       );
        if (count == 0) _logger.w("Repo: Notification $id not found for deletion.");
     } on sqflite.DatabaseException catch (e, stackTrace) {
        _logger.e("Repo: DB Error deleting notification $id", error: e, stackTrace: stackTrace);
       throw DatabaseException("Failed to delete notification.", cause: e, stackTrace: stackTrace);
     } catch (e, stackTrace) {
         _logger.e("Repo: Error deleting notification $id", error: e, stackTrace: stackTrace);
         throw DataProcessingException("Could not delete notification.", cause: e, stackTrace: stackTrace);
     }
  }

  @override
  Future<void> subscribeToTopic(String topic) async {
     _logger.i("Repo: Subscribing to FCM topic: $topic");
     try { await _firebaseMessaging.subscribeToTopic(topic); _logger.d("Repo: Subscribed OK to topic: $topic"); }
     catch (e, stackTrace) { _logger.e("Repo: Failed to subscribe to topic $topic", error: e, stackTrace: stackTrace); }
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) async {
      _logger.i("Repo: Unsubscribing from FCM topic: $topic");
      try { await _firebaseMessaging.unsubscribeFromTopic(topic); _logger.d("Repo: Unsubscribed OK from topic: $topic"); }
      catch (e, stackTrace) { _logger.e("Repo: Failed to unsubscribe from topic $topic", error: e, stackTrace: stackTrace); }
  }

  @override
  Future<String?> getDeviceToken() async {
     _logger.d("Repo: Getting active device token from local DB...");
     try {
       final results = await _databaseHelper.query( 'fcm_tokens', where: 'isActive = ?', whereArgs: [1], orderBy: 'timestamp DESC', limit: 1, );
       final token = results.isNotEmpty ? results.first['token'] as String? : null;
       _logger.d("Repo: Found device token in DB: ${token != null}");
       return token;
     } on sqflite.DatabaseException catch (e, stackTrace) { _logger.e("Repo: DB Error getting device token", error: e, stackTrace: stackTrace); return null; }
     catch (e, stackTrace) { _logger.e("Repo: Error getting device token", error: e, stackTrace: stackTrace); return null; }
  }

  @override
  Future<void> sendNotification(Map<String, dynamic> data) async {
     _logger.e("Repo: Client-side sending of notifications is not supported.");
    throw UnimplementedFeatureException('Client-side notification sending');
  }

  @override
  Future<void> initializeNotifications() async {
     _logger.d("Repo: initializeNotifications called.");
     if (!_isInitialized) { await initialize(); }
  }
}