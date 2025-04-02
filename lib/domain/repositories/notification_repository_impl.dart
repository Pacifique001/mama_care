import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:injectable/injectable.dart';
import 'package:mama_care/data/local/database_helper.dart';
import 'package:mama_care/data/repositories/notification_repository.dart';
import 'package:mama_care/domain/entities/notification_model.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final dbHelper = DatabaseHelper();
  await dbHelper.database;
  
  if (message.notification != null) {
    await dbHelper.insert('notifications', {
      'id': message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'title': message.notification?.title ?? 'Notification',
      'body': message.notification?.body ?? '',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'isRead': 0,
      'payload': message.data.toString(),
      'fcmMessageId': message.messageId,
    });
  }
}

@Injectable(as: NotificationRepository)
class NotificationRepositoryImpl implements NotificationRepository {
  final FirebaseMessaging _firebaseMessaging;
  final DatabaseHelper _databaseHelper;
  final FlutterLocalNotificationsPlugin _localNotifications;
  
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
  );
  
  NotificationRepositoryImpl(
    this._firebaseMessaging,
    this._databaseHelper,
  ) : _localNotifications = FlutterLocalNotificationsPlugin();

  @override
  Future<void> initialize() async {
    await _initializeLocalNotifications();
    await _configureFirebaseMessaging();
    await _handleInitialMessage();
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings iosSettings = 
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    
    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }
  }

  Future<void> _configureFirebaseMessaging() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    if (Platform.isIOS) {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true, badge: true, sound: true, provisional: false,
      );
      print('Notification permission status: ${settings.authorizationStatus}');
    }
    
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedApp);
    
    final token = await _firebaseMessaging.getToken();
    if (token != null) {
      await _databaseHelper.insert('fcm_tokens', {
        'token': token,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isActive': 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      await _databaseHelper.insert('fcm_tokens', {
        'token': newToken,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isActive': 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    
    await subscribeToTopic('all_users');
  }

  Future<void> _handleInitialMessage() async {
    final message = await _firebaseMessaging.getInitialMessage();
    if (message != null) {
      await _processNotification(message);
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    await _processNotification(message);
    _showLocalNotification(message);
  }

  Future<void> _handleOpenedApp(RemoteMessage message) async {
    await _processNotification(message, markAsRead: true);
  }

  Future<void> _processNotification(RemoteMessage message, {bool markAsRead = false}) async {
    if (message.notification == null) return;
    
    final notification = {
      'id': message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'title': message.notification!.title ?? 'Notification',
      'body': message.notification!.body ?? '',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'isRead': markAsRead ? 1 : 0,
      'payload': message.data.toString(),
      'fcmMessageId': message.messageId,
    };
    
    await _databaseHelper.insert(
      'notifications',
      notification,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    _processNotificationData(message.data);
  }

  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    
    _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.data.toString(),
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      print('Notification tapped with payload: ${response.payload}');
    }
  }

  void _processNotificationData(Map<String, dynamic> data) {
    if (data.containsKey('videoId')) {
      _databaseHelper.markVideoForRefresh(data['videoId']);
    }
    if (data.containsKey('category')) {
      _databaseHelper.markCategoryForRefresh(data['category']);
    }
  }

  // Implement all your interface methods using _databaseHelper
  @override
  Future<void> saveNotification(NotificationModel notification) async {
    await _databaseHelper.insert(
      'notifications',
      notification.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<NotificationModel>> getNotifications() async {
    final results = await _databaseHelper.query(
      'notifications',
      orderBy: 'timestamp DESC',
    );
    return results.map((e) => NotificationModel.fromJson(e)).toList();
  }

  @override
  Future<void> markNotificationAsRead(String id) async {
    await _databaseHelper.update(
      'notifications',
      {'isRead': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<int> getUnreadNotificationCount() async {
    final results = await _databaseHelper.query(
      'notifications',
      where: 'isRead = ?',
      whereArgs: [0],
    );
    return results.length;
  }

  @override
  Future<void> markAllNotificationsAsRead() async {
    await _databaseHelper.update(
      'notifications',
      {'isRead': 1},
    );
  }

  @override
  Future<void> deleteNotification(String id) async {
    await _databaseHelper.delete(
      'notifications',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
  }

  @override
  Future<String?> getDeviceToken() async {
    final results = await _databaseHelper.query(
      'fcm_tokens',
      where: 'isActive = ?',
      whereArgs: [1],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    return results.isNotEmpty ? results.first['token'] as String? : null;
  }

  @override
  Future<void> sendNotification(Map<String, dynamic> data) async {
    throw UnimplementedError('Client-side sending not supported');
  }

  @override
  Future<void> initializeNotifications() async {
    // Already handled in initialize()
  }

  static Future<void> initializeFirebase() async {
    await Firebase.initializeApp();
  }
}