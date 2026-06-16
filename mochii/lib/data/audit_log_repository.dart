import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AuditLog {
  const AuditLog({
    this.id,
    required this.timestamp,
    required this.actionType,
    required this.status,
    this.imagePath,
    this.attemptCount = 0,
    this.lastError,
  });

  final int? id;
  final DateTime timestamp;
  final String actionType;
  final String status;
  final String? imagePath;
  final int attemptCount;
  final String? lastError;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'action_type': actionType,
      'status': status,
      'image_path': imagePath,
      'attempt_count': attemptCount,
      'last_error': lastError,
    };
  }

  factory AuditLog.fromMap(Map<String, dynamic> map) {
    return AuditLog(
      id: map['id'] as int,
      timestamp: DateTime.parse(map['timestamp'] as String),
      actionType: map['action_type'] as String,
      status: map['status'] as String,
      imagePath: map['image_path'] as String?,
      attemptCount: (map['attempt_count'] as int?) ?? 0,
      lastError: map['last_error'] as String?,
    );
  }
}

class AuditLogRepository {
  static const String _databaseName = 'digital_collar.db';
  static const int _databaseVersion = 2;
  static const String tableName = 'audit_logs';

  Database? _db;

  Future<Database> get database async {
    if (_db != null) {
      return _db!;
    }

    final String dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, _databaseName),
      version: _databaseVersion,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE $tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            action_type TEXT NOT NULL,
            status TEXT NOT NULL CHECK(status IN ('pending', 'uploaded')),
            image_path TEXT,
            attempt_count INTEGER NOT NULL DEFAULT 0,
            last_error TEXT
          )
        ''');
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 2) {
          await _safeAddColumn(
            db,
            'ALTER TABLE $tableName ADD COLUMN image_path TEXT',
          );
          await _safeAddColumn(
            db,
            'ALTER TABLE $tableName ADD COLUMN attempt_count INTEGER NOT NULL DEFAULT 0',
          );
          await _safeAddColumn(
            db,
            'ALTER TABLE $tableName ADD COLUMN last_error TEXT',
          );
        }
      },
    );

    return _db!;
  }

  Future<void> _safeAddColumn(Database db, String sql) async {
    try {
      await db.execute(sql);
    } on DatabaseException {
      // Ignore duplicate-column style upgrade races.
    }
  }

  Future<int> insertAuditLog(AuditLog log) async {
    final Database db = await database;
    return db.insert(tableName, log.toMap());
  }

  Future<List<AuditLog>> getPendingLogs({String? actionType}) async {
    final Database db = await database;
    final String whereClause = actionType == null
        ? 'status = ?'
        : 'status = ? AND action_type = ?';
    final List<Object> whereArgs = actionType == null
        ? <Object>['pending']
        : <Object>['pending', actionType];

    final List<Map<String, dynamic>> rows = await db.query(
      tableName,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'timestamp ASC',
    );

    return rows.map(AuditLog.fromMap).toList();
  }

  Future<int> addPendingTrustFall({required String imagePath}) async {
    return insertAuditLog(
      AuditLog(
        timestamp: DateTime.now().toUtc(),
        actionType: 'trust_fall',
        status: 'pending',
        imagePath: imagePath,
      ),
    );
  }

  Future<int> markUploaded(int id) async {
    final Database db = await database;
    return db.update(
      tableName,
      <String, Object>{'status': 'uploaded'},
      where: 'id = ?',
      whereArgs: <Object>[id],
    );
  }

  Future<int> markUploadAttemptFailed(int id, {required String error}) async {
    final Database db = await database;
    return db.rawUpdate(
      'UPDATE $tableName SET attempt_count = attempt_count + 1, last_error = ? WHERE id = ?',
      <Object>[error, id],
    );
  }
}
