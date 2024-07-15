import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:clockwork/database/time_entry.dart';
import 'dart:developer' as developer;

class DatabaseHelper {
  static const _databaseName = "TimeEntryDatabase.db";
  static const _databaseVersion = 1;

  static const table = 'time_entries';

  static const columnId = 'id';
  static const columnJob = 'job';
  static const columnStart = 'start';
  static const columnEnd = 'end';

  // Make this a singleton class
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);
    return await openDatabase(path,
        version: _databaseVersion, onCreate: _onCreate);
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $table (
        $columnId TEXT PRIMARY KEY,
        $columnJob TEXT NOT NULL,
        $columnStart TEXT NOT NULL,
        $columnEnd TEXT
      )
    ''');
  }

  // Store the last deleted or updated entry for undo operation
  TimeEntry? _lastDeletedEntry;

  Future<int> insert(TimeEntry entry) async {
    Database db = await database;
    int id = await db.insert(table, entry.toMap());
    developer.log('Inserted TimeEntry with id: $id', name: 'DatabaseHelper');
    return id;
  }

  Future<List<TimeEntry>> queryAllEntries() async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(table);
    developer.log('Retrieved ${maps.length} entries from database',
        name: 'DatabaseHelper');
    return List.generate(maps.length, (i) {
      return TimeEntry.fromMap(maps[i]);
    });
  }

  Future<int> update(TimeEntry entry) async {
    Database db = await database;
    int count = await db.update(table, entry.toMap(),
        where: '$columnId = ?', whereArgs: [entry.id]);
    developer.log('Updated TimeEntry with id: ${entry.id}',
        name: 'DatabaseHelper');
    return count;
  }

  Future<int> delete(String id) async {
    Database db = await database;
    var entryMaps =
        await db.query(table, where: '$columnId = ?', whereArgs: [id]);
    if (entryMaps.isNotEmpty) {
      _lastDeletedEntry = TimeEntry.fromMap(entryMaps.first);
    }
    int count = await db.delete(table, where: '$columnId = ?', whereArgs: [id]);
    developer.log('Deleted TimeEntry with id: $id', name: 'DatabaseHelper');
    return count;
  }

  Future<void> undoDelete() async {
    if (_lastDeletedEntry != null) {
      await insert(_lastDeletedEntry!);
      _lastDeletedEntry = null;
    }
  }

  // New method to view all entries in the database
  Future<void> printAllEntries() async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(table);
    developer.log('Current database contents:', name: 'DatabaseHelper');
    for (var map in maps) {
      developer.log(map.toString(), name: 'DatabaseHelper');
    }
  }
}
