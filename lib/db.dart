import 'dart:convert';
import 'dart:io';
import 'package:mongo_dart/mongo_dart.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  late Db _db;
  
  late DbCollection users;
  late DbCollection groups;
  late DbCollection expenses;
  late DbCollection chatMessages;
  late DbCollection activities;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<void> connect() async {
    String mongoUrl = Platform.environment['MONGO_URL'] ?? "mongodb://localhost:27017/splitwise";
    if (Platform.environment['MONGO_URL'] == null) {
      try {
        final file = File('config.json');
        if (await file.exists()) {
          final content = await file.readAsString();
          final config = jsonDecode(content);
          mongoUrl = config['mongo_url'] ?? mongoUrl;
        }
      } catch (e) {
        print("Could not load config.json, using default database URL: $e");
      }
    }

    print("Connecting to MongoDB at: $mongoUrl");
    _db = await Db.create(mongoUrl);
    await _db.open();
    print("MongoDB Connected successfully!");

    users = _db.collection('users');
    groups = _db.collection('groups');
    expenses = _db.collection('expenses');
    chatMessages = _db.collection('chatMessages');
    activities = _db.collection('activities');
  }

  Db get db => _db;

  Future<void> ensureConnected() async {
    try {
      if (!_db.isConnected) {
        print("Database disconnected. Reconnecting...");
        await _db.open();
        print("Database reconnected successfully!");
      }
    } catch (_) {
      await connect();
    }
  }
}
