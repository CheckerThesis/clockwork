import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:clockwork/database/time_entry.dart';
import 'package:http/http.dart' as http;
import 'dart:developer' as developer;

class DatabaseHelper {
  static const String tableName = 'timeEntries';

  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  DatabaseHelper._privateConstructor();
  static Database? _database;

  Future<Database> get database async {
    return _database ??= await _initDatabase();
  }

  Future<Database> _initDatabase() async {
    return await openDatabase(
      join(await getDatabasesPath(), 'time_entries_database.db'),
      onCreate: (db, version) {
        return db.execute('''
          CREATE TABLE $tableName(
            id INTEGER PRIMARY KEY, 
            job TEXT, 
            start TEXT, 
            end TEXT, 
            duration TEXT, 
            needsSync INTEGER NOT NULL DEFAULT 1 CHECK(needsSync IN (0,1)),
            isDeleted INTEGER NOT NULL DEFAULT 0 CHECK(isDeleted IN (0,1))
          )
          ''');
      },
      version: 1,
    );
  }

  Future<void> syncDatabases() async {
    var azureList = await retrieveAzure();
    var localList = await retrieveLocal();

    for (var azureEntry in azureList) {
      if (!localList.any((localEntry) => localEntry.id == azureEntry.id)) {
        // Entry exists in Azure but not in local database
        azureEntry.needsSync = false;
        await writeLocal(azureEntry, true);
        developer.log(
            "Added entry from Azure to local database: ${azureEntry.id}",
            name: "syncDatabases");
      }
    }
  }

  Future<List<TimeEntry>> getNeedsSync(
      Future<List<TimeEntry>> futureTimeEntries) async {
    final timeEntries = await futureTimeEntries;
    return timeEntries.where((timeEntry) => timeEntry.needsSync).toList();
  }

  Future<List<TimeEntry>> retrieveAzure() async {
    HttpOverrides.global = MyHttpOverrides();
    final url = Uri.parse("https://10.0.2.2:7192/api/Items");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((json) => TimeEntry.fromJson(json)).toList();
    } else {
      developer.log("Error code: ${response.statusCode}");
      throw Exception('Failed to retrieve Azure data');
    }
  }

  Future<List<TimeEntry>> retrieveLocal() async {
    final db = await database;
    final List<Map<String, dynamic>> timeEntryMaps = await db.query(tableName);

    return List.generate(
        timeEntryMaps.length, (i) => TimeEntry.fromJson(timeEntryMaps[i]));
  }

  Future<int?> writeAzure(TimeEntry timeEntry) async {
    HttpOverrides.global = MyHttpOverrides();
    final url = Uri.parse("https://10.0.2.2:7192/api/Items");
    try {
      final response = await http
          .post(
            url,
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
            },
            body: jsonEncode(timeEntry.toJson()),
          )
          .timeout(Duration(seconds: 4));

      if (response.statusCode == 201) {
        developer.log("Entry written to Azure successfully",
            name: "writeAzure");
        Map<String, dynamic> responseBody = jsonDecode(response.body);
        return responseBody['id'];
      } else {
        throw Exception(
            "Failed to write entry. Status code: ${response.statusCode}");
      }
    } catch (e) {
      developer.log("Failed to write to Azure: $e", name: "writeAzure");
      return null;
    }
  }

  Future<void> writeLocal(TimeEntry timeEntry,
      [bool? writeToBoth = null]) async {
    final db = await database;

    if (writeToBoth == null) {
      int? azureId = await writeAzure(timeEntry);

      if (azureId != null) {
        timeEntry.id = azureId;
        timeEntry.needsSync = false;
      } else {
        final int maxLocalId = Sqflite.firstIntValue(await db
                .rawQuery('SELECT MIN(id) FROM $tableName WHERE id < 0')) ??
            0;
        timeEntry.id = maxLocalId - 1;
      }
      await db.insert(
        tableName,
        timeEntry.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      await db.insert(
        tableName,
        timeEntry.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> updateAzure(TimeEntry timeEntry) async {
    final url = Uri.parse("https://10.0.2.2:7192/api/Items/${timeEntry.id}");
    final response = await http.put(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(timeEntry.toJson()),
    );

    if (response.statusCode == 204) {
      developer.log("Entry updated to Azure successfully");
    } else {
      developer.log(
          "Failed to update entry with ID ${timeEntry.id}. Status code: ${response.statusCode}",
          name: "updateAzure");
      developer.log("Response body: ${response.body}", name: "updateAzure");
      throw Exception("Failed to update entry in Azure");
    }
  }

  Future<void> updateLocal(TimeEntry timeEntry) async {
    final db = await database;

    await db.update(
      tableName,
      timeEntry.toJson(),
      where: 'id = ?',
      whereArgs: [timeEntry.id],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteAzure(int id) async {
    final url = Uri.parse("https://10.0.2.2:7192/api/Items/$id");
    final response = await http.delete(
      url,
      headers: <String, String>{
        "Content-Type": "application/json; charset=UTF-8",
      },
    );

    if (response.statusCode == 204) {
      developer.log("Entry with ID $id deleted from Azure successfully",
          name: "deleteAzure");
    } else {
      developer
          .log("Failed to delete entry. Status code: ${response.statusCode}");
      developer.log("Response body: ${response.body}");
      throw Exception("Failed to delete entry from Azure");
    }
  }

  Future<void> deleteLocal(int id) async {
    final db = await database;

    await db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  void printAzure() async {
    try {
      List<TimeEntry> timeEntries = await retrieveAzure();

      developer.log("Azure entries");

      for (var timeEntry in timeEntries) {
        developer.log(timeEntry.toString());
      }
    } catch (e) {
      developer.log("Error fetching data from Azure: $e", name: "printAzure");
    }
  }

  void printLocal() async {
    List<TimeEntry> timeEntries = await instance.retrieveLocal();

    developer.log("Local entries");

    for (var timeEntry in timeEntries) {
      developer.log(timeEntry.toString());
    }
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}
