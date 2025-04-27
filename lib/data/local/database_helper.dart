import 'dart:async';
import 'dart:convert'; // Needed for permissions JSON

import 'package:bcrypt/bcrypt.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:collection/collection.dart';

import 'package:logging/logging.dart';
import 'package:mama_care/domain/entities/article_model.dart';
import 'package:mama_care/domain/entities/calendar_notes_model.dart';
import 'package:mama_care/domain/entities/food_model.dart';

import 'package:mama_care/domain/entities/user_model.dart';
import 'package:mama_care/domain/entities/user_role.dart'; // For enum conversion
import 'package:mama_care/utils/asset_helper.dart';
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

// --- Custom Exception for Firebase Reset ---
class FirebasePasswordResetRequiredException implements Exception {
  final String email;
  FirebasePasswordResetRequiredException(this.email);
  @override
  String toString() =>
      'Password reset for $email must be handled via Firebase Auth SDK (sendPasswordResetEmail).';
}

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid(); // For generating unique IDs

  // Firestore Collection References (centralized)
  late final CollectionReference _usersCollection;
  late final CollectionReference _nurseAssignmentsCollection;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal() {
    _usersCollection = _firestore.collection('users');
    _nurseAssignmentsCollection = _firestore.collection('nurse_assignments');
    _configureLogger(); // Centralize logger config
  }

  void _configureLogger() {
    Logger.root.level = Level.ALL; // Use Level.ALL for detailed dev logs
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
      // Use a distinct name if you want to force recreation during dev
      // final path = join(dbPath, 'mama_care_dev_v7.db');
      final path = join(
        dbPath,
        'mama_care_v3.db',
      ); // Keep existing name for migration
      _log.info('Database path: $path');

      // ***** INCREMENT VERSION TO 7 *****
      const currentDbVersion = 7;

      return await openDatabase(
        path,
        version: currentDbVersion, // Use the incremented version
        onCreate: _onCreate,
        onUpgrade: _onUpgrade, // Ensure this handles upgrades up to v7
        onConfigure: _onConfigure,
      );
    } catch (e, stackTrace) {
      _log.severe('Failed to initialize database', e, stackTrace);
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
      // Ensure _createTables uses the LATEST schema (including v7 changes)
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
      // Keep previous upgrade steps
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
        await _rebuildFtsIndex(txn: txn);
      }
      if (oldVersion < 6) {
        _log.info(
          'Applying v6 changes: Add user_video_prefs, modify app_videos',
        );
        await _createUserVideoPrefsTable(txn); // Creates if not exists
        // Safely attempt to drop column (might fail if already dropped)
        try {
          await txn.execute('ALTER TABLE app_videos DROP COLUMN isFavorite');
          _log.info(
            "Dropped isFavorite column from app_videos (if it existed).",
          );
        } catch (e) {
          _log.warning(
            "Could not drop isFavorite from app_videos (might not exist): $e",
          );
        }
        // Recreate FTS table because app_videos schema changed
        await txn.execute('DROP TABLE IF EXISTS videos_fts');
        await _createFtsTable(txn);
        await _rebuildFtsIndex(txn: txn);
      }

      // ***** ADDED: Migration for Version 7 *****
      if (oldVersion < 7) {
        _log.info(
          'Applying v7 changes: Add role and permissions to users table',
        );
        // Use try-catch for robustness in case migration is run multiple times
        try {
          await txn.execute(
            // Add DEFAULT constraint for existing rows
            "ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'patient'",
          );
          _log.info("Added 'role' column to users table.");
        } catch (e) {
          _log.warning("Could not add 'role' column (might exist): $e");
        }
        try {
          await txn.execute(
            // Nullable is okay, or add DEFAULT '[]' if preferred
            "ALTER TABLE users ADD COLUMN permissions TEXT",
          );
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

    // ***** UPDATED users Table Definition *****
    await txn.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        firebaseId TEXT UNIQUE,
        email TEXT NOT NULL UNIQUE COLLATE NOCASE,
        name TEXT NOT NULL,
        password TEXT, -- Store hashed password or NULL if using Firebase Auth only
        phoneNumber TEXT UNIQUE,
        profileImageUrl TEXT,
        verified INTEGER DEFAULT 0, -- 0 = false, 1 = true
        createdAt INTEGER NOT NULL,
        lastLogin INTEGER,
        syncStatus INTEGER DEFAULT 0, -- 0: Synced, 1: NeedsPush, 2: NeedsPull, 3: Error
        lastSynced INTEGER,
        role TEXT NOT NULL DEFAULT 'patient', -- ADDED: Store role as text, default to patient
        permissions TEXT -- ADDED: Store permissions as JSON String List '["p1", "p2"]', nullable ok
      )
    ''');
    _log.fine(
      "Created/Ensured 'users' table exists with role and permissions.",
    );

    // --- Other tables (ensure they are up-to-date if needed) ---
    await txn.execute('''
      CREATE TABLE IF NOT EXISTS sessions(
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        expiresAt INTEGER NOT NULL,
        FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await txn.execute('''
      CREATE TABLE IF NOT EXISTS password_reset_tokens(
        token TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        expiresAt INTEGER NOT NULL,
        FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await txn.execute('''
       CREATE TABLE IF NOT EXISTS fcm_tokens(
         token TEXT PRIMARY KEY,
         userId TEXT, -- Nullable if user not logged in
         timestamp INTEGER NOT NULL,
         isActive INTEGER DEFAULT 1,
         FOREIGN KEY (userId) REFERENCES users(id) ON DELETE SET NULL -- Keep user ID if user deleted? Or Cascade? SET NULL seems safer.
       )
     ''');
    await txn.execute('''
      CREATE TABLE IF NOT EXISTS pregnancy_details(
        id INTEGER PRIMARY KEY AUTOINCREMENT, -- Use standard auto-increment
        userId TEXT NOT NULL UNIQUE, -- Ensure only one entry per user
        startingDay INTEGER,
        weeksPregnant INTEGER,
        daysPregnant INTEGER,
        babyHeight REAL,
        babyWeight REAL,
        dueDate INTEGER NOT NULL,
        FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await txn.execute('''
       CREATE TABLE IF NOT EXISTS favorite_hospitals(
         id INTEGER PRIMARY KEY AUTOINCREMENT,
         userId TEXT NOT NULL,
         googlePlaceId TEXT,
         name TEXT,
         vicinity TEXT,
         latitude REAL,
         longitude REAL,
         FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE,
         UNIQUE (userId, googlePlaceId) -- Ensure uniqueness per user
       )
     ''');
    await txn.execute('''
       CREATE TABLE IF NOT EXISTS prediction_history(
         id INTEGER PRIMARY KEY AUTOINCREMENT,
         userId TEXT NOT NULL,
         age INTEGER, sbp INTEGER, dbp INTEGER, bs REAL, temp REAL, heartRate INTEGER,
         result TEXT,
         timestamp INTEGER NOT NULL,
         FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
       )
     ''');
    await txn.execute('''
      CREATE TABLE IF NOT EXISTS calendar_notes(
        id TEXT PRIMARY KEY, -- Keep UUID if needed for sync
        userId TEXT NOT NULL,
        date INTEGER NOT NULL, -- Store as Millis UTC is usually best
        note TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER,
        FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    // Video table (Schema reflects state AFTER v6 upgrade - no isFavorite)
    await txn.execute('''
       CREATE TABLE IF NOT EXISTS app_videos(
         id TEXT PRIMARY KEY,
         title TEXT NOT NULL,
         description TEXT,
         url TEXT NOT NULL UNIQUE,
         thumbnailUrl TEXT,
         isRecommended INTEGER DEFAULT 0,
         category TEXT,
         duration INTEGER,
         publishedAt INTEGER
       )
     ''');
    // User video preferences table (Created separately for clarity)
    await _createUserVideoPrefsTable(txn);

    await txn.execute('''
       CREATE TABLE IF NOT EXISTS categories(
         id TEXT PRIMARY KEY,
         displayName TEXT NOT NULL,
         description TEXT,
         displayOrder INTEGER DEFAULT 0
       )
     ''');
    await txn.execute('''
       CREATE TABLE IF NOT EXISTS notifications(
         id TEXT PRIMARY KEY, -- UUID
         userId TEXT NOT NULL,
         fcmMessageId TEXT UNIQUE, -- Optional: track original FCM message
         title TEXT,
         body TEXT,
         timestamp INTEGER NOT NULL,
         isRead INTEGER DEFAULT 0,
         isScheduled INTEGER DEFAULT 0,
         payload TEXT, -- JSON string for extra data
         FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
         
       )
     ''');
    await txn.execute('''
       CREATE TABLE IF NOT EXISTS preferences (
         key TEXT PRIMARY KEY,
         value TEXT
       )
     ''');
    await txn.execute('''
      CREATE TABLE IF NOT EXISTS sync_meta(
        collectionName TEXT PRIMARY KEY,
        lastSyncTimestamp INTEGER,
        syncDirection TEXT -- Optional: 'push', 'pull', 'bidirectional'
      )
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
         -- Optional: FOREIGN KEY (doctorId) REFERENCES doctors(id) -- Add if doctors table exists
         -- Optional: FOREIGN KEY (nurseId) REFERENCES users(id) -- Or separate nurses table
       )
     ''');
    await txn.execute('''
        CREATE TABLE IF NOT EXISTS articles (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          content TEXT NOT NULL, -- Changed from detail
          author TEXT,
          imageUrl TEXT NOT NULL,
          publishDate TEXT NOT NULL, -- Store as ISO8601 String
          isBookmarked INTEGER DEFAULT 0, -- 0 for false, 1 for true
          tags TEXT -- Store tags as JSON String list '["tag1", "tag2"]'
        )
      ''');
    await txn.execute('''
      CREATE TABLE IF NOT EXISTS foods (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,        -- Changed from foodName
        description TEXT,
        category TEXT,           -- Added category column
        imageUrl TEXT,           -- Added imageUrl column (nullable)
        benefitsJson TEXT,       -- Added column for JSON string benefits
        isFavorite INTEGER DEFAULT 0 -- Added column for favorite (integer)
      )
    ''');
    // FTS table (Depends on app_videos schema *without* isFavorite)
    await _createFtsTable(txn);

    _log.fine('Finished CREATE TABLE statements.');
  }

  // --- Separated table creation functions for clarity ---
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
    await txn.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS videos_fts USING fts4(
          content='app_videos', -- Link to the main video table
          videoId UNINDEXED, -- Usually don't search by ID directly
          title,
          description,
          category
          -- tokenize=unicode61 -- Consider adding for better international language support if needed
        )
      ''');
    _log.fine('Created/Ensured FTS table videos_fts exists.');
  }

  // --- Index Creation ---
  Future<void> _createIndexes(Transaction txn) async {
    _log.fine('Creating indexes...');
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
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_calendar_notes_userId_date ON calendar_notes(userId, date)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_notifications_userId_timestamp ON notifications(userId, timestamp)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_app_videos_category_published ON app_videos(category, publishedAt)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_user_video_prefs_userId ON user_video_prefs(userId)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_user_video_prefs_videoId ON user_video_prefs(videoId)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_appointments_userId_time ON appointments(userId, requestedTime)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_appointments_status ON appointments(status)',
    ); // Index status for filtering
    _log.fine('Indexes created.');
  }

  // --- Trigger Creation ---
  Future<void> _createTriggers(Transaction txn) async {
    _log.fine('Creating/Updating triggers...');
    // --- FTS Triggers ---
    // Drop existing before creating to ensure they match the current schema
    await txn.execute('DROP TRIGGER IF EXISTS videos_ai');
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
           -- Update only indexed columns
           UPDATE videos_fts SET title = new.title, description = new.description, category = new.category WHERE videoId = old.id;
         END;
       ''');
    _log.fine('FTS Triggers created/updated.');
  }

  // --- Initial Data Population ---
  Future<void> _insertInitialData(Transaction txn) async {
    _log.fine('Inserting initial data...');

    // --- Preferences ---
    await txn.insert('preferences', {
      'key': 'theme',
      'value': 'system',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await txn.insert('preferences', {
      'key': 'onboarding_completed',
      'value': '0',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    // --- Categories ---
    final categories = [
      // ... your existing categories data ...
      {
        'id': 'pregnancy',
        'displayName': 'Pregnancy Journey',
        'displayOrder': 1,
      },
      {'id': 'nutrition', 'displayName': 'Healthy Eating', 'displayOrder': 2},
      {'id': 'fitness', 'displayName': 'Fitness & Yoga', 'displayOrder': 3},
      {'id': 'labor', 'displayName': 'Labor & Delivery', 'displayOrder': 4},
      {'id': 'newborn', 'displayName': 'Newborn Care', 'displayOrder': 5},
      {'id': 'postpartum', 'displayName': 'Postpartum', 'displayOrder': 6},
      {'id': 'health', 'displayName': 'Health & Wellness', 'displayOrder': 7},
      {'id': 'other', 'displayName': 'Other Resources', 'displayOrder': 99},
    ];
    for (var category in categories) {
      await txn.insert(
        'categories',
        category,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    _log.fine('Initial categories inserted/updated.');

    // --- Articles ---
    _log.info('Seeding initial articles into database...');
    int articlesInserted = 0;
    try {
      final articleBatch = txn.batch();
      for (final articleMap in AssetsHelper.articleData) {
        try {
          // Add try-catch around individual parsing if needed
          final article = ArticleModel.fromMap(articleMap);
          articleBatch.insert(
            'articles',
            article.toSqliteMap(),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        } catch (e, s) {
          _log.warning(
            'Failed to parse or queue article: ${articleMap['title']}',
            e,
            s,
          );
        }
      }
      final List<Object?> articleResults = await articleBatch.commit(
        noResult: false,
      );
      articlesInserted =
          articleResults
              .where((result) => result != null && result is int && result > 0)
              .length;
      _log.info('Seeded $articlesInserted initial articles successfully.');
    } catch (e, s) {
      _log.severe('Failed to commit article batch', e, s);
    }

    // --- Foods (NEW SECTION) ---
    _log.info('Seeding initial foods into database...');
    int foodsInserted = 0;
    try {
      final foodBatch = txn.batch();
      for (final foodMap in AssetsHelper.foodData) {
        try {
          // Create FoodModel instance (generates ID) and convert to map
          final food = FoodModel.fromMap(
            foodMap,
          ); // Create model (generates ID)
          foodBatch.insert(
            'foods',
            food.toSqliteMap(), // Use the correct map for SQLite
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        } catch (e, s) {
          _log.warning(
            'Failed to parse or queue food: ${foodMap['name']}',
            e,
            s,
          );
        }
      }
      // Commit the batch for foods
      final List<Object?> foodResults = await foodBatch.commit(noResult: false);
      // Count successful inserts
      foodsInserted =
          foodResults
              .where((result) => result != null && result is int && result > 0)
              .length;
      _log.info('Seeded $foodsInserted initial foods successfully.');
    } catch (e, s) {
      _log.severe('Failed to commit food batch', e, s);
    }
    // -------------------------

    _log.fine('Initial data insertion complete.');
  }

  // --- FTS Rebuild Helper ---
  Future<void> _rebuildFtsIndex({Transaction? txn}) async {
    _log.info('Rebuilding FTS index for videos_fts...');
    final db = txn ?? await database;
    try {
      // FTS4 uses a specific syntax for rebuild (via optimize)
      // INSERT INTO videos_fts(videos_fts) VALUES('rebuild') -- This is for FTS5
      // Optimize command works for FTS4
      await db.execute("INSERT INTO videos_fts(videos_fts) VALUES('optimize')");
      _log.info('FTS index optimized/rebuilt.');
    } catch (e, stackTrace) {
      _log.severe('Error rebuilding/optimizing FTS index', e, stackTrace);
    }
  }

  // --- Transaction Wrapper ---
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    // Using exclusive: false might be slightly less safe but can prevent some deadlocks
    // if nested transactions or complex operations occur. Test carefully.
    return await db.transaction<T>(action /*, exclusive: true*/);
  }

  // --- Core CRUD Helpers ---
  // (insert, query, update, delete, rawQuery, rawUpdate, rawInsert, rawDelete remain the same)
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
      // Wrap the specific SQFlite exception if needed
      _log.severe('Error inserting into $table', e, stackTrace);
      if (e is DatabaseException) {
        throw DatabaseExceptions(
          'Insert failed into $table: ${e.getResultCode()}',
          cause: e,
          stackTrace: stackTrace,
        );
      }
      rethrow; // Rethrow other exceptions
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
      if (e is DatabaseException) {
        throw DatabaseExceptions(
          'Query failed on $table: ${e.getResultCode()}',
          cause: e,
          stackTrace: stackTrace,
        );
      }
      rethrow;
    }
  }

  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
    ConflictAlgorithm?
    conflictAlgorithm, // Allow specifying conflict algorithm for update
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
        conflictAlgorithm: conflictAlgorithm, // Pass it through
      );
    } catch (e, stackTrace) {
      _log.severe('Error updating $table', e, stackTrace);
      if (e is DatabaseException) {
        throw DatabaseExceptions(
          'Update failed on $table: ${e.getResultCode()}',
          cause: e,
          stackTrace: stackTrace,
        );
      }
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
      if (e is DatabaseException) {
        throw DatabaseExceptions(
          'Delete failed on $table: ${e.getResultCode()}',
          cause: e,
          stackTrace: stackTrace,
        );
      }
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
      if (e is DatabaseException) {
        throw DatabaseExceptions(
          'Raw query failed: ${e.getResultCode()}',
          cause: e,
          stackTrace: stackTrace,
        );
      }
      rethrow;
    }
  }

  // --- Security ---
  // _hashPassword, _verifyPassword, _generateSecureToken remain the same
  String _hashPassword(String password) {
    return BCrypt.hashpw(password, BCrypt.gensalt(logRounds: 10));
  }

  bool _verifyPassword(String inputPassword, String storedHash) {
    // Handle potentially null or empty stored hash defensively
    if (storedHash.isEmpty) return false;
    try {
      return BCrypt.checkpw(inputPassword, storedHash);
    } catch (e) {
      // BCrypt can throw exceptions for invalid hash formats
      _log.warning('Password verification failed (check hash format?): $e');
      return false;
    }
  }

  String _generateSecureToken() {
    return _uuid.v4();
  }

  // --- User Operations ---
  // (upsertUser, insertLocalUser, createLocalUserWithPassword, etc. need update for role/permissions)

  Future<void> upsertUser(
    Map<String, dynamic> userData, {
    Transaction? txn,
  }) async {
    if (userData['id'] == null || userData['id'].isEmpty) {
      _log.severe("Cannot upsert user: Missing 'id'. Data: $userData");
      throw ArgumentError("User data must include a valid 'id' for upsert.");
    }
    _log.fine("Upserting user: ${userData['id']}");

    // Prepare data: Ensure role is string, permissions is JSON string
    if (userData.containsKey('role') && userData['role'] is UserRole) {
      userData['role'] = userRoleToString(userData['role']);
    } else if (!userData.containsKey('role')) {
      userData['role'] = 'patient'; // Default if missing
    }

    if (userData.containsKey('permissions') &&
        userData['permissions'] is List) {
      userData['permissions'] = jsonEncode(userData['permissions']);
    } else if (!userData.containsKey('permissions')) {
      userData['permissions'] = '[]'; // Default if missing
    }

    await insert(
      'users',
      userData,
      conflictAlgorithm: ConflictAlgorithm.replace,
      txn: txn,
    );
  }

  Future<UserModel> insertLocalUser(UserModel user, {Transaction? txn}) async {
    _log.info('Inserting local user: ${user.email}');
    if (user.id.isEmpty) {
      throw ArgumentError('User ID cannot be empty for insertion.');
    }
    // Use the user's toMap method, which should handle role/permissions correctly
    final Map<String, dynamic> userData =
        user.toJson(); // Assumes toMap encodes correctly
    userData['createdAt'] ??= DateTime.now().millisecondsSinceEpoch;
    userData.remove('password'); // Don't store plain password

    await insert(
      'users',
      userData,
      conflictAlgorithm:
          ConflictAlgorithm.fail, // Fail if user ID already exists
      txn: txn,
    );
    return user;
  }

  Future<UserModel> createLocalUserWithPassword(
    String name,
    String email,
    String password, {
    String? id,
    String? phoneNumber,
    UserRole role = UserRole.patient, // Add role parameter
    List<String>? permissions, // Add permissions parameter
    Transaction? txn,
  }) async {
    final userId = id ?? _uuid.v4();
    _log.info('Creating local user $userId with role $role for email: $email');

    final now = DateTime.now().millisecondsSinceEpoch;
    // Default permissions if null, otherwise use provided
    final effectivePermissions =
        permissions ?? _getDefaultPermissionsForRole(role);

    final userMap = {
      'id': userId,
      'firebaseId': null,
      'name': name,
      'email': email.toLowerCase(),
      'password': _hashPassword(password),
      'phoneNumber': phoneNumber,
      'profileImageUrl': null,
      'verified': 0,
      'createdAt': now,
      'lastLogin': now,
      'syncStatus': 1, // Needs sync
      'lastSynced': null,
      'role': userRoleToString(role), // Store role as string
      'permissions': jsonEncode(
        effectivePermissions,
      ), // Store permissions as JSON string
    };

    await insert(
      'users',
      userMap,
      conflictAlgorithm: ConflictAlgorithm.fail,
      txn: txn,
    );
    // Create UserModel from the map used for insertion
    return UserModel.fromMap(userMap);
  }

  // getUserById, getUserByFirebaseId, getUserByEmail remain the same

  Future<UserModel?> getUserById(String userId, {Transaction? txn}) async {
    final results = await query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
      txn: txn,
    );
    // Use the refined fromMap which handles role/permissions string -> enum/list
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
      where: 'email = ? COLLATE NOCASE', // Case-insensitive search
      whereArgs: [email.toLowerCase()],
      limit: 1,
      txn: txn,
    );
    return results.isNotEmpty ? UserModel.fromMap(results.first) : null;
  }

  Future<void> updateUser(
    UserModel user, {
    bool markForSync = true,
    Transaction? txn,
  }) async {
    _log.info('Updating user: ${user.id}');
    // Use the user's toMap method for consistency
    final updateData = user.toJson();

    // Remove fields that shouldn't be updated directly this way
    updateData.remove('id');
    updateData.remove('createdAt');
    updateData.remove('password'); // Use specific password update method

    if (markForSync) {
      updateData['syncStatus'] = 1; // Mark for push
      updateData['lastSynced'] = null;
    } else {
      // If not marking for sync, ensure syncStatus isn't accidentally changed
      updateData.remove('syncStatus');
      updateData.remove('lastSynced');
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

  // updateUserPassword, updateLastLogin, linkFirebaseId, deleteUser remain the same
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
        'syncStatus': 1, // Mark for sync? Depends on your logic
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
        'syncStatus': 0, // Assume synced after successful link
        'lastSynced': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [localUserId],
      txn: txn,
    );
  }

  Future<bool> deleteUser(String userId, {Transaction? txn}) async {
    _log.warning('Deleting user: $userId');
    return await transaction((innerTxn) async {
      // Cascade deletes should handle related data in tables with FOREIGN KEY ON DELETE CASCADE
      // Explicitly delete from tables with ON DELETE SET NULL if desired
      await delete(
        'fcm_tokens', // Example: Clean up tokens explicitly if SET NULL was used
        where: 'userId = ?',
        whereArgs: [userId],
        txn: innerTxn,
      );

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

  // --- Session Management ---
  // (createSession, validateSession, clearSession, clearAllSessionsForUser, clearExpiredSessions remain the same)
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

  Future<UserModel?> validateSession(String sessionId) async {
    _log.fine('Validating session: $sessionId');
    UserModel? user;
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
        user = await getUserById(
          userId,
          txn: txn,
        ); // Fetch user within transaction
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

  // --- Password Reset ---
  // (createPasswordResetToken, verifyAndUsePasswordResetToken, clearExpiredResetTokens remain the same)
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
      if (user.firebaseId != null && user.firebaseId!.isNotEmpty) {
        // Check for non-empty firebaseId
        _log.warning(
          'Password reset requested for Firebase-linked user ($email). Use Firebase SDK method `sendPasswordResetEmail`.',
        );
        throw FirebasePasswordResetRequiredException(email);
      }

      // Proceed with local password reset token generation ONLY if not Firebase linked
      if (user.password == null || user.password!.isEmpty) {
        _log.warning(
          'Password reset requested for local user ($email) with no local password set. Aborting token generation.',
        );
        return; // Cannot reset a non-existent local password
      }

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
      _log.info(
        "Password reset token generated. CALL BACKEND API TO SEND EMAIL with token: $generatedToken for email: $email",
      );
      // --- !!! Replace with actual backend call !!! ---
      // await YourApiClient.sendResetEmail(email: email, token: generatedToken);
      // --- !!! ----------------------------------- !!! ---
    }
    return generatedToken;
  }

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
        return;
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

  // --- FCM Token Management ---
  // (saveFcmToken, deactivateFcmToken, updateFcmTokenUserId, getActiveFcmTokens remain the same)
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
      {
        'userId': userId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isActive': 1, // Ensure it's active when associating with user
      },
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
      // Get tokens for non-logged-in users (if applicable)
      // whereClause += ' AND userId IS NULL';
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

  // --- Calendar Notes ---
  // (insertCalendarNote, getCalendarNoteById, etc. remain the same)
  Future<CalendarNote> insertCalendarNote(
    CalendarNote note, {
    Transaction? txn,
  }) async {
    // Assign ID if missing before insert
    if (note.id == null || note.id!.isEmpty) {
      note = note.copyWith(id: _uuid.v4());
    }
    note = note.copyWith(
      // Ensure createdAt is set
      createdAt: note.createdAt ?? DateTime.now(),
      // Ensure date is stored consistently (e.g., start of day UTC)
      date: DateTime(note.date.year, note.date.month, note.date.day),
    );

    await insert(
      'calendar_notes',
      note.toMap(), // Assumes toMap handles DateTime to int conversion
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
    // Ensure comparison uses start/end of day based on the input 'day'
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
      where: 'userId = ? AND date >= ? AND date <= ?', // Compare against millis
      whereArgs: [userId, startOfDay, endOfDay],
      orderBy: 'date ASC', // Or createdAt ASC
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
    // Ensure start/end capture the full days if needed
    final startMs =
        DateTime(start.year, start.month, start.day).millisecondsSinceEpoch;
    final endMs =
        DateTime(
          end.year,
          end.month,
          end.day,
          23,
          59,
          59,
          999,
        ).millisecondsSinceEpoch;
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
    // Ensure updatedAt is set and date is normalized
    note = note.copyWith(
      updatedAt: DateTime.now(),
      date: DateTime(note.date.year, note.date.month, note.date.day),
    );
    final count = await update(
      'calendar_notes',
      note.toMap(), // Assumes toMap includes id, updatedAt, normalized date
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

  // --- Video Operations ---
  // (upsertVideo, upsertVideos, getVideoById, getAllVideos, getVideosByCategory, searchVideos remain the same)
  Future<void> upsertVideo(
    Map<String, dynamic> videoData, {
    Transaction? txn,
  }) async {
    // Ensure user-specific fields are NOT in videoData
    videoData.remove('isFavorite');
    videoData.remove('watchedPosition');
    videoData.remove('lastWatched');

    // Validate required fields? (e.g., id, url, title)
    if (videoData['id'] == null ||
        videoData['url'] == null ||
        videoData['title'] == null) {
      _log.warning(
        "Skipping video upsert due to missing required fields: ${videoData['id']}",
      );
      return;
    }

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
      int upsertedCount = 0;
      for (final videoData in videosData) {
        videoData.remove('isFavorite');
        videoData.remove('watchedPosition');
        videoData.remove('lastWatched');

        // Basic validation before adding to batch
        if (videoData['id'] != null &&
            videoData['url'] != null &&
            videoData['title'] != null) {
          batch.insert(
            'app_videos',
            videoData,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          upsertedCount++;
        } else {
          _log.warning(
            "Skipping video in batch upsert due to missing fields: ${videoData['id']}",
          );
        }
      }
      if (upsertedCount > 0) {
        await batch.commit(noResult: true);
        _log.info('Finished upserting $upsertedCount videos.');
        // Rebuild FTS index if requested or after significant changes
        if (rebuildFts || upsertedCount > 50) {
          // Example threshold
          await _rebuildFtsIndex(txn: innerTxn); // Pass innerTxn
        }
      } else {
        _log.warning('No valid videos found to upsert in the provided list.');
      }
    });
  }

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
      where: 'category = ? COLLATE NOCASE', // Case-insensitive category search
      whereArgs: [category],
      orderBy: orderBy ?? 'publishedAt DESC',
      txn: txn,
    );
  }

  Future<List<Map<String, dynamic>>> searchVideos(
    String searchTerm, {
    Transaction? txn,
  }) async {
    if (searchTerm.trim().isEmpty) return [];
    _log.info('Searching videos for: "$searchTerm"');
    // Prepare query for FTS (prefix search)
    final ftsQuery = searchTerm
        .trim()
        .split(RegExp(r'\s+')) // Split by whitespace
        .where((t) => t.isNotEmpty)
        .map(
          (term) => term.endsWith('*') ? term : '$term*',
        ) // Add wildcard if not present
        .join(' ');

    if (ftsQuery.isEmpty) return [];

    _log.fine('FTS Query: $ftsQuery');

    final ftsResults = await query(
      'videos_fts',
      where: 'videos_fts MATCH ?', // Use MATCH operator
      whereArgs: [ftsQuery],
      columns: ['videoId'], // Get the original video IDs
      // FTS results are typically ordered by relevance automatically
      txn: txn,
    );

    if (ftsResults.isEmpty) {
      _log.info('No videos found matching "$searchTerm" via FTS.');
      return [];
    }

    final videoIds = ftsResults.map((row) => row['videoId'] as String).toList();
    final placeholders = List.filled(videoIds.length, '?').join(',');

    // Fetch full video details for matched IDs
    final videos = await query(
      'app_videos',
      where: 'id IN ($placeholders)',
      whereArgs: videoIds,
      txn: txn,
    );
    _log.info(
      'Found ${videos.length} video details matching "$searchTerm" via FTS.',
    );

    // Optional: Re-order based on FTS relevance if needed
    final orderedVideos =
        videoIds
            .map((id) {
              return videos.firstWhereOrNull((v) => v['id'] == id);
            })
            .whereNotNull()
            .toList(); // Filter out nulls if any ID mismatch occurred

    return orderedVideos;
  }

  // --- User Video Preferences ---
  // (setVideoFavorite, isVideoFavorite, getFavoriteVideos remain the same)
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
        // Update lastWatched or favoritedAt timestamp if needed
        // 'favoritedAt': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm:
          ConflictAlgorithm.replace, // Upsert based on (userId, videoId)
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
    return results.isNotEmpty &&
        (results.first['isFavorite'] as int? ?? 0) == 1;
  }

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
        ORDER BY v.publishedAt DESC -- Or order by when favorited if timestamp stored in user_video_prefs
     ''',
      [userId],
      txn,
    );
    _log.info('Found ${results.length} favorite videos for user $userId');
    return results;
  }

  // --- Recommendations (Updated to use JOIN for user prefs) ---
  Future<List<Map<String, dynamic>>> getRecommendedVideos({
    String? userId, // Add userId to potentially exclude favorited/watched
    int limit = 10,
    Transaction? txn,
  }) async {
    return await transaction((innerTxn) async {
      // --- Strategy:
      // 1. Get explicitly recommended videos (isRecommended=1)
      // 2. Get videos from preferred categories (e.g., 'pregnancy', 'nutrition')
      // 3. Get latest videos
      // --- Exclude videos the user has interacted with (favorited/watched recently)? (Optional)

      final Set<String> fetchedIds = {};
      final List<Map<String, dynamic>> results = [];
      String excludeClause = '';
      List<dynamic> excludeArgs = [];

      // Optional: Build exclusion list based on user interaction
      if (userId != null) {
        final userPrefs = await query(
          'user_video_prefs',
          where:
              'userId = ? AND (isFavorite = 1 OR lastWatched > ?)', // Favorited or watched in last 30 days?
          whereArgs: [
            userId,
            DateTime.now()
                .subtract(const Duration(days: 30))
                .millisecondsSinceEpoch,
          ],
          columns: ['videoId'],
          txn: innerTxn,
        );
        final excludedIds =
            userPrefs.map((p) => p['videoId'] as String).toSet();
        if (excludedIds.isNotEmpty) {
          excludeClause =
              'AND v.id NOT IN (${List.filled(excludedIds.length, '?').join(',')})';
          excludeArgs = excludedIds.toList();
          fetchedIds.addAll(
            excludedIds,
          ); // Also prevent re-fetching excluded ones
        }
      }

      // 1. Explicitly recommended videos
      if (results.length < limit) {
        final recommendedResults = await innerTxn.rawQuery(
          '''
             SELECT v.* FROM app_videos v
             WHERE v.isRecommended = 1 $excludeClause
             ORDER BY v.publishedAt DESC
             LIMIT ?
         ''',
          [...excludeArgs, limit - results.length],
        );

        results.addAll(recommendedResults);
        fetchedIds.addAll(recommendedResults.map((v) => v['id'] as String));
        _log.fine(
          "Fetched ${recommendedResults.length} explicitly recommended videos.",
        );
      }

      // 2. Key categories (if still needed)
      if (results.length < limit) {
        final Set<String> currentFetchedIds = Set.from(
          fetchedIds,
        ); // Copy for this query
        final categoryPlaceholders = List.filled(
          currentFetchedIds.length,
          '?',
        ).join(',');
        final categoryExcludeClause =
            currentFetchedIds.isNotEmpty
                ? 'AND v.id NOT IN ($categoryPlaceholders)'
                : '';

        final categoryResults = await innerTxn.rawQuery(
          '''
            SELECT v.* FROM app_videos v
            WHERE v.category IN (?, ?, ?) AND v.isRecommended = 0 $categoryExcludeClause
            ORDER BY RANDOM() -- Or publishedAt DESC
            LIMIT ?
        ''',
          [
            'pregnancy',
            'nutrition',
            'newborn',
            ...currentFetchedIds,
            limit - results.length,
          ],
        );

        results.addAll(categoryResults);
        fetchedIds.addAll(categoryResults.map((v) => v['id'] as String));
        _log.fine(
          "Fetched ${categoryResults.length} videos from key categories.",
        );
      }

      // 3. Latest videos (if still needed)
      if (results.length < limit) {
        final Set<String> currentFetchedIds = Set.from(
          fetchedIds,
        ); // Copy for this query
        final latestPlaceholders = List.filled(
          currentFetchedIds.length,
          '?',
        ).join(',');
        final latestExcludeClause =
            currentFetchedIds.isNotEmpty
                ? 'AND v.id NOT IN ($latestPlaceholders)'
                : '';

        final latestResults = await innerTxn.rawQuery(
          '''
            SELECT v.* FROM app_videos v
            WHERE v.isRecommended = 0 $latestExcludeClause
            ORDER BY v.publishedAt DESC
            LIMIT ?
         ''',
          [...currentFetchedIds, limit - results.length],
        );

        results.addAll(latestResults);
        _log.fine("Fetched ${latestResults.length} latest videos.");
      }

      _log.info('Fetched ${results.length} recommended videos.');
      // Ensure unique results just in case logic overlaps slightly
      final uniqueResults = results.map((e) => e['id']).toSet();
      results.retainWhere((x) => uniqueResults.remove(x['id']));

      return results;
    });
  }

  // --- Preferences ---
  // (savePreference, getPreference, etc. remain the same)
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
  // (setOnboardingCompleted, isOnboardingCompleted remain the same)
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

  // --- Pregnancy Details ---
  // (upsertPregnancyDetail, getPregnancyDetails remain the same)
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

  // --- Prediction History ---
  // (insertPredictionHistory, getPredictionHistory remain the same)
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

  // --- Favorite Hospitals ---
  // (addFavoriteHospital, getFavoriteHospitals, etc. remain the same)
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

    await insert(
      'favorite_hospitals',
      hospitalData,
      conflictAlgorithm:
          ConflictAlgorithm.replace, // Relies on UNIQUE (userId, googlePlaceId)
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

  // --- Firebase Sync Management ---
  // (updateLastSyncTimestamp, getLastSyncTimestamp remain the same)
  Future<void> updateLastSyncTimestamp(
    String collectionName, {
    int? timestamp,
    Transaction? txn,
  }) async {
    await insert(
      'sync_meta',
      {
        'collectionName': collectionName,
        'lastSyncTimestamp': timestamp ?? DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
      txn: txn,
    );
    _log.fine(
      // Use fine for potentially frequent operations
      'Updated last sync timestamp for $collectionName',
    );
  }

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
    // Default to 0 if no sync meta exists yet
    return result.isNotEmpty
        ? (result.first['lastSyncTimestamp'] as int? ?? 0)
        : 0;
  }

  // --- Firebase-Specific Operations ---
  // (assignPatientToNurse remains the same)
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
            // Safely handle potential null or incorrect type for patientIds
            var patientsData = data['patientIds'];
            if (patientsData is List) {
              // Ensure all elements are strings
              currentPatients = List<String>.from(
                patientsData
                    .map((item) => item.toString())
                    .where((s) => s.isNotEmpty),
              );
            }
          }

          // Example capacity limit - move to config?
          const capacityLimit = 5;
          if (currentPatients.length >= capacityLimit) {
            _log.severe(
              'Nurse $nurseId is at full capacity ($capacityLimit patients). Cannot assign $patientId.',
            );
            // Use a more specific exception if caught upstream
            throw Exception('Nurse at full capacity');
          }

          if (!currentPatients.contains(patientId)) {
            currentPatients.add(patientId);
            final timestamp = FieldValue.serverTimestamp();
            final updateData = {
              'patientIds':
                  currentPatients, // Or FieldValue.arrayUnion([patientId])
              'doctorId': doctorId, // Track who assigned
              'lastUpdated': timestamp,
            };

            if (exists) {
              firestoreTxn.update(assignmentRef, updateData);
            } else {
              // Set initial data if document doesn't exist
              firestoreTxn.set(assignmentRef, {
                'nurseId': nurseId,
                'createdAt': timestamp,
                ...updateData, // Include the common update fields
              });
            }
            _log.info(
              'Firestore transaction: Added patient $patientId to nurse $nurseId.',
            );
          } else {
            _log.warning(
              'Patient $patientId already assigned to nurse $nurseId in Firestore.',
            );
            // Optionally update 'lastUpdated' even if patient already exists?
            // firestoreTxn.update(assignmentRef, {'lastUpdated': FieldValue.serverTimestamp()});
          }
        })
        .catchError((error, stackTrace) {
          _log.severe(
            'Firestore transaction failed for nurse assignment',
            error,
            stackTrace,
          );
          // Rethrow a more specific exception if needed
          throw DatabaseExceptions(
            'Failed to assign patient via Firestore',
            cause: error,
          );
        });

    _log.info(
      'Successfully requested assignment of patient $patientId to nurse $nurseId via Firestore.',
    );
  }

  // --- Full Sync Example ---
  // (syncUsersWithFirebase, _syncLocalUsersToFirebase, _syncFirebaseUsersToLocal remain mostly the same,
  //  ensure they handle role/permissions correctly during sync)

  Future<void> syncUsersWithFirebase() async {
    _log.info('Starting user sync with Firebase...');
    bool syncErrorOccurred = false;
    int lastSuccessfulSyncTime = await getLastSyncTimestamp('users');
    int currentTimestampForNextSync =
        DateTime.now()
            .millisecondsSinceEpoch; // Capture time *before* sync starts

    try {
      await transaction((txn) async {
        // 1. Push local changes -> Firestore
        await _syncLocalUsersToFirebase(txn);

        // 2. Pull Firebase changes -> local DB
        final latestFirebaseTimestamp = await _syncFirebaseUsersToLocal(
          txn,
          lastSuccessfulSyncTime,
        );

        // Use the later of the initial timestamp or the latest from Firebase
        // This prevents missing updates that occurred during the sync process
        lastSuccessfulSyncTime =
            latestFirebaseTimestamp > currentTimestampForNextSync
                ? latestFirebaseTimestamp
                : currentTimestampForNextSync;

        // Update sync timestamp ONLY if pull was successful (no exception thrown)
        await updateLastSyncTimestamp(
          'users',
          timestamp: lastSuccessfulSyncTime,
          txn: txn,
        );
      });
      _log.info('User sync cycle completed successfully.');
    } on Exception catch (e, stackTrace) {
      // Catch specific exceptions if needed
      syncErrorOccurred = true;
      _log.severe('User sync cycle failed', e, stackTrace);
      // Don't update lastSuccessfulSyncTime on failure
      // Consider logging error to a persistent store for later analysis/retry
    } finally {
      // Optionally trigger UI refresh regardless of success/failure
      // to reflect potential partial updates or error states
    }
  }

  // Push local -> Firebase (Needs to send role/permissions)
  Future<void> _syncLocalUsersToFirebase(Transaction txn) async {
    _log.fine('Sync Phase 1: Pushing local user changes to Firestore...');
    final unsyncedUsers = await query(
      'users',
      where: 'syncStatus = ?', // 1 = NeedsPush
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
      // Use UserModel.fromMap which decodes role/permissions correctly
      final user = UserModel.fromMap(userMap);
      final Map<String, dynamic> firebaseData = {
        // Map fields from UserModel to Firestore fields
        'name': user.name,
        'email': user.email, // Already lowercase from creation/update
        'phoneNumber': user.phoneNumber,
        'profileImageUrl': user.profileImageUrl,
        'verified':
            user.verified, // Send bool/int based on Firestore expectation
        'role': userRoleToString(user.role), // Convert enum to string
        'permissions': user.permissions, // Send the List<String> directly
        // Do NOT sync password hash
        // 'localId': user.id, // Optional reference
      };

      try {
        DocumentReference userDocRef;
        if (user.firebaseId == null || user.firebaseId!.isEmpty) {
          // This scenario should ideally be minimized. User linking should happen first.
          // If we push using local ID, linking later becomes harder.
          _log.warning(
            'Sync Phase 1: Attempting to push user ${user.id} (local ID only) to Firestore. This is generally discouraged. Linking should occur first.',
          );
          // Option A: Skip push until firebaseId is linked (better)
          // continue;
          // Option B: Push using local ID (requires careful handling later)
          userDocRef = _usersCollection.doc(
            user.id,
          ); // Use local UUID as Firestore doc ID
          firebaseData['createdAt'] =
              FieldValue.serverTimestamp(); // Set on first push
          firebaseData['lastUpdated'] = FieldValue.serverTimestamp();
          await userDocRef.set(
            firebaseData,
            SetOptions(merge: true),
          ); // Use set to create
          _log.info(
            'Sync Phase 1: Pushed Firestore document for local user ${user.id}. Needs linking!',
          );
          // DO NOT mark as synced locally (status remains 1)
        } else {
          // Update existing Firebase document
          _log.fine(
            'Sync Phase 1: Pushing update for user ${user.firebaseId} to Firestore.',
          );
          userDocRef = _usersCollection.doc(user.firebaseId!);
          firebaseData['lastUpdated'] = FieldValue.serverTimestamp();
          await userDocRef.update(firebaseData); // Update existing doc

          // Mark local user as synced (syncStatus = 0)
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
        continue; // Continue with next user
      }
    }
  }

  // Pull Firebase -> Local (Needs to handle role/permissions)
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
    int latestTimestampPulled = lastSyncTimestamp; // Track newest timestamp

    try {
      final querySnapshot =
          await _usersCollection
              .where('lastUpdated', isGreaterThan: lastSyncTime)
              .orderBy('lastUpdated', descending: false)
              .get();

      if (querySnapshot.docs.isEmpty) {
        _log.fine('Sync Phase 2: No new user changes in Firebase.');
        return lastSyncTimestamp;
      }
      _log.info(
        'Sync Phase 2: Found ${querySnapshot.docs.length} users updated in Firebase.',
      );

      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?; // Use null-safe cast
        final firebaseId = doc.id;

        if (data == null) {
          _log.warning(
            'Sync Phase 2: Skipping Firebase doc $firebaseId (null data).',
          );
          continue;
        }

        // Update latest timestamp processed for reliable next sync
        final lastUpdatedMillis =
            (data['lastUpdated'] as Timestamp?)?.millisecondsSinceEpoch;
        if (lastUpdatedMillis != null &&
            lastUpdatedMillis > latestTimestampPulled) {
          latestTimestampPulled = lastUpdatedMillis;
        }

        final email = data['email'] as String?;
        if (email == null || email.isEmpty) {
          _log.warning(
            'Sync Phase 2: Skipping Firebase doc $firebaseId (missing or empty email).',
          );
          continue;
        }

        // Find local user by firebaseId first, then by email as fallback
        UserModel? localUser =
            await getUserByFirebaseId(firebaseId, txn: txn) ??
            await getUserByEmail(email, txn: txn);

        final now = DateTime.now().millisecondsSinceEpoch;
        // Prepare data for local upsert, converting types
        final Map<String, dynamic> localData = {
          'firebaseId': firebaseId,
          'email': email.toLowerCase(),
          'name': data['name'] as String? ?? 'Unknown',
          'phoneNumber': data['phoneNumber'] as String?,
          'profileImageUrl': data['profileImageUrl'] as String?,
          'verified':
              (data['verified'] == true || data['verified'] == 1) ? 1 : 0,
          'createdAt':
              (data['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
              now, // Use Firestore creation time if available
          'lastLogin':
              (data['lastLogin'] as Timestamp?)
                  ?.millisecondsSinceEpoch, // Firestore's login time
          'role':
              data['role'] as String? ?? 'patient', // Get role string, default
          'permissions': jsonEncode(
            data['permissions'] as List? ?? [],
          ), // Get list, encode to string
          'syncStatus': 0, // Mark as synced after pull
          'lastSynced': now,
          'password': null, // Never import password
        };

        if (localUser != null) {
          // --- Update existing local user ---
          _log.fine(
            'Sync Phase 2: Updating local user ${localUser.id} from Firebase doc $firebaseId',
          );
          // Ensure we don't overwrite critical local fields unless intended
          localData['id'] = localUser.id; // Keep existing local primary key
          localData['password'] =
              localUser.password; // Keep existing local password hash
          localData['createdAt'] =
              localUser.createdAt ??
              localData['createdAt']; // Prefer existing local creation time

          // If firebaseId was missing locally but email matched, link them now
          if (localUser.firebaseId == null || localUser.firebaseId!.isEmpty) {
            _log.info(
              'Sync Phase 2: Linking existing local user ${localUser.id} (email: $email) to firebaseId $firebaseId.',
            );
            localData['firebaseId'] = firebaseId; // Add the firebaseId
          }

          // Use UPDATE instead of INSERT OR REPLACE to avoid accidentally changing ID
          await update(
            'users',
            localData,
            where: 'id = ?',
            whereArgs: [localUser.id],
            txn: txn,
          );
        } else {
          // --- Insert new local user ---
          _log.fine(
            'Sync Phase 2: Inserting new local user from Firebase doc $firebaseId',
          );
          localData['id'] = _uuid.v4(); // Generate a NEW local UUID
          await insert(
            'users',
            localData,
            conflictAlgorithm:
                ConflictAlgorithm.replace, // Should not conflict with UUIDv4
            txn: txn,
          );
        }
      }
      _log.info(
        'Sync Phase 2: Finished processing ${querySnapshot.docs.length} Firebase changes.',
      );
      return latestTimestampPulled; // Return the timestamp of the last processed record
    } catch (e, stackTrace) {
      _log.severe(
        'Sync Phase 2: Error pulling users from Firebase',
        e,
        stackTrace,
      );
      // Rethrow to signal failure to the outer transaction
      throw DatabaseExceptions(
        'Failed to sync Firebase users to local',
        cause: e,
      );
    }
  }

  // --- Database Maintenance ---
  // (performMaintenance, vacuumDatabase, close remain the same)
  Future<void> performMaintenance() async {
    _log.info('Performing database maintenance...');
    try {
      await transaction((txn) async {
        await clearExpiredSessions(txn: txn);
        await clearExpiredResetTokens(txn: txn);
        // Clean up old notifications (e.g., older than 90 days)
        final ninetyDaysAgo =
            DateTime.now()
                .subtract(const Duration(days: 90))
                .millisecondsSinceEpoch;
        final deletedNotifs = await delete(
          // Use delete helper
          'notifications',
          where: 'timestamp < ?',
          whereArgs: [ninetyDaysAgo],
          txn: txn,
        );
        _log.info('Cleared $deletedNotifs old notifications.');
        // Add other cleanup tasks:
        // - Clear old prediction history?
        // - Deactivate old/unused FCM tokens?
      });
      _log.info('Database maintenance completed.');
      // Optional: Vacuum after maintenance if significant data was deleted
      // await vacuumDatabase();
    } catch (e, stackTrace) {
      _log.severe('Database maintenance failed', e, stackTrace);
    }
  }

  Future<void> vacuumDatabase() async {
    _log.info("Vacuuming database...");
    final db = await database;
    try {
      await db.execute('VACUUM;');
      _log.info("Database vacuum complete.");
    } catch (e, stackTrace) {
      _log.severe("Database vacuum failed", e, stackTrace);
    }
  }

  Future<void> close() async {
    final db = _database; // Use local copy
    if (db != null && db.isOpen) {
      await db.close();
      _database = null;
      _log.info('Database closed.');
    }
  }

  // --- Database Export ---
  // (exportDatabase remains the same)
  Future<void> exportDatabase(String backupPath) async {
    _log.info('Attempting to export database to: $backupPath');
    final db = await database;
    final currentPath = db.path; // Get current path before potentially closing
    try {
      // Close DB before attempting copy/vacuum for safety on some platforms
      await close();
      _log.info('Database closed for export.');

      // Attempt VACUUM INTO first (preferred)
      // Reopen temporarily just for VACUUM INTO
      final tempDb = await openDatabase(currentPath, readOnly: false);
      await tempDb.execute('VACUUM INTO ?', [backupPath]);
      await tempDb.close(); // Close the temporary handle
      _log.info('Database successfully exported using VACUUM INTO.');
    } catch (e) {
      _log.warning(
        'VACUUM INTO failed (SQLite version might be < 3.27.0 or other issue). Error: $e',
      );
      _log.severe(
        'Manual file copy fallback is NOT IMPLEMENTED. Database export failed.',
      );
      // Ensure DB is reopened if VACUUM failed but close succeeded before
      if (_database == null) await database;
      throw DatabaseExceptions(
        "Database export failed. VACUUM INTO error.",
        cause: e,
      );
    } finally {
      // Ensure the main database handle is reopened if it was closed
      if (_database == null) {
        _log.info('Reopening main database handle after export attempt.');
        await database; // Re-initializes _database if null
      }
    }
  }

  // --- Helper to get default permissions ---
  List<String> _getDefaultPermissionsForRole(UserRole role) {
    // Duplicated from AuthViewModel - consider moving to a shared location/service
    switch (role) {
      case UserRole.patient:
        return [
          'view_profile',
          'view_appointments',
          'request_appointment',
          'view_articles',
          'view_videos',
          'view_timeline',
          'view_calendar',
        ];
      case UserRole.nurse:
        return [
          'view_profile',
          'view_assigned_patients',
          'manage_own_appointments',
          'edit_patient_notes',
          'view_articles',
          'view_videos',
        ];
      case UserRole.doctor:
        return [
          'view_profile',
          'view_all_patients',
          'manage_appointments',
          'assign_nurse',
          'manage_nurses',
          'view_reports',
          'edit_articles',
          'edit_videos',
        ];
      case UserRole.admin:
        return [
          'manage_users',
          'manage_roles',
          'manage_content',
          'view_all_data',
          'configure_settings',
        ];
      case UserRole.unknown:
        return [];
    }
  }
}

