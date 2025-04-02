import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:mama_care/domain/entities/user_model.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'mama_care.db');

    return await openDatabase(
      path,
      version: 3, // Incremented version for migration
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createTables(db);
    }
    if (oldVersion < 3) {  // Increment your version number
      await db.execute('ALTER TABLE app_videos ADD COLUMN isRecommended INTEGER DEFAULT 0');
    }
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pregnancy_details(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT NOT NULL,
        startingDay INTEGER NOT NULL,
        babyHeight REAL NOT NULL,
        babyWeight REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS favorite_hospitals(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        vicinity TEXT,
        latitude REAL,
        longitude REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_preferences(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT,
        password TEXT,
        name TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS prediction_history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        age INTEGER,
        sbp INTEGER,
        dbp INTEGER,
        bs REAL,
        temp REAL,
        heartRate INTEGER,
        result TEXT,
        timestamp INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS saved_videos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        detail TEXT,
        image TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS calendar_notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date INTEGER,
        note TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS hospital_data(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        address TEXT,
        latitude REAL,
        longitude REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS risk_data(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        age INTEGER,
        systolicBP INTEGER,
        diastolicBP INTEGER,
        bs REAL,
        bodyTemp REAL,
        heartRate INTEGER,
        riskData TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_videos(
        id TEXT PRIMARY KEY,
        title TEXT,
        description TEXT,
        url TEXT,
        isFavorite INTEGER DEFAULT 0,
        isRecommended INTEGER DEFAULT 0,
        category TEXT,
        needs_refresh INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS users(
        id TEXT PRIMARY KEY,
        email TEXT,
        name TEXT,
        profileImageUrl TEXT,
        token TEXT,
        last_login INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS otps(
        email TEXT PRIMARY KEY,
        otp TEXT,
        expiry_time INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS onboarding(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        completed INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS fcm_tokens(
        token TEXT PRIMARY KEY
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS video_metadata(
        id TEXT PRIMARY KEY,
        needs_refresh INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories(
        category TEXT PRIMARY KEY,
        needs_refresh INTEGER DEFAULT 0
      )
    ''');
    // Add these to your _createTables method in DatabaseHelper
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications(
        id TEXT PRIMARY KEY,
        title TEXT,
        body TEXT,
        timestamp INTEGER,
        isRead INTEGER DEFAULT 0,
        payload TEXT,
        fcmMessageId TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS fcm_tokens(
        token TEXT PRIMARY KEY,
        timestamp INTEGER,
        isActive INTEGER DEFAULT 1
      )
    ''');
  }

  // ========== Generic CRUD Operations ==========
  Future<int> insert(String table, Map<String, dynamic> data, 
      {ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.replace}) async {
    final db = await database;
    return await db.insert(table, data, conflictAlgorithm: conflictAlgorithm);
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<dynamic>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return await db.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
    ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.replace,
  }) async {
    final db = await database;
    return await db.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    return await db.delete(
      table,
      where: where,
      whereArgs: whereArgs,
    );
  }

  // ========== Specific Operations ==========
  Future<void> insertPregnancyDetail(Map<String, dynamic> details) async {
    await insert('pregnancy_details', details);
  }

  Future<List<Map<String, dynamic>>> getPregnancyDetails(String userId) async {
    return await query(
      'pregnancy_details',
      where: 'userId = ?',
      whereArgs: [userId],
    );
  }

  Future<void> insertFavoriteHospital(Map<String, dynamic> hospital) async {
    await insert('favorite_hospitals', hospital);
  }

  Future<List<Map<String, dynamic>>> getFavoriteHospitals() async {
    return await query('favorite_hospitals');
  }

  Future<void> insertUserPreferences(Map<String, dynamic> preferences) async {
    await insert('user_preferences', preferences);
  }

  Future<Map<String, dynamic>?> getUserPreferences() async {
    final results = await query('user_preferences', limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> insertPredictionHistory(Map<String, dynamic> data) async {
    return await insert('prediction_history', data);
  }

  Future<List<Map<String, dynamic>>> getPredictionHistory() async {
    return await query('prediction_history', orderBy: 'timestamp DESC');
  }

  Future<void> insertSavedVideo(Map<String, dynamic> video) async {
    await insert('saved_videos', video);
  }

  Future<List<Map<String, dynamic>>> getSavedVideos() async {
    return await query('saved_videos');
  }

  Future<void> clearUserPreferences() async {
    await delete('user_preferences');
  }

  Future<void> insertCalendarNote(Map<String, dynamic> note) async {
    await insert('calendar_notes', note);
  }

  Future<List<Map<String, dynamic>>> getCalendarNotes() async {
    return await query('calendar_notes', orderBy: 'date DESC');
  }

  Future<void> deleteCalendarNote(int id) async {
    await delete('calendar_notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> insertHospitalData(Map<String, dynamic> data) async {
    await insert('hospital_data', data);
  }

  Future<List<Map<String, dynamic>>> getHospitalData() async {
    return await query('hospital_data');
  }

  Future<void> insertRiskData(Map<String, dynamic> data) async {
    await insert('risk_data', data);
  }

  Future<List<Map<String, dynamic>>> getRiskData() async {
    return await query('risk_data');
  }

  // Video Operations
  Future<List<Map<String, dynamic>>> getAllVideos() async {
    return await query('app_videos');
  }

  Future<List<Map<String, dynamic>>> searchVideos(String query) async {
   final db = await database;
    return await db.query(
      'app_videos',
      where: 'title LIKE ? OR description LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
    );
  }

  Future<Map<String, dynamic>?> getVideoById(String id) async {
    final results = await query(
      'app_videos',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> insertVideo(Map<String, dynamic> video) async {
    await insert('app_videos', video);
  }

  Future<void> updateVideo(Map<String, dynamic> video) async {
    await update(
      'app_videos',
      video,
      where: 'id = ?',
      whereArgs: [video['id']],
    );
  }

  Future<void> deleteVideo(String id) async {
    await delete('app_videos', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getFavoriteVideos() async {
    return await query(
      'app_videos',
      where: 'isFavorite = ?',
      whereArgs: [1],
    );
  }

  Future<List<Map<String, dynamic>>> getVideosByCategory(String category) async {
    return await query(
      'app_videos',
      where: 'category = ?',
      whereArgs: [category],
    );
  }

  // User Operations
  Future<int> insertUser(Map<String, dynamic> user) async {
    return await insert('users', user);
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final results = await query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> updateUser(UserModel user) async {
    await update(
      'users',
      user.toJson(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<void> updateUserLastLogin(String email) async {
    await update(
      'users',
      {'last_login': DateTime.now().millisecondsSinceEpoch},
      where: 'email = ?',
      whereArgs: [email],
    );
  }

  Future<bool> isLoggedIn() async {
    final results = await query('users', limit: 1);
    return results.isNotEmpty;
  }

  // OTP Operations
  Future<void> insertOrUpdateOTP(String email, String otp, int expiryTime) async {
    await insert(
      'otps',
      {
        'email': email,
        'otp': otp,
        'expiry_time': expiryTime,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getOTPWithExpiry(String email) async {
    final results = await query(
      'otps',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> deleteOTP(String email) async {
    await delete('otps', where: 'email = ?', whereArgs: [email]);
  }

  // Onboarding Operations
  Future<void> setOnboardingCompleted(bool completed) async {
    await insert(
      'onboarding',
      {'completed': completed ? 1 : 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> isOnboardingCompleted() async {
    final result = await query('onboarding', limit: 1);
    return result.isNotEmpty ? result.first['completed'] == 1 : false;
  }

  // FCM Token Operations
  Future<void> saveFcmToken(String token) async {
    await insert('fcm_tokens', {'token': token});
  }

  // Refresh Operations
  Future<void> markVideoForRefresh(String videoId) async {
    await update(
      'video_metadata',
      {'needs_refresh': 1},
      where: 'id = ?',
      whereArgs: [videoId],
    );
  }

  Future<void> markCategoryForRefresh(String category) async {
    await update(
      'categories',
      {'needs_refresh': 1},
      where: 'category = ?',
      whereArgs: [category],
    );
  }
  Future<List<Map<String, dynamic>>> getRecommendedVideos() async {
    final db = await database;
    
    // First try explicitly recommended videos
    var recommendedVideos = await db.query(
      'app_videos',
      where: 'isRecommended = ?',
      whereArgs: [1],
      limit: 10,
    );

    // Then try important categories
    if (recommendedVideos.isEmpty) {
      recommendedVideos = await db.query(
        'app_videos',
        where: 'category IN (?, ?, ?, ?)',
        whereArgs: ['pregnancy', 'newborn', 'health', 'nutrition'],
        orderBy: 'RANDOM()',
        limit: 10,
      );
    }

    // Fallback to recent videos
    if (recommendedVideos.isEmpty) {
      recommendedVideos = await db.query(
        'app_videos',
        orderBy: 'id DESC',
        limit: 10,
      );
    }

    return recommendedVideos;
  }

  Future<void> markVideoAsRecommended(String videoId, bool recommended) async {
    final db = await database;
    await db.update(
      'app_videos',
      {'isRecommended': recommended ? 1 : 0},
      where: 'id = ?',
      whereArgs: [videoId],
    );
  }

  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction(action);
  }
  
}