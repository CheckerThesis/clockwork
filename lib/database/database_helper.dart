import 'dart:async';
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
    try {
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
    } catch (e) {
      _logError('_initDatabase', e);
      rethrow;
    }
  }

  Future<bool> checkAzureConnection() async {
    HttpOverrides.global = MyHttpOverrides();
    final url = Uri.parse("https://10.0.2.2:7192/api/Items");

    try {
      final response = await http.get(url).timeout(Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      _logError('checkAzureConnection', e);
      return false;
    }
  }

  Future<void> syncDatabases() async {
    try {
      bool isConnected = await checkAzureConnection();
      if (!isConnected) {
        _logError('syncDatabases', 'No connection to Azure database');
        return;
      }

      var azureList = await retrieveAzure();
      var localList = await retrieveLocal();

      for (var azureEntry in azureList) {
        var localEntry =
            localList.firstWhere((entry) => entry.id == azureEntry.id);
        if (!localList.any((localEntry) => localEntry.id == azureEntry.id)) {
          azureEntry.needsSync = false;
          await writeLocal(azureEntry, true);
          _logSuccess('syncDatabases',
              "Added entry from Azure to local database: ${azureEntry.id}");
        } else if (azureEntry.job != localEntry.job ||
            azureEntry.start != localEntry.start ||
            azureEntry.end != localEntry.end ||
            azureEntry.duration != localEntry.duration) {
          print(azureEntry.id);
          writeLocal(azureEntry, true);
        }

        // check if current azureEntry and compare with localEntry
      }

      for (var localEntry in localList.reversed) {
        if (localEntry.isDeleted && localEntry.id! < 0) {
          await deleteLocal(localEntry.id);
        } else if (localEntry.isDeleted) {
          await deleteAzure(localEntry.id);
          await deleteLocal(localEntry.id);
        } else if (localEntry.id! < 0) {
          int? azureId = await writeAzure(localEntry);

          TimeEntry newEntry = TimeEntry(
            id: azureId,
            job: localEntry.job,
            start: localEntry.start,
            end: localEntry.end,
            needsSync: false,
          );
          await writeLocal(newEntry, true);

          // Delete the old entry with the negative ID
          await deleteLocal(localEntry.id!);
          _logSuccess('syncDatabases',
              "Synced local entry to Azure and removed local copy: ${localEntry.id}");
        } else if (!azureList
                .any((azureEntry) => azureEntry.id == localEntry.id) &&
            localEntry.needsSync == false) {
          await deleteLocal(localEntry.id);
        } else if (localEntry.needsSync == true &&
            azureList.any((azureEntry) => azureEntry.id == localEntry.id)) {
          localEntry.needsSync = false;
          writeLocal(localEntry, true);
          writeAzure(localEntry);
        }
      }
      _logSuccess(
          'syncDatabases', "Database synchronization completed successfully");
    } catch (e) {
      _logError('syncDatabases', e);
    }
  }

  Future<void> markForDeletion(int targetId) async {
    try {
      final db = await database;

      // Update the isDeleted status in the database
      await db.update(
        tableName,
        {'isDeleted': 1}, // SQLite uses 1 for true
        where: 'id = ?',
        whereArgs: [targetId],
      );

      _logSuccess(
          'markForDeletion', "Entry marked for deletion with ID: $targetId");
    } catch (e) {
      _logError('markForDeletion', e);
      rethrow;
    }
  }

  Future<List<TimeEntry>> retrieveAzure() async {
    HttpOverrides.global = MyHttpOverrides();
    final url = Uri.parse("https://10.0.2.2:7192/api/Items");

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        List<dynamic> jsonList = jsonDecode(response.body);
        List<TimeEntry> entries =
            jsonList.map((json) => TimeEntry.fromJson(json)).toList();
        _logSuccess(
            'retrieveAzure', "Retrieved ${entries.length} entries from Azure");
        return entries;
      }
      throw HttpException(
          'Failed to retrieve Azure data: Status ${response.statusCode}');
    } on SocketException catch (e) {
      _logError('retrieveAzure', e, 'Network error');
      return [];
    } on HttpException catch (e) {
      _logError('retrieveAzure', e, 'HTTP error');
      return [];
    } on FormatException catch (e) {
      _logError('retrieveAzure', e, 'Data format error');
      return [];
    } catch (e) {
      _logError('retrieveAzure', e);
      return [];
    }
  }

  Future<List<TimeEntry>> retrieveLocal() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> timeEntryMaps =
          await db.query(tableName);
      List<TimeEntry> entries = List.generate(
          timeEntryMaps.length, (i) => TimeEntry.fromJson(timeEntryMaps[i]));
      _logSuccess('retrieveLocal',
          "Retrieved ${entries.length} entries from local database");
      return entries;
    } catch (e) {
      _logError('retrieveLocal', e);
      return [];
    }
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
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 201) {
        Map<String, dynamic> responseBody = jsonDecode(response.body);
        _logSuccess('writeAzure',
            "Entry written to Azure successfully with ID: ${responseBody['id']}");
        return responseBody['id'];
      } else if (response.statusCode == 200) {
        Map<String, dynamic> responseBody = jsonDecode(response.body);
        _logSuccess('writeAzure',
            "Entry updated to Azure successfully with ID: ${responseBody['id']}");
        return responseBody['id'];
      }
      throw HttpException(
          "Failed to write entry. Status code: ${response.statusCode}");
    } on TimeoutException catch (e) {
      _logError('writeAzure', e, 'Request timed out');
      return null;
    } on SocketException catch (e) {
      _logError('writeAzure', e, 'Network error');
      return null;
    } on HttpException catch (e) {
      _logError('writeAzure', e, 'HTTP error');
      return null;
    } on FormatException catch (e) {
      _logError('writeAzure', e, 'Data format error');
      return null;
    } catch (e) {
      _logError('writeAzure', e);
      return null;
    }
  }

  Future<void> writeLocal(TimeEntry timeEntry, [bool? writeToBoth]) async {
    try {
      final db = await database;

      if (writeToBoth == null) {
        // Get the azureId
        int? azureId = await writeAzure(timeEntry);
        if (azureId != null) {
          // Assign azureId to entryId
          timeEntry.id = azureId;
          timeEntry.needsSync = false;
        } else {
          // Decrement from negative
          final int maxLocalId = Sqflite.firstIntValue(await db
                  .rawQuery('SELECT MIN(id) FROM $tableName WHERE id < 0')) ??
              0;
          timeEntry.id = maxLocalId - 1;
        }
      }

      await db.insert(
        tableName,
        timeEntry.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _logSuccess('writeLocal',
          "Entry written to local database with ID: ${timeEntry.id}");
    } catch (e) {
      _logError('writeLocal', e);
      rethrow;
    }
  }

  Future<void> updateAzure(TimeEntry timeEntry) async {
    final url = Uri.parse("https://10.0.2.2:7192/api/Items/${timeEntry.id}");
    try {
      final response = await http.put(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(timeEntry.toJson()),
      );

      if (response.statusCode == 204) {
        _logSuccess('updateAzure',
            "Entry updated in Azure successfully with ID: ${timeEntry.id}");
      } else {
        throw HttpException(
            "Failed to update entry in Azure. Status code: ${response.statusCode}");
      }
    } on SocketException catch (e) {
      _logError('updateAzure', e, 'Network error');
      rethrow;
    } on HttpException catch (e) {
      _logError('updateAzure', e, 'HTTP error');
      rethrow;
    } on FormatException catch (e) {
      _logError('updateAzure', e, 'Data format error');
      rethrow;
    } catch (e) {
      _logError('updateAzure', e);
      rethrow;
    }
  }

  Future<void> updateLocal(TimeEntry timeEntry) async {
    try {
      final db = await database;
      await db.update(
        tableName,
        timeEntry.toJson(),
        where: 'id = ?',
        whereArgs: [timeEntry.id],
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _logSuccess('updateLocal',
          "Entry updated in local database with ID: ${timeEntry.id}");
    } catch (e) {
      _logError('updateLocal', e);
      rethrow;
    }
  }

  Future<void> deleteAzure(int? id) async {
    final url = Uri.parse("https://10.0.2.2:7192/api/Items/$id");
    try {
      final response = await http.delete(
        url,
        headers: <String, String>{
          "Content-Type": "application/json; charset=UTF-8",
        },
      );

      if (response.statusCode == 204) {
        _logSuccess('deleteAzure', "Entry deleted from Azure with ID: $id");
      } else {
        throw HttpException(
            "Failed to delete entry from Azure. Status code: ${response.statusCode}");
      }
    } on SocketException catch (e) {
      _logError('deleteAzure', e, 'Network error');
      rethrow;
    } on HttpException catch (e) {
      _logError('deleteAzure', e, 'HTTP error');
      rethrow;
    } catch (e) {
      _logError('deleteAzure', e);
      rethrow;
    }
  }

  Future<void> deleteLocal(int? id) async {
    try {
      final db = await database;
      await db.delete(
        tableName,
        where: 'id = ?',
        whereArgs: [id],
      );
      _logSuccess(
          'deleteLocal', "Entry deleted from local database with ID: $id");
    } catch (e) {
      _logError('deleteLocal', e);
      rethrow;
    }
  }

  void printAzure() async {
    try {
      List<TimeEntry> timeEntries = await retrieveAzure();
      developer.log("Azure entries");
      for (var timeEntry in timeEntries) {
        developer.log(timeEntry.toString());
      }
    } catch (e) {
      _logError('printAzure', e);
    }
  }

  void printLocal() async {
    try {
      List<TimeEntry> timeEntries = await instance.retrieveLocal();
      developer.log("Local entries");
      for (var timeEntry in timeEntries) {
        developer.log(timeEntry.toString());
      }
    } catch (e) {
      _logError('printLocal', e);
    }
  }

  void _logError(String functionName, dynamic error, [String? errorType]) {
    developer.log(
      "${errorType != null ? '$errorType: ' : ''}$error",
      name: functionName,
    );
  }

  void _logSuccess(String functionName, String message) {
    developer.log(
      message,
      name: functionName,
    );
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
