import 'dart:convert';
import 'package:mongo_dart/mongo_dart.dart';

void main() {
  final id = ObjectId();
  final map = {'_id': id};
  try {
    print(jsonEncode(map));
  } catch(e) {
    print('Error: $e');
  }
}
