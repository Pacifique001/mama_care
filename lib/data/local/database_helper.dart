import 'dart:async';
import 'dart:convert';

import 'package:bcrypt/bcrypt.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;

import 'package:logging/logging.dart'; 
import 'package:mama_care/domain/entities/calendar_notes_model.dart';

import 'package:mama_care/domain/entities/user_model.dart';
import 'package:mama_care/domain/entities/user_role.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart'; 

// --- Logger Setup ---
final _log = Logger('DatabaseHelper');

class DatabaseExceptions implements Exception {
  final String message;
  final dynamic cause;
  final StackTrace? stackTrace;
  DatabaseExceptions(this.message, {this.cause, this.stackTrace});
  @override
  String toString() => 'DatabaseException: $message';
}

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid(); // For generating unique IDs

  // Firestore Collection References (centralized)
  late final CollectionReference _usersCollection;
  late final CollectionReference _nurseAssignmentsCollection;

  // Add other collection references as needed

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal() {
    _usersCollection = _firestore.collection('users');
    _nurseAssignmentsCollection = _firestore.collection('nurse_assignments');
    _configureLogger(); // Centralize logger config
  }

  void _configureLogger() {
    Logger.root.level =
        Level.INFO; // Default level, adjust as needed (Level.ALL for dev)
    Logger.root.onRecord.listen((record) {
      // Use a more structured logging format if desired
      // ignore: avoid_print
      print(
        '${record.level.name}: ${record.time.toIso8601String()}: ${record.loggerName}: ${record.message}',
      );
      if (record.error != null) {
        // ignore: avoid_print
        print('ERROR: ${record.error}');
      }
      if (record.stackTrace != null) {
        // ignore: avoid_print
        print('STACKTRACE: ${record.stackTrace}');
      }
    });
  }

  // --- Database Initialization & Migration ---
  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _log.info('Initializing database...');
    _database = await _initDatabase();
    _log.info('Database initialized successfully.');
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      final dbPath = await getDatabasesPath();

      final path = join(dbPath, 'mama_care_v3.db');
      _log.info('Database path: $path');
      return await openDatabase(
        path,
        version: 7, // <<<=== INCREMENTED VERSION for schema changes
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onConfigure: _onConfigure,
      );
    } catch (e, stackTrace) {
      // Use positional arguments for logging package
      _log.severe('Failed to initialize database', e, stackTrace);
      // Rethrow as a more specific exception if desired
      throw DatabaseExceptions(
        'Failed to initialize database',
        cause: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    _log.info('Foreign keys enabled.');
  }

  Future<void> _onCreate(Database db, int version) async {
    _log.info('Creating database tables for version $version...');
    // Use transaction for atomic creation
    await db.transaction((txn) async {
      await _createTables(txn);
      await _createIndexes(txn);
      await _createTriggers(txn); // Apply triggers on creation
      await _insertInitialData(txn);
    });
    _log.info('Database tables created successfully.');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    _log.warning(
      'Upgrading database from version $oldVersion to $newVersion...',
    );
    await db.transaction((txn) async {
      // --- Apply Migrations Sequentially ---
      if (oldVersion < 3) {
        _log.info('Applying v3 changes: Add isRecommended to app_videos');
        await txn.execute(
          'ALTER TABLE app_videos ADD COLUMN isRecommended INTEGER DEFAULT 0',
        );
      }
      if (oldVersion < 4) {
        _log.info('Applying v4 changes: Add userId to fcm_tokens');
        try {
          await txn.execute(
            'ALTER TABLE fcm_tokens ADD COLUMN userId TEXT REFERENCES users(id) ON DELETE SET NULL',
          );
        } catch (e) {
          _log.warning("Could not add userId to fcm_tokens (might exist): $e");
        }
      }
      if (oldVersion < 5) {
        _log.info('Applying v5 changes: Ensure triggers exist, rebuild FTS');
        await _createTriggers(txn); // Re-apply triggers
        await txn.execute(
          'DROP TABLE IF EXISTS videos_fts',
        ); // Drop before recreate
        await _createFtsTable(txn);
        await _rebuildFtsIndex(txn: txn); // Use named arg
      }
      if (oldVersion < 6) {
        _log.info(
          'Applying v6 changes: Add user_video_prefs, modify app_videos',
        );
        await _createUserVideoPrefsTable(txn);
        try {
          await txn.execute(
            'ALTER TABLE app_videos DROP COLUMN isFavorite',
          ); // Attempt drop first
          _log.info('Dropped isFavorite column from app_videos');
        } catch (e) {
          _log.warning('Could not drop isFavorite (might not exist): $e');
        }
        // Recreate FTS table regardless of drop success/failure if schema changed
        await txn.execute('DROP TABLE IF EXISTS videos_fts');
        await _createFtsTable(txn);
        await _rebuildFtsIndex(txn: txn); // Use named arg
      }
      // --- ADDED: Migration for Version 7 ---
      if (oldVersion < 7) {
        _log.info(
          'Applying v7 changes: Add role and permissions to users table',
        );
        try {
          await txn.execute(
            "ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'patient'",
          );
          _log.info("Added 'role' column to users table.");
        } catch (e) {
          _log.warning("Could not add 'role' column (might exist): $e");
        }
        try {
          await txn.execute(
            "ALTER TABLE users ADD COLUMN permissions TEXT",
          ); // Nullable is fine
          _log.info("Added 'permissions' column to users table.");
        } catch (e) {
          _log.warning("Could not add 'permissions' column (might exist): $e");
        }
      }
      // --- END Version 7 Migration ---

      // Add future upgrade steps like: if (oldVersion < 8) { ... }
    });
    _log.info('Database upgrade completed.');
  }
  // --- Schema Definition ---

  Future<void> _createTables(Transaction txn) async {
    _log.fine('Executing CREATE TABLE statements...');

    // Core User and Auth Tables (Unchanged from previous refined version)
    await txn.execute('''
      CREATE TABLE IF NOT EXISTS users(
        id TEXT PRIMARY KEY, email TEXT NOT NULL UNIQUE COLLATE NOCASE, name TEXT NOT NULL,
        firebaseId TEXT UNIQUE, password TEXT, phoneNumber TEXT, profileImageUrl TEXT,
        verified INTEGER DEFAULT 0, createdAt INTEGER NOT NULL, lastLogin INTEGER,
        syncStatus INTEGER DEFAULT 0, lastSynced INTEGER 
        role TEXT NOT NULL DEFAULT 'patient', -- Store role as text, default to patient
        permissions TEXT -- Store permissions as JSON String List '["p1", "p2"]'
        )
    ''');
    await txn.execute('''
      CREATE TABLE IF NOT EXISTS sessions( id TEXT PRIMARY KEY, userId TEXT NOT NULL, createdAt INTEGER NOT NULL, expiresAt INTEGER NOT NULL,
        FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE )
    ''');
    await txn.execute('''
      CREATE TABLE IF NOT EXISTS password_reset_tokens( token TEXT PRIMARY KEY, userId TEXT NOT NULL, expiresAt INTEGER NOT NULL,
        FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE )
    ''');
    await txn.execute('''
       CREATE TABLE IF NOT EXISTS fcm_tokens( token TEXT PRIMARY KEY, userId TEXT, timestamp INTEGER NOT NULL, isActive INTEGER DEFAULT 1,
         FOREIGN KEY (userId) REFERENCES users(id) ON DELETE SET NULL )
     ''');
    await txn.execute('''
      CREATE TABLE IF NOT EXISTS pregnancy_details( id INTEGER PRIMARY KEY AUTOINCREMENT, userId TEXT NOT NULL UNIQUE, -- Ensure only one entry per user
        startingDay INTEGER, weeksPregnant INTEGER, daysPregnant INTEGER, babyHeight REAL, babyWeight REAL, dueDate INTEGER NOT NULL,
        FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE )
    ''');
    await txn.execute('''
      CREATE TABLE IF NOT EXISTS favorite_hospitals( id INTEGER PRIMARY KEY AUTOINCREMENT, userId TEXT NOT NULL, googlePlaceId TEXT, -- Make googlePlaceId unique *per user*
        name TEXT, vicinity TEXT, latitude REAL, longitude REAL,
        FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE, UNIQUE (userId, googlePlaceId) )
    ''');
    await txn.execute('''
      CREATE TABLE IF NOT EXISTS prediction_history( id INTEGER PRIMARY KEY AUTOINCREMENT, userId TEXT NOT NULL, age INTEGER, sbp INTEGER, dbp INTEGER, bs REAL, temp REAL, heartRate INTEGER, result TEXT, timestamp INTEGER NOT NULL,
        FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE )
    ''');
    await txn.execute('''
      CREATE TABLE IF NOT EXISTS calendar_notes( id TEXT PRIMARY KEY, userId TEXT NOT NULL, date INTEGER NOT NULL, note TEXT NOT NULL, createdAt INTEGER NOT NULL, updatedAt INTEGER,
        FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE )
    ''');
    await txn.execute('''
       CREATE TABLE IF NOT EXISTS app_videos( id TEXT PRIMARY KEY, title TEXT NOT NULL, description TEXT, url TEXT NOT NULL UNIQUE, thumbnailUrl TEXT,
         -- isFavorite INTEGER DEFAULT 0, -- REMOVED in v6, moved to user_video_prefs
         isRecommended INTEGER DEFAULT 0, category TEXT, duration INTEGER, publishedAt INTEGER )
     ''');
   
    await _createUserVideoPrefsTable(txn);

    await txn.execute('''
       CREATE TABLE IF NOT EXISTS categories( id TEXT PRIMARY KEY, displayName TEXT NOT NULL, description TEXT, displayOrder INTEGER DEFAULT 0 )
     ''');
    await txn.execute('''
       CREATE TABLE IF NOT EXISTS notifications( id TEXT PRIMARY KEY, userId TEXT NOT NULL, fcmMessageId TEXT UNIQUE, title TEXT, body TEXT, timestamp INTEGER NOT NULL, isRead INTEGER DEFAULT 0, payload TEXT,
         FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE )
     ''');

    
    await txn.execute(
      'CREATE TABLE IF NOT EXISTS preferences ( key TEXT PRIMARY KEY, value TEXT )',
    );
    await txn.execute('''
      CREATE TABLE IF NOT EXISTS sync_meta( collectionName TEXT PRIMARY KEY, lastSyncTimestamp INTEGER, syncDirection TEXT )
    ''');
    
    await txn.execute('''
  CREATE TABLE IF NOT EXISTS appointments (
    id TEXT PRIMARY KEY,
    userId TEXT NOT NULL,
    doctorId TEXT NOT NULL,
    requestedTime INTEGER NOT NULL, -- Store as MillisecondsSinceEpoch UTC
    scheduledTime INTEGER,          -- Store as MillisecondsSinceEpoch UTC
    status TEXT NOT NULL,           -- Store enum as String (e.g., 'pending', 'confirmed')
    nurseId TEXT,
    reason TEXT NOT NULL,
    notes TEXT,
    createdAt INTEGER,              -- Optional: Creation timestamp
    FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
    -- Optional: FOREIGN KEY (doctorId) REFERENCES doctors(id)
    -- Optional: FOREIGN KEY (nurseId) REFERENCES nurses(id)
  )
''');
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_appointments_userId_time ON appointments(userId, requestedTime)',
    );
    _log.fine("Created appointments table and index.");
    // FTS table
    await _createFtsTable(txn);

    _log.fine('Finished CREATE TABLE statements.');
  }

  // Separated table creation for clarity, called during initial create and v6 upgrade
  Future<void> _createUserVideoPrefsTable(Transaction txn) async {
    await txn.execute('''
        CREATE TABLE IF NOT EXISTS user_video_prefs (
            userId TEXT NOT NULL,
            videoId TEXT NOT NULL,
            isFavorite INTEGER DEFAULT 0,
            watchedPosition INTEGER DEFAULT 0, -- Example: track watch progress
            lastWatched INTEGER,            -- Example: timestamp
            PRIMARY KEY (userId, videoId),    -- Composite primary key
            FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY (videoId) REFERENCES app_videos(id) ON DELETE CASCADE
        )
      ''');
    _log.fine('Created/Ensured user_video_prefs table exists.');
  }

  Future<void> _createFtsTable(Transaction txn) async {
    // FTS table references the *current* app_videos schema (without isFavorite)
    await txn.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS videos_fts USING fts4(
          content='app_videos',
          videoId TEXT, title, description, category
          -- tokenize=unicode61 -- Consider adding for better international language support
        )
      ''');
    _log.fine('Created FTS table videos_fts.');
  }

  Future<void> _createIndexes(Transaction txn) async {
    _log.fine('Creating indexes...');
    // Core
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_users_firebaseId ON users(firebaseId)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_sessions_userId ON sessions(userId)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_sessions_expiresAt ON sessions(expiresAt)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_fcm_tokens_userId ON fcm_tokens(userId)',
    );
    // Features
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_calendar_notes_userId_date ON calendar_notes(userId, date)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_pregnancy_details_userId ON pregnancy_details(userId)',
    ); // Already UNIQUE
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_notifications_userId_timestamp ON notifications(userId, timestamp)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_app_videos_category_published ON app_videos(category, publishedAt)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_user_video_prefs_userId ON user_video_prefs(userId)',
    ); // For getting all user prefs
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_user_video_prefs_videoId ON user_video_prefs(videoId)',
    ); // If querying prefs for a specific video across users
    _log.fine('Indexes created.');
  }

  Future<void> _createTriggers(Transaction txn) async {
    _log.fine('Creating triggers...');
    // FTS triggers - ensure they match the current app_videos schema
    await txn.execute(
      'DROP TRIGGER IF EXISTS videos_ai',
    ); // Drop existing before creating
    await txn.execute('''
        CREATE TRIGGER videos_ai AFTER INSERT ON app_videos BEGIN
          INSERT INTO videos_fts (videoId, title, description, category) VALUES (new.id, new.title, new.description, new.category);
        END;
      ''');
    await txn.execute('DROP TRIGGER IF EXISTS videos_ad');
    await txn.execute('''
        CREATE TRIGGER videos_ad AFTER DELETE ON app_videos BEGIN
          DELETE FROM videos_fts WHERE videoId = old.id;
        END;
      ''');
    await txn.execute('DROP TRIGGER IF EXISTS videos_au');
    await txn.execute('''
        CREATE TRIGGER videos_au AFTER UPDATE ON app_videos BEGIN
          UPDATE videos_fts SET title = new.title, description = new.description, category = new.category WHERE videoId = old.id;
        END;
      ''');
    // Removed simple syncStatus trigger - sync needs explicit handling
    _log.fine('Triggers created/updated.');
  }

  // --- Initial Data Population ---
  Future<void> _insertInitialData(Transaction txn) async {
    _log.fine('Inserting initial data...');
    // Preferences
    await txn.insert('preferences', {
      'key': 'theme',
      'value': 'system',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await txn.insert('preferences', {
      'key': 'onboarding_completed',
      'value': '0',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    // Categories (use replace in case definition changes)
    await txn.insert('categories', {
      'id': 'pregnancy',
      'displayName': 'Pregnancy Journey',
      'displayOrder': 1,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await txn.insert('categories', {
      'id': 'nutrition',
      'displayName': 'Healthy Eating',
      'displayOrder': 2,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await txn.insert('categories', {
      'id': 'newborn',
      'displayName': 'Newborn Care',
      'displayOrder': 3,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await txn.insert('categories', {
      'id': 'postpartum',
      'displayName': 'Postpartum',
      'displayOrder': 4,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await txn.insert('categories', {
      'id': 'health',
      'displayName': 'Health & Wellness',
      'displayOrder': 5,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Load initial hospital data from assets (example)
    // This depends on having a 'assets/data/hospitals.json' file
    // await _loadInitialHospitalsFromAssets(txn); // See helper method below

    _log.fine('Initial data insertion complete.');
  }

  // Example Helper to load data from assets (Consider moving to a separate service)
  // Future<void> _loadInitialHospitalsFromAssets(Transaction txn) async {
  //   try {
  //     _log.fine("Loading initial hospitals from assets...");
  //     final String jsonString = await rootBundle.loadString('assets/data/hospitals.json');
  //     final List<dynamic> hospitals = jsonDecode(jsonString);
  //     final batch = txn.batch();
  //     int count = 0;
  //     for (var hospital in hospitals) {
  //       if (hospital is Map<String, dynamic>) {
  // Decide how to store this - maybe a dedicated `static_hospitals` table?
  // Or preload into `favorite_hospitals` with a special `userId` like 'system'?
  // For now, let's assume a separate table `static_hospitals` exists:
  // batch.insert('static_hospitals', {
  //   'googlePlaceId': hospital['googlePlaceId'], // Assuming schema
  //   'name': hospital['name'],
  //   'vicinity': hospital['vicinity'],
  //   'latitude': hospital['latitude'],
  //   'longitude': hospital['longitude'],
  // }, conflictAlgorithm: ConflictAlgorithm.ignore);
  //         count++;
  //       }
  //     }
  //     if (count > 0) {
  //       await batch.commit(noResult: true);
  //       _log.info("Loaded $count initial hospitals from assets.");
  //     } else {
  //        _log.warning("No valid hospital data found in assets/data/hospitals.json");
  //     }
  //   } catch (e, stackTrace) {
  //     _log.severe("Error loading initial hospitals from assets", e, stackTrace);
  //     // Decide if this error should prevent db creation? Probably not.
  //   }
  // }

  // Rebuild FTS index - IMPORTANT after large data changes or schema updates
  Future<void> _rebuildFtsIndex({Transaction? txn}) async {
    _log.info('Rebuilding FTS index for videos_fts...');
    final db = txn ?? await database;
    try {
      // FTS5 uses 'rebuild', FTS4 uses 'optimize'. Using standard rebuild command.
      await db.execute("INSERT INTO videos_fts(videos_fts) VALUES('rebuild')");
      _log.info('FTS index rebuilt.');
    } catch (e, stackTrace) {
      _log.severe('Error rebuilding FTS index', e, stackTrace);
      // If rebuild fails, FTS search might be inconsistent.
    }
  }

  // --- Transaction Wrapper ---
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction<T>(action, exclusive: true);
  }

  // --- Core CRUD Helpers (accept optional transaction) ---

  Future<int> insert(
    String table,
    Map<String, dynamic> data, {
    ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.replace,
    Transaction? txn,
  }) async {
    final db = txn ?? await database;
    try {
      _log.finest('INSERT into $table: $data');
      return await db.insert(table, data, conflictAlgorithm: conflictAlgorithm);
    } catch (e, stackTrace) {
      _log.severe('Error inserting into $table', e, stackTrace);
      rethrow; // Allow calling function to handle
    }
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
    Transaction? txn,
  }) async {
    final db = txn ?? await database;
    try {
      _log.finest(
        'QUERY $table: WHERE $where | ARGS $whereArgs | LIMIT $limit',
      );
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
    } catch (e, stackTrace) {
      _log.severe('Error querying $table', e, stackTrace);
      rethrow;
    }
  }

  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
    Transaction? txn,
  }) async {
    final db = txn ?? await database;
    try {
      _log.finest('UPDATE $table SET $values WHERE $where | ARGS $whereArgs');
      return await db.update(
        table,
        values,
        where: where,
        whereArgs: whereArgs,
        /*conflictAlgorithm: conflictAlgorithm,*/
      );
    } catch (e, stackTrace) {
      _log.severe('Error updating $table', e, stackTrace);
      rethrow;
    }
  }

  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    Transaction? txn,
  }) async {
    final db = txn ?? await database;
    try {
      _log.finest('DELETE from $table WHERE $where | ARGS $whereArgs');
      return await db.delete(table, where: where, whereArgs: whereArgs);
    } catch (e, stackTrace) {
      _log.severe('Error deleting from $table', e, stackTrace);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? arguments,
    Transaction? txn,
  ]) async {
    final db = txn ?? await database;
    try {
      _log.finest('RAW QUERY: $sql | ARGS: $arguments');
      return await db.rawQuery(sql, arguments);
    } catch (e, stackTrace) {
      _log.severe('Error executing raw query: $sql', e, stackTrace);
      rethrow;
    }
  }

  Future<int> rawUpdate(
    String sql, [
    List<dynamic>? arguments,
    Transaction? txn,
  ]) async {
    final db = txn ?? await database;
    try {
      _log.finest('RAW UPDATE: $sql | ARGS: $arguments');
      return await db.rawUpdate(sql, arguments);
    } catch (e, stackTrace) {
      _log.severe('Error executing raw update: $sql', e, stackTrace);
      rethrow;
    }
  }

  Future<int> rawInsert(
    String sql, [
    List<dynamic>? arguments,
    Transaction? txn,
  ]) async {
    final db = txn ?? await database;
    try {
      _log.finest('RAW INSERT: $sql | ARGS: $arguments');
      return await db.rawInsert(sql, arguments);
    } catch (e, stackTrace) {
      _log.severe('Error executing raw insert: $sql', e, stackTrace);
      rethrow;
    }
  }

  Future<int> rawDelete(
    String sql, [
    List<dynamic>? arguments,
    Transaction? txn,
  ]) async {
    final db = txn ?? await database;
    try {
      _log.finest('RAW DELETE: $sql | ARGS: $arguments');
      return await db.rawDelete(sql, arguments);
    } catch (e, stackTrace) {
      _log.severe('Error executing raw delete: $sql', e, stackTrace);
      rethrow;
    }
  }

  // --- Security ---
  // _hashPassword, _verifyPassword, _generateSecureToken remain the same

  String _hashPassword(String password) {
    return BCrypt.hashpw(password, BCrypt.gensalt(logRounds: 10));
  }

  bool _verifyPassword(String inputPassword, String storedHash) {
    try {
      return BCrypt.checkpw(inputPassword, storedHash);
    } catch (e) {
      _log.warning('Password verification failed: $e');
      return false;
    }
  }

  String _generateSecureToken() {
    return _uuid.v4();
  }

  Future<void> upsertUser(
    Map<String, dynamic> userData, {
    Transaction? txn,
  }) async {
    // Ensure required fields like 'id' are present if needed by your schema
    if (userData['id'] == null || userData['id'].isEmpty) {
      _log.severe("Cannot upsert user: Missing 'id'. Data: $userData");
      throw ArgumentError("User data must include a valid 'id' for upsert.");
    }
    _log.fine("Upserting user: ${userData['id']}");
    await insert(
      'users', // The name of your users table
      userData,
      conflictAlgorithm:
          ConflictAlgorithm.replace, // Use replace for upsert behavior
      txn: txn,
    );
  }

  Future<UserModel> insertLocalUser(UserModel user, {Transaction? txn}) async {
    _log.info('Inserting local user: ${user.email}');
    if (user.id.isEmpty) {
      throw ArgumentError('User ID cannot be empty for insertion.');
    }
    final Map<String, dynamic> userData =
        user.toMap(); // Use consistent mapping
    userData['createdAt'] =
        userData['createdAt'] ?? DateTime.now().millisecondsSinceEpoch;
    userData.remove(
      'password',
    ); // Don't store password if managed by Firebase Auth primarily

    await insert(
      'users',
      userData,
      conflictAlgorithm: ConflictAlgorithm.fail,
      txn: txn,
    );
    return user;
  }

  /// Creates a user with email/password locally AND optionally hashes the password.
  /// Useful if *not* using Firebase Auth or for initial local creation before sync.
  Future<UserModel> createLocalUserWithPassword(
    String name,
    String email,
    String password, {
    String? id,
    String? phoneNumber,
    Transaction? txn,
  }) async {
    final userId = id ?? _uuid.v4();
    _log.info('Creating local user $userId with password for email: $email');

    final now = DateTime.now().millisecondsSinceEpoch;
    final userMap = {
      'id': userId,
      'firebaseId': null, // Not linked yet
      'name': name,
      'email': email.toLowerCase(), // Store lowercase email
      'password': _hashPassword(password),
      'phoneNumber': phoneNumber,
      'profileImageUrl': null,
      'verified': 0,
      'createdAt': now,
      'lastLogin': now, // Set last login on creation
      'syncStatus': 1, // Needs sync (push to Firebase)
      'lastSynced': null,
    };

    await insert(
      'users',
      userMap,
      conflictAlgorithm: ConflictAlgorithm.fail,
      txn: txn,
    );
    return UserModel.fromMap(userMap);
  }

  Future<UserModel?> getUserById(String userId, {Transaction? txn}) async {
    final results = await query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
      txn: txn,
    );
    return results.isNotEmpty ? UserModel.fromMap(results.first) : null;
  }

  Future<UserModel?> getUserByFirebaseId(
    String firebaseId, {
    Transaction? txn,
  }) async {
    final results = await query(
      'users',
      where: 'firebaseId = ?',
      whereArgs: [firebaseId],
      limit: 1,
      txn: txn,
    );
    return results.isNotEmpty ? UserModel.fromMap(results.first) : null;
  }

  Future<UserModel?> getUserByEmail(String email, {Transaction? txn}) async {
    final results = await query(
      'users',
      where: 'email = ? COLLATE NOCASE',
      whereArgs: [email.toLowerCase()],
      limit: 1,
      txn: txn,
    );
    return results.isNotEmpty ? UserModel.fromMap(results.first) : null;
  }

  /// Updates user data locally. Marks for sync if needed.
  Future<void> updateUser(
    UserModel user, {
    bool markForSync = true,
    Transaction? txn,
  }) async {
    _log.info('Updating user: ${user.id}');
    final updateData = user.toMap();
    // Don't update primary key, creation time, or password directly here
    updateData.remove('id');
    updateData.remove('createdAt');
    updateData.remove(
      'password',
    ); // Password updates should use a dedicated method

    if (markForSync) {
      updateData['syncStatus'] = 1; // Mark for Firebase push
      updateData['lastSynced'] = null; // Reset sync time
    }

    final count = await update(
      'users',
      updateData,
      where: 'id = ?',
      whereArgs: [user.id],
      txn: txn,
    );
    if (count == 0) {
      _log.warning('Attempted to update non-existent user: ${user.id}');
    }
  }

  Future<void> updateUserPassword(
    String userId,
    String newPassword, {
    Transaction? txn,
  }) async {
    _log.info('Updating password for user: $userId');
    final hashedPassword = _hashPassword(newPassword);
    final count = await update(
      'users',
      {
        'password': hashedPassword,
        'syncStatus':
            1, // Mark for potential sync actions (e.g., notify other devices)
      },
      where: 'id = ?',
      whereArgs: [userId],
      txn: txn,
    );
    if (count == 0) {
      _log.warning(
        'Attempted to update password for non-existent user: $userId',
      );
    }
  }

  Future<void> updateLastLogin(String userId, {Transaction? txn}) async {
    await update(
      'users',
      {'lastLogin': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [userId],
      txn: txn,
    );
  }

  Future<void> linkFirebaseId(
    String localUserId,
    String firebaseId, {
    Transaction? txn,
  }) async {
    _log.info('Linking local user $localUserId to Firebase ID $firebaseId');
    await update(
      'users',
      {
        'firebaseId': firebaseId,
        'syncStatus': 0,
      }, // Mark as potentially synced after linking
      where: 'id = ?',
      whereArgs: [localUserId],
      txn: txn,
    );
  }

  Future<bool> deleteUser(String userId, {Transaction? txn}) async {
    _log.warning('Deleting user: $userId');
    // Transaction ensures all related data is deleted atomically
    return await transaction((innerTxn) async {
      // Cascade deletes should handle related data (sessions, tokens, prefs, etc.)
      // Explicitly delete from non-cascaded tables if necessary (e.g., FCM if SET NULL was used)
      await delete(
        'fcm_tokens',
        where: 'userId = ?',
        whereArgs: [userId],
        txn: innerTxn,
      ); // Delete tokens linked to this user

      final count = await delete(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
        txn: innerTxn,
      );
      _log.info('User deletion result for $userId: count=$count');
      return count > 0;
    });
  }

  // --- Session Management (Refined) ---
  // createSession, validateSession, clearSession, etc. remain similar

  Future<String> createSession(
    String userId, {
    Duration duration = const Duration(days: 7),
    Transaction? txn,
  }) async {
    final now = DateTime.now();
    final expiresAt = now.add(duration);
    final sessionId = _generateSecureToken(); // Use secure token

    await insert('sessions', {
      'id': sessionId,
      'userId': userId,
      'createdAt': now.millisecondsSinceEpoch,
      'expiresAt': expiresAt.millisecondsSinceEpoch,
    }, txn: txn);
    _log.info(
      'Created session $sessionId for user $userId, expires: $expiresAt',
    );
    return sessionId;
  }

  /// Validates a session token and returns the associated user if valid.
  Future<UserModel?> validateSession(String sessionId) async {
    _log.fine('Validating session: $sessionId');
    UserModel? user;
    // Use transaction for consistent read of session and user
    await transaction((txn) async {
      final sessionResult = await query(
        'sessions',
        where: 'id = ? AND expiresAt > ?',
        whereArgs: [sessionId, DateTime.now().millisecondsSinceEpoch],
        limit: 1,
        txn: txn,
      );

      if (sessionResult.isNotEmpty) {
        final userId = sessionResult.first['userId'] as String;
        _log.fine('Session $sessionId is valid for user $userId');
        user = await getUserById(userId, txn: txn);
        if (user == null) {
          _log.warning(
            'Session $sessionId valid but user $userId not found! Cleaning up orphaned session.',
          );
          await delete(
            'sessions',
            where: 'id = ?',
            whereArgs: [sessionId],
            txn: txn,
          );
        }
      } else {
        _log.info('Session $sessionId is invalid or expired.');
      }
    });
    return user;
  }

  Future<void> clearSession(String sessionId, {Transaction? txn}) async {
    _log.info('Clearing session: $sessionId');
    await delete('sessions', where: 'id = ?', whereArgs: [sessionId], txn: txn);
  }

  Future<void> clearAllSessionsForUser(
    String userId, {
    Transaction? txn,
  }) async {
    _log.info('Clearing all sessions for user: $userId');
    await delete(
      'sessions',
      where: 'userId = ?',
      whereArgs: [userId],
      txn: txn,
    );
  }

  Future<void> clearExpiredSessions({Transaction? txn}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    _log.info('Clearing expired sessions (before $now)');
    final count = await delete(
      'sessions',
      where: 'expiresAt < ?',
      whereArgs: [now],
      txn: txn,
    );
    _log.info('Cleared $count expired sessions.');
  }

  // --- Password Reset (Refined) ---

  Future<String?> createPasswordResetToken(String email) async {
    _log.info('Creating password reset token for email: $email');
    String? generatedToken;
    await transaction((txn) async {
      final user = await getUserByEmail(email, txn: txn);
      if (user == null) {
        _log.warning('Password reset requested for non-existent email: $email');
        return; // Security: Don't reveal if email exists or not
      }
      // Check if this user is managed by Firebase Auth
      if (user.firebaseId.isNotEmpty) {
        _log.warning(
          'Password reset requested for Firebase-linked user ($email). Use Firebase SDK method `sendPasswordResetEmail`.',
        );
        // BEST OPTION: Throw an exception to signal the caller to use the Firebase method.
        throw FirebasePasswordResetRequiredException(email);
      }

      // Proceed with local password reset token generation
      await delete(
        'password_reset_tokens',
        where: 'userId = ?',
        whereArgs: [user.id],
        txn: txn,
      ); // Clear old tokens

      final token = _generateSecureToken();
      final expiresAt = DateTime.now().add(const Duration(hours: 1));

      await insert('password_reset_tokens', {
        'token': token,
        'userId': user.id,
        'expiresAt': expiresAt.millisecondsSinceEpoch,
      }, txn: txn);
      generatedToken = token;
      _log.info('Generated local password reset token for user ${user.id}');
    });

    if (generatedToken != null) {
      // ***************************************************************
      // *** CRITICAL SECURITY NOTE ***
      // Email sending MUST be handled server-side (e.g., Cloud Function).
      // NEVER embed email credentials or logic in the client app.
      // Send the 'generatedToken' and 'email' to your backend API endpoint.
      // Your backend will validate, construct the reset link, and send the email.
      _log.info(
        "Password reset token generated. NOW CALL YOUR BACKEND API TO SEND THE EMAIL with token: $generatedToken for email: $email",
      );
      // Example (conceptual):
      // try {
      //   await apiClient.sendPasswordResetEmail(email: email, token: generatedToken);
      // } catch (e) {
      //   _log.severe("Failed to trigger password reset email via backend", e);
      //   // Handle failure - maybe delete the token? Or inform user?
      // }
      // ***************************************************************
    }
    return generatedToken; // Return token mainly for testing or if backend needs it directly
  }
  // verifyAndUsePasswordResetToken, clearExpiredResetTokens remain similar

  Future<bool> verifyAndUsePasswordResetToken(
    String token,
    String newPassword,
  ) async {
    _log.info('Attempting to reset password with token: $token');
    bool success = false;
    await transaction((txn) async {
      final result = await query(
        'password_reset_tokens',
        where: 'token = ? AND expiresAt > ?',
        whereArgs: [token, DateTime.now().millisecondsSinceEpoch],
        limit: 1,
        txn: txn,
      );

      if (result.isEmpty) {
        _log.warning(
          'Invalid or expired password reset token provided: $token',
        );
        return; // Exit transaction block
      }

      final userId = result.first['userId'] as String;
      _log.info('Valid reset token found for user $userId. Updating password.');

      // Update the user's password locally
      await updateUserPassword(userId, newPassword, txn: txn);

      // Delete the used token
      await delete(
        'password_reset_tokens',
        where: 'token = ?',
        whereArgs: [token],
        txn: txn,
      );

      success = true;
      _log.info(
        'Password successfully reset for user $userId using token $token.',
      );
    });
    return success;
  }

  Future<void> clearExpiredResetTokens({Transaction? txn}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    _log.info('Clearing expired password reset tokens (before $now)');
    final count = await delete(
      'password_reset_tokens',
      where: 'expiresAt < ?',
      whereArgs: [now],
      txn: txn,
    );
    _log.info('Cleared $count expired reset tokens.');
  }

  // --- FCM Token Management (Unchanged) ---
  // saveFcmToken, deactivateFcmToken, updateFcmTokenUserId, getActiveFcmTokens remain similar

  Future<void> saveFcmToken(
    String token,
    String? userId, {
    Transaction? txn,
  }) async {
    _log.info('Saving FCM token: $token for user: $userId');
    await insert(
      'fcm_tokens',
      {
        'token': token,
        'userId': userId, // Can be null if user is not logged in
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isActive': 1,
      },
      conflictAlgorithm:
          ConflictAlgorithm.replace, // Replace existing entry for this token
      txn: txn,
    );
  }

  Future<void> deactivateFcmToken(String token, {Transaction? txn}) async {
    _log.info('Deactivating FCM token: $token');
    await update(
      'fcm_tokens',
      {'isActive': 0},
      where: 'token = ?',
      whereArgs: [token],
      txn: txn,
    );
  }

  Future<void> updateFcmTokenUserId(
    String token,
    String? userId, {
    Transaction? txn,
  }) async {
    _log.info('Updating userId for FCM token $token to $userId');
    await update(
      'fcm_tokens',
      {'userId': userId, 'timestamp': DateTime.now().millisecondsSinceEpoch},
      where: 'token = ?',
      whereArgs: [token],
      txn: txn,
    );
  }

  Future<List<String>> getActiveFcmTokens({
    String? userId,
    Transaction? txn,
  }) async {
    String whereClause = 'isActive = 1';
    List<dynamic> whereArgs = [];
    if (userId != null) {
      whereClause += ' AND userId = ?';
      whereArgs.add(userId);
    } else {
      // Optionally get tokens for non-logged-in users if needed
       whereClause += ' AND userId IS NULL';
    }

    final results = await query(
      'fcm_tokens',
      columns: ['token'],
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      txn: txn,
    );
    return results.map((row) => row['token'] as String).toList();
  }

  Future<CalendarNote> insertCalendarNote(
    CalendarNote note, {
    Transaction? txn,
  }) async {
    if (note.id == null || note.id!.isEmpty) {
      note = note.copyWith(id: _uuid.v4());
    }

    await insert(
      'calendar_notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
      txn: txn,
    );
    _log.info('Inserted calendar note: ${note.id}');
    return note;
  }

  Future<CalendarNote?> getCalendarNoteById(
    String id, {
    Transaction? txn,
  }) async {
    final results = await query(
      'calendar_notes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
      txn: txn,
    );
    return results.isNotEmpty ? CalendarNote.fromMap(results.first) : null;
  }

  Future<List<CalendarNote>> getCalendarNotesForDay(
    String userId,
    DateTime day, {
    Transaction? txn,
  }) async {
    final startOfDay =
        DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    final endOfDay =
        DateTime(
          day.year,
          day.month,
          day.day,
          23,
          59,
          59,
          999,
        ).millisecondsSinceEpoch;
    final results = await query(
      'calendar_notes',
      where: 'userId = ? AND date >= ? AND date <= ?',
      whereArgs: [userId, startOfDay, endOfDay],
      orderBy: 'date ASC',
      txn: txn,
    );
    return results.map((map) => CalendarNote.fromMap(map)).toList();
  }

  Future<List<CalendarNote>> getCalendarNotesBetween(
    String userId,
    DateTime start,
    DateTime end, {
    Transaction? txn,
  }) async {
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;
    final results = await query(
      'calendar_notes',
      where: 'userId = ? AND date BETWEEN ? AND ?',
      whereArgs: [userId, startMs, endMs],
      orderBy: 'date ASC',
      txn: txn,
    );
    return results.map((map) => CalendarNote.fromMap(map)).toList();
  }

  Future<int> updateCalendarNote(CalendarNote note, {Transaction? txn}) async {
    note = note.copyWith(updatedAt: DateTime.now());
    final count = await update(
      'calendar_notes',
      note.toMap(), // Assumes toMap includes id and updatedAt
      where: 'id = ? AND userId = ?',
      whereArgs: [note.id, note.userId],
      txn: txn,
    );
    if (count > 0) _log.info('Updated calendar note: ${note.id}');
    return count;
  }

  Future<int> deleteCalendarNote(
    String id,
    String userId, {
    Transaction? txn,
  }) async {
    final count = await delete(
      'calendar_notes',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, userId],
      txn: txn,
    );
    if (count > 0) _log.info('Deleted calendar note: $id');
    return count;
  }

  // --- Video Operations (Refined for user_video_prefs) ---

  Future<void> upsertVideo(
    Map<String, dynamic> videoData, {
    Transaction? txn,
  }) async {
    // Ensure user-specific fields are NOT in videoData
    videoData.remove('isFavorite');
    videoData.remove('watchedPosition');
    // Validate required fields? (e.g., id, url, title)
    await insert(
      'app_videos',
      videoData,
      conflictAlgorithm: ConflictAlgorithm.replace,
      txn: txn,
    );
    _log.finer('Upserted video: ${videoData['id']}');
  }

  Future<void> upsertVideos(
    List<Map<String, dynamic>> videosData, {
    bool rebuildFts = false,
    Transaction? txn,
  }) async {
    if (videosData.isEmpty) return;
    _log.info('Upserting ${videosData.length} videos...');
    await transaction((innerTxn) async {
      final batch = innerTxn.batch();
      for (final videoData in videosData) {
        videoData.remove('isFavorite'); // Ensure no user data here
        videoData.remove('watchedPosition');
        batch.insert(
          'app_videos',
          videoData,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
    _log.info('Finished upserting videos.');
    // Rebuild FTS index if requested (e.g., after a large initial sync)
    if (rebuildFts || videosData.length > 50) {
      // Example threshold
      await _rebuildFtsIndex(
        txn: txn,
      ); // Pass txn if called within another transaction
    }
  }

  // Get video methods remain similar (getVideoById, getAllVideos, getVideosByCategory)

  Future<Map<String, dynamic>?> getVideoById(
    String id, {
    Transaction? txn,
  }) async {
    final results = await query(
      'app_videos',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
      txn: txn,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllVideos({
    String? orderBy,
    Transaction? txn,
  }) async {
    return await query(
      'app_videos',
      orderBy: orderBy ?? 'publishedAt DESC',
      txn: txn,
    );
  }

  Future<List<Map<String, dynamic>>> getVideosByCategory(
    String category, {
    String? orderBy,
    Transaction? txn,
  }) async {
    return await query(
      'app_videos',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: orderBy ?? 'publishedAt DESC',
      txn: txn,
    );
  }

  // Search uses FTS (unchanged)
  Future<List<Map<String, dynamic>>> searchVideos(
    String searchTerm, {
    Transaction? txn,
  }) async {
    if (searchTerm.trim().isEmpty) return [];
    _log.info('Searching videos for: "$searchTerm"');
    final ftsQuery = searchTerm
        .split(' ')
        .where((t) => t.isNotEmpty)
        .map((term) => '$term*')
        .join(' ');
    if (ftsQuery.isEmpty) return [];

    final ftsResults = await query(
      'videos_fts',
      where: 'videos_fts MATCH ?',
      whereArgs: [ftsQuery],
      columns: ['videoId'], // Get the original video IDs
      txn: txn,
    );

    if (ftsResults.isEmpty) return [];
    final videoIds = ftsResults.map((row) => row['videoId'] as String).toList();
    final placeholders = List.filled(videoIds.length, '?').join(',');
    final videos = await query(
      'app_videos',
      where: 'id IN ($placeholders)',
      whereArgs: videoIds,
      txn: txn,
    );
    _log.info('Found ${videos.length} videos matching "$searchTerm" via FTS.');
    // Optional: Order results based on videoIds order from FTS relevance if needed
    return videos;
  }

  // --- User Video Preferences ---

  Future<void> setVideoFavorite(
    String userId,
    String videoId,
    bool isFavorite, {
    Transaction? txn,
  }) async {
    _log.info(
      'Setting video $videoId favorite status to $isFavorite for user $userId',
    );
    await insert(
      'user_video_prefs',
      {
        'userId': userId,
        'videoId': videoId,
        'isFavorite': isFavorite ? 1 : 0,
        // Update lastWatched timestamp if needed
        'lastWatched': DateTime.now().millisecondsSinceEpoch,
      },
      // Replace existing entry for this user/video combo
      conflictAlgorithm: ConflictAlgorithm.replace,
      txn: txn,
    );
  }

  Future<bool> isVideoFavorite(
    String userId,
    String videoId, {
    Transaction? txn,
  }) async {
    final results = await query(
      'user_video_prefs',
      where: 'userId = ? AND videoId = ?',
      whereArgs: [userId, videoId],
      columns: ['isFavorite'],
      limit: 1,
      txn: txn,
    );
    return results.isNotEmpty && results.first['isFavorite'] == 1;
  }

  // Updated to fetch from the correct tables using JOIN
  Future<List<Map<String, dynamic>>> getFavoriteVideos(
    String userId, {
    Transaction? txn,
  }) async {
    _log.info('Fetching favorite videos for user $userId');
    // JOIN app_videos with user_video_prefs to get full video details
    final results = await rawQuery(
      '''
        SELECT v.*
        FROM app_videos v
        JOIN user_video_prefs p ON v.id = p.videoId
        WHERE p.userId = ? AND p.isFavorite = 1
        ORDER BY v.publishedAt DESC -- Or order by when favorited if timestamp stored
     ''',
      [userId],
      txn,
    ); // Pass the transaction object here
    _log.info('Found ${results.length} favorite videos for user $userId');
    return results;
  }

  // Recommendation logic (Unchanged, but now doesn't rely on isFavorite in app_videos)
  Future<List<Map<String, dynamic>>> getRecommendedVideos({
    int limit = 10,
    Transaction? txn,
  }) async {
    return await transaction((innerTxn) async {
      // 1. Explicitly recommended videos
      var results = await query(
        'app_videos',
        where: 'isRecommended = 1',
        limit: limit,
        orderBy: 'publishedAt DESC',
        txn: innerTxn,
      );
      var currentCount = results.length;
      final fetchedIds =
          results
              .map((v) => v['id'] as String)
              .toSet(); // Keep track of fetched IDs

      // 2. Key categories (if needed)
      if (currentCount < limit) {
        final categoryResults = await query(
          'app_videos',
          where:
              'category IN (?, ?, ?) AND isRecommended = 0 AND id NOT IN (${List.filled(fetchedIds.length, '?').join(',')})', // Avoid duplicates
          whereArgs: ['pregnancy', 'nutrition', 'newborn', ...fetchedIds],
          limit: limit - currentCount,
          orderBy: 'RANDOM()',
          txn: innerTxn,
        );
        results.addAll(categoryResults);
        fetchedIds.addAll(categoryResults.map((v) => v['id'] as String));
        currentCount = results.length;
      }

      // 3. Latest videos (if still needed)
      if (currentCount < limit) {
        final placeholders =
            fetchedIds.isEmpty
                ? ''
                : 'AND id NOT IN (${List.filled(fetchedIds.length, '?').join(',')})';
        final latestResults = await query(
          'app_videos',
          where:
              'isRecommended = 0 $placeholders'
                  .trim(), // Ensure WHERE clause is valid
          whereArgs: fetchedIds.toList(),
          limit: limit - currentCount,
          orderBy: 'publishedAt DESC',
          txn: innerTxn,
        );
        results.addAll(latestResults);
      }
      _log.info('Fetched ${results.length} recommended videos.');
      return results;
    });
  }

  Future<void> savePreference(
    String key,
    String value, {
    Transaction? txn,
  }) async {
    await insert('preferences', {'key': key, 'value': value}, txn: txn);
    _log.fine('Saved preference: $key = $value');
  }

  Future<String?> getPreference(String key, {Transaction? txn}) async {
    final result = await query(
      'preferences',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
      txn: txn,
    );
    return result.isNotEmpty ? result.first['value'] as String? : null;
  }

  Future<bool> getBoolPreference(
    String key, {
    bool defaultValue = false,
    Transaction? txn,
  }) async {
    final value = await getPreference(key, txn: txn);
    // Treat null, '0', or 'false' (case-insensitive) as false
    return value != null && value != '0' && value.toLowerCase() != 'false';
  }

  Future<void> saveBoolPreference(
    String key,
    bool value, {
    Transaction? txn,
  }) async {
    await savePreference(key, value ? '1' : '0', txn: txn);
  }

  Future<void> deletePreference(String key, {Transaction? txn}) async {
    await delete('preferences', where: 'key = ?', whereArgs: [key], txn: txn);
    _log.fine('Deleted preference: $key');
  }

  // --- Onboarding Status ---
  Future<void> setOnboardingCompleted(
    bool completed, {
    Transaction? txn,
  }) async {
    await saveBoolPreference('onboarding_completed', completed, txn: txn);
    _log.info('Onboarding status set to: $completed');
  }

  Future<bool> isOnboardingCompleted({Transaction? txn}) async {
    return await getBoolPreference(
      'onboarding_completed',
      defaultValue: false,
      txn: txn,
    );
  }

  // --- Pregnancy Details (Refined with UNIQUE constraint handling) ---
  Future<void> upsertPregnancyDetail(
    Map<String, dynamic> data, {
    Transaction? txn,
  }) async {
    if (data['userId'] == null) {
      throw ArgumentError("userId is required for pregnancy details.");
    }
    // Ensure dueDate is stored consistently (e.g., milliseconds)
    data['dueDate'] = _parseDateToMillis(data['dueDate']);
    if (data['dueDate'] == null) {
      throw ArgumentError("Valid dueDate is required.");
    }

    // Use replace based on the UNIQUE constraint on userId
    await insert(
      'pregnancy_details',
      data,
      conflictAlgorithm:
          ConflictAlgorithm.replace, // Relies on UNIQUE (userId) constraint
      txn: txn,
    );
    _log.info('Upserted pregnancy details for user: ${data['userId']}');
  }

  int? _parseDateToMillis(dynamic dateInput) {
    if (dateInput == null) return null;
    if (dateInput is int) return dateInput; // Already millis
    if (dateInput is DateTime) return dateInput.millisecondsSinceEpoch;
    if (dateInput is String) {
      try {
        return DateTime.parse(dateInput).millisecondsSinceEpoch;
      } catch (_) {
        return null; // Invalid date string format
      }
    }
    return null; // Unsupported type
  }

  Future<Map<String, dynamic>?> getPregnancyDetails(
    String userId, {
    Transaction? txn,
  }) async {
    final results = await query(
      'pregnancy_details',
      where: 'userId = ?',
      whereArgs: [userId],
      limit: 1,
      txn: txn,
    );
    return results.isNotEmpty ? results.first : null;
  }

  // --- Prediction History (Unchanged) ---
  Future<int> insertPredictionHistory(
    Map<String, dynamic> data, {
    Transaction? txn,
  }) async {
    if (data['userId'] == null) {
      throw ArgumentError("userId is required for prediction history.");
    }
    data['timestamp'] =
        data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch;
    return await insert('prediction_history', data, txn: txn);
  }

  Future<List<Map<String, dynamic>>> getPredictionHistory(
    String userId, {
    int? limit,
    Transaction? txn,
  }) async {
    return await query(
      'prediction_history',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
      limit: limit,
      txn: txn,
    );
  }

  // --- Favorite Hospitals (Refined with UNIQUE constraint) ---
  Future<void> addFavoriteHospital(
    Map<String, dynamic> hospitalData, {
    Transaction? txn,
  }) async {
    if (hospitalData['userId'] == null) {
      throw ArgumentError('userId is required for favorite hospital');
    }
    if (hospitalData['googlePlaceId'] == null && hospitalData['name'] == null) {
      throw ArgumentError('googlePlaceId or name required');
    }

    // Use replace based on UNIQUE (userId, googlePlaceId) constraint
    await insert(
      'favorite_hospitals',
      hospitalData,
      conflictAlgorithm: ConflictAlgorithm.replace,
      txn: txn,
    );
    _log.info(
      'Added/Updated favorite hospital for user ${hospitalData['userId']}',
    );
  }

  Future<List<Map<String, dynamic>>> getFavoriteHospitals(
    String userId, {
    Transaction? txn,
  }) async {
    return await query(
      'favorite_hospitals',
      where: 'userId = ?',
      whereArgs: [userId],
      txn: txn,
    );
  }

  // Allow removal by ID (primary key) or by userId/googlePlaceId combo
  Future<void> removeFavoriteHospitalById(int id, {Transaction? txn}) async {
    final count = await delete(
      'favorite_hospitals',
      where: 'id = ?',
      whereArgs: [id],
      txn: txn,
    );
    if (count > 0) _log.info('Removed favorite hospital by id $id');
  }

  Future<void> removeFavoriteHospitalByPlaceId(
    String userId,
    String googlePlaceId, {
    Transaction? txn,
  }) async {
    final count = await delete(
      'favorite_hospitals',
      where: 'userId = ? AND googlePlaceId = ?',
      whereArgs: [userId, googlePlaceId],
      txn: txn,
    );
    if (count > 0) {
      _log.info('Removed favorite hospital $googlePlaceId for user $userId');
    }
  }

  // --- Firebase Sync Management (Refined timestamps) ---
  Future<void> updateLastSyncTimestamp(
    String collectionName, {
    int? timestamp,
    Transaction? txn,
  }) async {
    await insert(
      'sync_meta',
      {
        'collectionName': collectionName,
        'lastSyncTimestamp':
            timestamp ??
            DateTime.now().millisecondsSinceEpoch, // Use provided or now
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
      txn: txn,
    );
    _log.info(
      'Updated last sync timestamp for $collectionName to ${DateTime.fromMillisecondsSinceEpoch(timestamp ?? DateTime.now().millisecondsSinceEpoch)}',
    );
  }
  // getLastSyncTimestamp remains the same

  Future<int> getLastSyncTimestamp(
    String collectionName, {
    Transaction? txn,
  }) async {
    final result = await query(
      'sync_meta',
      where: 'collectionName = ?',
      whereArgs: [collectionName],
      limit: 1,
      txn: txn,
    );
    return result.isNotEmpty
        ? (result.first['lastSyncTimestamp'] as int? ?? 0)
        : 0;
  }

  // --- Firebase-Specific Operations (Nurse Assignment - Unchanged) ---
  Future<void> assignPatientToNurse(
    String nurseId,
    String patientId,
    String doctorId,
  ) async {
    _log.info(
      'Assigning patient $patientId to nurse $nurseId (Doctor: $doctorId)',
    );
    final assignmentRef = _nurseAssignmentsCollection.doc(nurseId);

    await _firestore
        .runTransaction((firestoreTxn) async {
          final docSnapshot = await firestoreTxn.get(assignmentRef);
          List<String> currentPatients = [];
          bool exists = docSnapshot.exists;
          if (exists && docSnapshot.data() != null) {
            var data = docSnapshot.data() as Map<String, dynamic>;
            var patientsData = data['patientIds'];
            if (patientsData is List) {
              currentPatients = List<String>.from(
                patientsData.map((item) => item.toString()),
              );
            }
          }

          final capacityLimit = 5;
          if (currentPatients.length >= capacityLimit) {
            _log.severe(
              'Nurse $nurseId is at full capacity ($capacityLimit patients).',
            );
            throw Exception('Nurse at full capacity');
          }

          if (!currentPatients.contains(patientId)) {
            currentPatients.add(patientId);
            final timestamp = FieldValue.serverTimestamp();
            if (exists) {
              firestoreTxn.update(assignmentRef, {
                'patientIds': currentPatients,
                'doctorId': doctorId,
                'lastUpdated': timestamp,
              });
            } else {
              firestoreTxn.set(assignmentRef, {
                'nurseId': nurseId,
                'patientIds': currentPatients,
                'doctorId': doctorId,
                'createdAt': timestamp,
                'lastUpdated': timestamp,
              });
            }
            _log.info(
              'Firestore transaction: Added patient $patientId to nurse $nurseId.',
            );
          } else {
            _log.warning(
              'Patient $patientId already assigned to nurse $nurseId in Firestore.',
            );
          }
        })
        .catchError((error, stackTrace) {
          _log.severe(
            'Firestore transaction failed for nurse assignment',
            error,
            stackTrace,
          );
          throw error; // Rethrow to signal failure
        });
    // Local DB update should ideally be handled by the main sync mechanism pulling from Firestore
    _log.info(
      'Successfully requested assignment of patient $patientId to nurse $nurseId via Firestore.',
    );
  }

  // --- Full Sync Example (Refined - Focus on Local -> Firestore Document Sync) ---

  Future<void> syncUsersWithFirebase() async {
    _log.info('Starting user sync with Firebase...');
    bool syncErrorOccurred = false;
    int lastSuccessfulSyncTime = await getLastSyncTimestamp('users');

    try {
      await transaction((txn) async {
        // 1. Push local changes (syncStatus 1) to Firestore documents
        await _syncLocalUsersToFirebase(txn);

        // 2. Pull Firebase changes since last sync into local DB
        lastSuccessfulSyncTime = await _syncFirebaseUsersToLocal(
          txn,
          lastSuccessfulSyncTime,
        );

        // 3. Update overall sync timestamp for 'users' ONLY if pull was successful
        await updateLastSyncTimestamp(
          'users',
          timestamp: lastSuccessfulSyncTime,
          txn: txn,
        );
      });
      _log.info('User sync cycle completed.');
    } catch (e, stackTrace) {
      syncErrorOccurred = true;
      _log.severe('User sync cycle failed', e, stackTrace);
      // Optionally: Implement retry logic, notify user, etc.
    }

    // Consider post-sync actions like refreshing UI based on sync status
  }

  // Step 1: Push local changes (Handles only Firestore document creation/update)
  Future<void> _syncLocalUsersToFirebase(Transaction txn) async {
    _log.fine('Sync Phase 1: Pushing local user changes to Firestore...');
    final unsyncedUsers = await query(
      'users',
      where: 'syncStatus = ?',
      whereArgs: [1],
      txn: txn,
    );
    if (unsyncedUsers.isEmpty) {
      _log.fine('Sync Phase 1: No local changes to push.');
      return;
    }
    _log.info(
      'Sync Phase 1: Found ${unsyncedUsers.length} local users to push.',
    );

    for (final userMap in unsyncedUsers) {
      final user = UserModel.fromMap(userMap);
      final Map<String, dynamic> firebaseData = {
        'name': user.name, 'email': user.email, 'phoneNumber': user.phoneNumber,
        'profileImageUrl': user.profileImageUrl, 'verified': user.verified,
        'role': userRoleToString(user.role),
        // Do NOT sync password hash. 'localId': user.id, // Optional reference
      };

      try {
        DocumentReference userDocRef;
        if (user.firebaseId.isEmpty) {
          // **** IMPORTANT DECISION: Cannot create Firebase Auth User here securely ****
          // Best practice: User creation initiated via UI -> Backend -> Firebase Auth -> Firestore Doc -> Sync Pull
          // Fallback (implemented here): Create ONLY the Firestore document using the local ID.
          // Requires the local ID (UUID) to be globally unique.
          // A separate linking mechanism (e.g., on first login) is REQUIRED.
          _log.warning(
            'Sync Phase 1: Pushing user ${user.id} (local ID) to Firestore. Firebase Auth user creation/linking must happen separately.',
          );
          userDocRef = _usersCollection.doc(
            user.id,
          ); // Use local UUID as Firestore doc ID
          firebaseData['createdAt'] =
              FieldValue.serverTimestamp(); // Set creation time on first push
          firebaseData['lastUpdated'] = FieldValue.serverTimestamp();
          // Use set with merge: true in case doc was somehow created by another process
          await userDocRef.set(firebaseData, SetOptions(merge: true));
          // *** We CANNOT link the firebaseId locally here because we didn't create an Auth user ***
          // The record remains locally with syncStatus=1 until a firebaseId is linked via another process.
          // Alternative: Mark with a different status? (e.g., 4 = PushedDocOnly) -> Requires linking later.
          // For simplicity, leave as 1, assuming linking handles setting syncStatus=0 later.
          _log.info(
            'Sync Phase 1: Pushed Firestore document for local user ${user.id}.',
          );
        } else {
          // Update existing Firebase document using the known firebaseId
          _log.fine(
            'Sync Phase 1: Pushing update for user ${user.firebaseId} to Firestore.',
          );
          userDocRef = _usersCollection.doc(user.firebaseId);
          firebaseData['lastUpdated'] = FieldValue.serverTimestamp();
          await userDocRef.update(firebaseData);

          // Mark local user as synced (syncStatus = 0) ONLY if update succeeded
          await update(
            'users',
            {
              'syncStatus': 0,
              'lastSynced': DateTime.now().millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [user.id],
            txn: txn,
          );
          _log.fine(
            'Sync Phase 1: Marked local user ${user.id} as synced after Firestore update.',
          );
        }
      } catch (e, stackTrace) {
        _log.severe(
          'Sync Phase 1: Error pushing user ${user.id} (${user.firebaseId ?? 'local only'}) to Firestore',
          e,
          stackTrace,
        );
        await update(
          'users',
          {'syncStatus': 3},
          where: 'id = ?',
          whereArgs: [user.id],
          txn: txn,
        ); // Mark as Error
        // Decide: Continue with next user or rethrow to abort transaction? (Continuing here)
        continue;
      }
    }
  }

  // Step 2: Pull Firebase changes
  Future<int> _syncFirebaseUsersToLocal(
    Transaction txn,
    int lastSyncTimestamp,
  ) async {
    _log.fine(
      'Sync Phase 2: Pulling Firebase user changes since ${DateTime.fromMillisecondsSinceEpoch(lastSyncTimestamp)}',
    );
    final lastSyncTime = Timestamp.fromMillisecondsSinceEpoch(
      lastSyncTimestamp,
    );
    int latestTimestampPulled =
        lastSyncTimestamp; // Track the newest timestamp seen

    try {
      final querySnapshot =
          await _usersCollection
              .where('lastUpdated', isGreaterThan: lastSyncTime)
              .orderBy('lastUpdated', descending: false) // Process in order
              .get();

      if (querySnapshot.docs.isEmpty) {
        _log.fine('Sync Phase 2: No new user changes in Firebase.');
        return lastSyncTimestamp;
      }
      _log.info(
        'Sync Phase 2: Found ${querySnapshot.docs.length} users updated in Firebase.',
      );

      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final firebaseId = doc.id;
        final email = data['email'] as String?;
        final lastUpdatedMillis =
            (data['lastUpdated'] as Timestamp?)?.millisecondsSinceEpoch;

        if (lastUpdatedMillis != null &&
            lastUpdatedMillis > latestTimestampPulled) {
          latestTimestampPulled =
              lastUpdatedMillis; // Update latest timestamp processed
        }

        if (email == null) {
          _log.warning(
            'Sync Phase 2: Skipping Firebase doc ${doc.id} (missing email).',
          );
          continue;
        }

        UserModel? localUser =
            await getUserByFirebaseId(firebaseId, txn: txn) ??
            await getUserByEmail(email, txn: txn);

        final now = DateTime.now().millisecondsSinceEpoch;
        final Map<String, dynamic> localData = {
          'firebaseId': firebaseId,
          'email': email.toLowerCase(),
          'name': data['name'] as String? ?? 'Unknown',
          'phoneNumber': data['phoneNumber'] as String?,
          'profileImageUrl': data['profileImageUrl'] as String?,
          'verified':
              (data['verified'] == true || data['verified'] == 1) ? 1 : 0,
          'createdAt':
              (data['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? now,
          'lastLogin':
              (data['lastLogin'] as Timestamp?)
                  ?.millisecondsSinceEpoch, // Use Firestore's if available
          // 'lastUpdated': lastUpdatedMillis ?? now, // Store Firestore update time if needed
          'role':
              data['role'] as String? ??
              'patient', // Pull role string, default patient
          // Assuming permissions stored as List<String> in Firestore
          'permissions': jsonEncode(
            data['permissions'] as List? ?? [],
          ), // Pull permissions list, encode to string for DB
          'syncStatus': 0,
          'lastSynced': now,
          'password': null, // Never import password
        };

        if (localUser != null) {
          // Update existing local user
          _log.fine(
            'Sync Phase 2: Updating local user ${localUser.id} from Firebase doc $firebaseId',
          );
          localData['id'] = localUser.id; // Keep local ID
          localData['password'] =
              localUser.password; // Keep existing local password hash if any
          localData['createdAt'] =
              localUser.createdAt ??
              localData['createdAt']; // Keep original local creation time

          await update(
            'users',
            localData,
            where: 'id = ?',
            whereArgs: [localUser.id],
            txn: txn,
          );
          // If email changed in Firestore and caused a match with a *different* local user than the one matched by firebaseId, handle conflict. (Complex case, maybe log warning)
        } else {
          // Insert new local user
          _log.fine(
            'Sync Phase 2: Inserting new local user from Firebase doc $firebaseId',
          );
          localData['id'] = _uuid.v4(); // Generate local UUID
          await insert(
            'users',
            localData,
            conflictAlgorithm: ConflictAlgorithm.replace,
            txn: txn,
          );
        }
      }
      _log.info(
        'Sync Phase 2: Finished processing ${querySnapshot.docs.length} Firebase changes.',
      );
      return latestTimestampPulled; // Return the timestamp of the last processed record
    } catch (e, stackTrace) {
      // Use positional arguments for package:logging logger
      _log.severe(
        'Sync Phase 2: Error pulling users from Firebase', // 1st arg: message
        e, // 2nd arg: error object
        stackTrace, // 3rd arg: stack trace
      );
      throw Exception(
        'Failed to sync Firebase users to local database: $e',
      ); // Fixed the missing expression after throw
    }
  }

  // --- Database Maintenance ---
  Future<void> performMaintenance() async {
    _log.info('Performing database maintenance...');
    await transaction((txn) async {
      await clearExpiredSessions(txn: txn);
      await clearExpiredResetTokens(txn: txn);
      // Clean up old notifications (e.g., older than 90 days)
      final ninetyDaysAgo =
          DateTime.now()
              .subtract(const Duration(days: 90))
              .millisecondsSinceEpoch;
      final deletedNotifs = await txn.delete(
        'notifications',
        where: 'timestamp < ?',
        whereArgs: [ninetyDaysAgo],
      );
      _log.info('Cleared $deletedNotifs old notifications.');
      // Add other cleanup tasks
    });
    // Optional: Vacuum after maintenance if significant data was deleted
    // await vacuumDatabase();
    _log.info('Database maintenance completed.');
  }

  Future<void> vacuumDatabase() async {
    /* Unchanged */
  }
  Future<void> close() async {
    /* Unchanged */
  }

  // --- Database Export (Using VACUUM INTO preferred, fallback commented out) ---
  Future<void> exportDatabase(String backupPath) async {
    _log.info('Attempting to export database to: $backupPath');
    final db = await database;
    try {
      // VACUUM INTO is atomic and preferred (SQLite 3.27.0+)
      await db.execute('VACUUM INTO ?', [backupPath]);
      _log.info('Database successfully exported using VACUUM INTO.');
    } catch (e) {
      _log.warning(
        'VACUUM INTO failed (SQLite version might be < 3.27.0 or other issue). Error: $e',
      );
      _log.severe(
        'Manual file copy fallback is commented out due to potential platform complexities/permissions. Implement if VACUUM INTO is not available and manual copy is essential.',
      );
      // --- Fallback: Manual copy (Requires dart:io and platform permissions) ---
      // print('Attempting manual file copy fallback...');
      // await close(); // Close DB before copying for safety
      // final dbPath = db.path;
      // try {
      //   await File(dbPath).copy(backupPath);
      //   _log.info('Database potentially exported using manual file copy (verify file).');
      //    await database; // Reopen the database
      // } catch (copyError, stackTrace) {
      //     _log.severe('Failed to export database using manual copy', copyError, stackTrace);
      //      await database; // Attempt to reopen original database
      //     throw copyError;
      // }
      // --- End Fallback ---
      throw Exception(
        "Database export failed. VACUUM INTO error: $e. Manual fallback not enabled.",
      ); // Indicate failure clearly
    }
  }
}

// --- Custom Exception for Firebase Reset ---
class FirebasePasswordResetRequiredException implements Exception {
  final String email;
  FirebasePasswordResetRequiredException(this.email);
  @override
  String toString() =>
      'Password reset for $email must be handled via Firebase Auth SDK (sendPasswordResetEmail).';
}