// --- Ensure UserModel.fromMap and toMap handle role/permissions correctly ---

// Example (assuming UserModel exists elsewhere and needs updating)
/*
extension UserModelDbMapping on UserModel {
  // Converts UserModel instance to Map for SQLite
  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'firebaseId': firebaseId,
      'email': email,
      'name': name,
      'password': password, // Be cautious storing password hash
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
      'verified': verified ? 1 : 0,
      'createdAt': createdAt,
      'lastLogin': lastLogin,
      'syncStatus': syncStatus,
      'lastSynced': lastSynced,
      'role': userRoleToString(role), // Convert enum to string
      'permissions': jsonEncode(permissions), // Convert list to JSON string
    };
  }

  // Creates UserModel from SQLite Map data
  static UserModel fromSqliteMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      firebaseId: map['firebaseId'] as String?,
      email: map['email'] as String? ?? '',
      name: map['name'] as String? ?? '',
      password: map['password'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      profileImageUrl: map['profileImageUrl'] as String?,
      verified: (map['verified'] as int? ?? 0) == 1,
      createdAt: map['createdAt'] as int? ?? 0,
      lastLogin: map['lastLogin'] as int?,
      syncStatus: map['syncStatus'] as int? ?? 0,
      lastSynced: map['lastSynced'] as int?,
      // Convert string from DB back to enum
      role: stringToUserRole(map['role'] as String? ?? 'unknown'),
      // Decode JSON string from DB back to list
      permissions: (jsonDecode(map['permissions'] as String? ?? '[]') as List)
                     .map((item) => item.toString())
                     .toList(),
    );
  }
}
// You would also need stringToUserRole function
UserRole stringToUserRole(String roleString) {
  return UserRole.values.firstWhere(
    (e) => userRoleToString(e) == roleString.toLowerCase(),
    orElse: () => UserRole.unknown,
  );
}
// And userRoleToString (if not already defined elsewhere)
String userRoleToString(UserRole role) {
   return role.name; // Assumes Dart 2.15+ enum .name getter
}
*/
