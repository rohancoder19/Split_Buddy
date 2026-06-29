import 'dart:convert';
import 'package:mongo_dart/mongo_dart.dart';

void main() async {
  final db = Db("mongodb+srv://souvik0254:Souvik2005@cluster0.0dz7l8n.mongodb.net/splitwise?appName=Cluster0");
  await db.open();
  
  final coll = db.collection('test_messages');
  await coll.drop(); // clean up
  
  // Insert a message
  await coll.insert({
    'id': 'msg1',
    'text': 'hello',
  });
  
  // Update to add deletedFor
  await coll.update(
    {'id': 'msg1'},
    {'\$addToSet': {'deletedFor': 'user1'}}
  );
  
  // Query for user1
  final user1Messages = await coll.find({'deletedFor': {'\$ne': 'user1'}}).toList();
  print('User 1 sees: \${user1Messages.length} messages'); // Expect 0
  
  // Query for user2
  final user2Messages = await coll.find({'deletedFor': {'\$ne': 'user2'}}).toList();
  print('User 2 sees: \${user2Messages.length} messages'); // Expect 1
  
  await db.close();
}
