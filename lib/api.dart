import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:crypto/crypto.dart';
import 'db.dart';

// Helper to hash passwords using SHA-256 and a salt
String hashPassword(String password, String salt) {
  final bytes = utf8.encode(password + salt + "splitwise_salt_2026");
  return sha256.convert(bytes).toString();
}

// Middleware to inject CORS headers
Middleware corsHeaders() {
  return (Handler handler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS, PUT, DELETE',
          'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization, X-Requested-With',
        });
      }
      final response = await handler(request);
      return response.change(headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS, PUT, DELETE',
        'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization, X-Requested-With',
      });
    };
  };
}

class ApiService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Map<String, String> _otpCache = {};

  Router get router {
    final router = Router();

    // Config endpoint (to fetch backend variables like Gemini API key securely)
    router.get('/api/config', (Request request) {
      final apiKey = Platform.environment['GEMINI_API_KEY'] ?? Platform.environment['GOOGLE_API_KEY'] ?? '';
      return Response.ok(
        jsonEncode({'geminiApiKey': apiKey}),
        headers: {'content-type': 'application/json'},
      );
    });

    // --- AUTH FLOW ---
    
    // Register
    router.post('/api/auth/register', (Request request) async {
      try {
        final payload = jsonDecode(await request.readAsString());
        final String name = payload['name'] ?? '';
        final String email = payload['email'] ?? '';
        final String phone = payload['phone'] ?? '';
        final String password = payload['password'] ?? '';

        if (name.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty) {
          return Response.badRequest(body: jsonEncode({'error': 'Missing required fields'}));
        }

        // Check if user already exists
        final existingUser = await _dbHelper.users.findOne({'email': email.toLowerCase()});
        if (existingUser != null) {
          return Response.badRequest(body: jsonEncode({'error': 'Email already registered'}));
        }

        final id = ObjectId().toHexString();
        final hashedPassword = hashPassword(password, email.toLowerCase());

        final newUser = {
          '_id': id,
          'id': id,
          'name': name,
          'email': email.toLowerCase(),
          'phone': phone,
          'password': hashedPassword,
          'friendIds': <String>[],
          'sessionToken': null
        };

        await _dbHelper.users.insert(newUser);
        return Response.ok(jsonEncode({'success': true, 'userId': id}));
      } catch (e, stack) {
        print("Registration error: $e\n$stack");
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    // Login
    router.post('/api/auth/login', (Request request) async {
      try {
        final payload = jsonDecode(await request.readAsString());
        final String email = payload['email'] ?? '';
        final String password = payload['password'] ?? '';

        if (email.isEmpty || password.isEmpty) {
          return Response.badRequest(body: jsonEncode({'error': 'Missing email or password'}));
        }

        final user = await _dbHelper.users.findOne({'email': email.toLowerCase()});
        if (user == null) {
          return Response.forbidden(jsonEncode({'error': 'Invalid email or password'}));
        }

        final hashedPassword = hashPassword(password, email.toLowerCase());
        if (user['password'] != hashedPassword) {
          return Response.forbidden(jsonEncode({'error': 'Invalid email or password'}));
        }

        // Generate session token
        final token = ObjectId().toHexString() + Random().nextInt(100000).toString();
        await _dbHelper.users.update(
          {'_id': user['_id']},
          {'\$set': {'sessionToken': token}}
        );

        final cleanUser = {
          'id': user['id'],
          'name': user['name'],
          'email': user['email'],
          'phone': user['phone'],
          'friendIds': List<String>.from(user['friendIds'] ?? []),
          'token': token
        };

        return Response.ok(jsonEncode(cleanUser));
      } catch (e, stack) {
        print("Login error: $e\n$stack");
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    // Send OTP (email / phone)
    router.post('/api/auth/otp/send', (Request request) async {
      try {
        final payload = jsonDecode(await request.readAsString());
        final String type = payload['type'] ?? '';
        final String target = (payload['target'] ?? '').toString().trim().toLowerCase();

        if (type.isEmpty || target.isEmpty) {
          return Response.badRequest(body: jsonEncode({'error': 'Missing type or target'}));
        }

        // Generate 6-digit code
        final code = (100000 + Random().nextInt(900000)).toString();
        _otpCache[target] = code;

        print("==========================================");
        print("[OTP] Generated for $type ($target): $code");
        print("==========================================");

        return Response.ok(jsonEncode({'success': true, 'code': code}));
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    // Verify OTP
    router.post('/api/auth/otp/verify', (Request request) async {
      try {
        final payload = jsonDecode(await request.readAsString());
        final String target = (payload['target'] ?? '').toString().trim().toLowerCase();
        final String code = (payload['code'] ?? '').toString().trim();

        if (target.isEmpty || code.isEmpty) {
          return Response.badRequest(body: jsonEncode({'error': 'Missing target or code'}));
        }

        final cached = _otpCache[target];
        if (cached == code) {
          _otpCache.remove(target);
          return Response.ok(jsonEncode({'success': true}));
        } else {
          return Response.badRequest(body: jsonEncode({'error': 'Invalid OTP verification code'}));
        }
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    // --- PROTECTED SERVICE ROUTES ---

    // Authenticated Middleware Wrapper Helper
    Future<Response> authenticated(Request request, Future<Response> Function(String userId) callback) async {
      final authHeader = request.headers['Authorization'] ?? request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        print("Auth failed: Missing or malformed Authorization header: '$authHeader'");
        return Response.forbidden(jsonEncode({'error': 'Unauthorized: Missing token'}));
      }
      final token = authHeader.replaceFirst('Bearer ', '').trim();
      final user = await _dbHelper.users.findOne({'sessionToken': token});
      if (user == null) {
        print("Auth failed: Session token not found in database: '$token'");
        return Response.forbidden(jsonEncode({'error': 'Unauthorized: Invalid token'}));
      }
      return callback(user['id'] as String);
    }

    // Add Friend
    router.post('/api/friends/add', (Request request) async {
      return authenticated(request, (userId) async {
        try {
          final payload = jsonDecode(await request.readAsString());
          final String query = (payload['query'] ?? '').trim();

          if (query.isEmpty) {
            return Response.badRequest(body: jsonEncode({'error': 'Missing email or phone'}));
          }

          final friend = await _dbHelper.users.findOne({
            '\$or': [
              {'email': query.toLowerCase()},
              {'phone': query}
            ]
          });

          if (friend == null) {
            return Response.badRequest(body: jsonEncode({'error': 'User not found'}));
          }

          if (friend['id'] == userId) {
            return Response.badRequest(body: jsonEncode({'error': 'Cannot add yourself'}));
          }

          final currentUser = await _dbHelper.users.findOne({'id': userId});
          final List<String> friendIds = List<String>.from(currentUser?['friendIds'] ?? []);
          
          if (friendIds.contains(friend['id'])) {
            return Response.badRequest(body: jsonEncode({'error': 'Already friends'}));
          }

          // Add bidirectionally
          await _dbHelper.users.update(
            {'id': userId},
            {'\$push': {'friendIds': friend['id']}}
          );
          await _dbHelper.users.update(
            {'id': friend['id']},
            {'\$push': {'friendIds': userId}}
          );

          // Log Activity
          await _logActivity(userId, "added ${friend['name']} as a friend");

          return Response.ok(jsonEncode({'success': true, 'friend': {
            'id': friend['id'],
            'name': friend['name'],
            'email': friend['email'],
            'phone': friend['phone'],
          }}));
        } catch (e) {
          return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
        }
      });
    });

    // List Friends
    router.get('/api/friends', (Request request) async {
      return authenticated(request, (userId) async {
        try {
          final user = await _dbHelper.users.findOne({'id': userId});
          final List<String> friendIds = List<String>.from(user?['friendIds'] ?? []);
          
          if (friendIds.isEmpty) {
            return Response.ok(jsonEncode([]));
          }

          final cursor = _dbHelper.users.find({
            'id': {'\$in': friendIds}
          });
          final friends = await cursor.toList();
          
          final cleanFriends = friends.map((f) => {
            'id': f['id'],
            'name': f['name'],
            'email': f['email'],
            'phone': f['phone'],
          }).toList();

          return Response.ok(jsonEncode(cleanFriends));
        } catch (e) {
          return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
        }
      });
    });

    // Create Group
    router.post('/api/groups', (Request request) async {
      return authenticated(request, (userId) async {
        try {
          final payload = jsonDecode(await request.readAsString());
          final String name = payload['name'] ?? '';
          final String type = payload['type'] ?? 'Trip'; // Trip, Home, Couple, Others
          final List<String> initialMembers = List<String>.from(payload['members'] ?? []);

          if (name.isEmpty) {
            return Response.badRequest(body: jsonEncode({'error': 'Group name is required'}));
          }

          final inviteCode = '${type.toUpperCase()}-${Random().nextInt(9000) + 1000}';
          final members = [userId, ...initialMembers].toSet().toList(); // Ensure unique IDs
          final groupId = ObjectId().toHexString();

          final newGroup = {
            '_id': groupId,
            'id': groupId,
            'name': name,
            'type': type,
            'memberIds': members,
            'inviteCode': inviteCode,
            'creatorId': userId,
            'itinerary': <Map<String, dynamic>>[],
            'researchItems': <Map<String, dynamic>>[],
            'packingItems': <Map<String, dynamic>>[],
            'chatMessages': <Map<String, dynamic>>[]
          };

          await _dbHelper.groups.insert(newGroup);
          await _logActivity(userId, "created the group '$name'");

          return Response.ok(jsonEncode({'success': true, 'group': newGroup}));
        } catch (e) {
          return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
        }
      });
    });

    // Join Group by Code
    router.post('/api/groups/join', (Request request) async {
      return authenticated(request, (userId) async {
        try {
          final payload = jsonDecode(await request.readAsString());
          final String code = (payload['inviteCode'] ?? '').trim();

          if (code.isEmpty) {
            return Response.badRequest(body: jsonEncode({'error': 'Invite code is required'}));
          }

          final group = await _dbHelper.groups.findOne({
            'inviteCode': {'\$regex': '^${RegExp.escape(code)}\$', '\$options': 'i'}
          });

          if (group == null) {
            return Response.badRequest(body: jsonEncode({'error': 'Group not found with this code'}));
          }

          final List<String> memberIds = List<String>.from(group['memberIds'] ?? []);
          if (memberIds.contains(userId)) {
            return Response.badRequest(body: jsonEncode({'error': 'You are already a member of this group'}));
          }

          await _dbHelper.groups.update(
            {'id': group['id']},
            {'\$push': {'memberIds': userId}}
          );

          await _logActivity(userId, "joined the group '${group['name']}'");

          return Response.ok(jsonEncode({'success': true, 'group': group}));
        } catch (e) {
          return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
        }
      });
    });

    // Add Friend to Group
    router.post('/api/groups/<groupId>/members', (Request request, String groupId) async {
      return authenticated(request, (userId) async {
        try {
          final payload = jsonDecode(await request.readAsString());
          final String friendId = payload['friendId'] ?? '';

          if (friendId.isEmpty) {
            return Response.badRequest(body: jsonEncode({'error': 'Friend ID is required'}));
          }

          final group = await _dbHelper.groups.findOne({'id': groupId});
          if (group == null) {
            return Response.badRequest(body: jsonEncode({'error': 'Group not found'}));
          }

          final List<String> memberIds = List<String>.from(group['memberIds'] ?? []);
          if (memberIds.contains(friendId)) {
            return Response.badRequest(body: jsonEncode({'error': 'User is already a member of this group'}));
          }

          await _dbHelper.groups.update(
            {'id': groupId},
            {'\$push': {'memberIds': friendId}}
          );

          final friend = await _dbHelper.users.findOne({'id': friendId});
          final friendName = friend?['name'] ?? 'Friend';
          await _logActivity(userId, "added $friendName to group '${group['name']}'");

          return Response.ok(jsonEncode({'success': true}));
        } catch (e) {
          return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
        }
      });
    });

    // List Groups
    router.get('/api/groups', (Request request) async {
      return authenticated(request, (userId) async {
        try {
          final cursor = _dbHelper.groups.find({
            'memberIds': userId
          });
          final groups = await cursor.toList();
          return Response.ok(jsonEncode(groups));
        } catch (e) {
          return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
        }
      });
    });

    // Update Group details (for AI Itinerary, Packing checklist, Research boards)
    router.put('/api/groups/<groupId>', (Request request, String groupId) async {
      return authenticated(request, (userId) async {
        try {
          final payload = jsonDecode(await request.readAsString());
          // Remove keys that should not be edited
          payload.remove('id');
          payload.remove('_id');
          payload.remove('creatorId');

          await _dbHelper.groups.update(
            {'id': groupId},
            {'\$set': payload}
          );
          return Response.ok(jsonEncode({'success': true}));
        } catch (e) {
          return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
        }
      });
    });

    // List Expenses for a Group
    router.get('/api/groups/<groupId>/expenses', (Request request, String groupId) async {
      return authenticated(request, (userId) async {
        try {
          final cursor = _dbHelper.expenses.find({'groupId': groupId});
          final expenses = await cursor.toList();
          return Response.ok(jsonEncode(expenses));
        } catch (e) {
          return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
        }
      });
    });

    // Create Expense / Record Settlement
    router.post('/api/expenses', (Request request) async {
      return authenticated(request, (userId) async {
        try {
          final payload = jsonDecode(await request.readAsString());
          final String? groupId = payload['groupId'];
          final String description = payload['description'] ?? '';
          final double amount = (payload['amount'] as num?)?.toDouble() ?? 0.0;
          final Map<String, dynamic> rawPayers = payload['payers'] ?? {};
          final List<String> involvedUserIds = List<String>.from(payload['involvedUserIds'] ?? []);

          if (description.isEmpty || amount <= 0 || rawPayers.isEmpty || involvedUserIds.isEmpty) {
            return Response.badRequest(body: jsonEncode({'error': 'Invalid expense data'}));
          }

          // Clean payers map (convert numeric values to double)
          final Map<String, double> payers = {};
          rawPayers.forEach((k, v) {
            payers[k] = (v as num).toDouble();
          });

          final expenseId = ObjectId().toHexString();
          final expense = {
            '_id': expenseId,
            'id': expenseId,
            'groupId': groupId,
            'description': description,
            'amount': amount,
            'payers': payers,
            'involvedUserIds': involvedUserIds,
            'date': DateTime.now().toIso8601String()
          };

          await _dbHelper.expenses.insert(expense);

          String destinationText = "";
          if (groupId != null) {
            final group = await _dbHelper.groups.findOne({'id': groupId});
            if (group != null) {
              destinationText = "in group '${group['name']}'";
            }
          } else {
            destinationText = "privately";
          }

          final String firstPayerId = payers.keys.first;
          await _logActivity(firstPayerId, "recorded '${description}' of ₹${amount.toStringAsFixed(2)} $destinationText");

          return Response.ok(jsonEncode({'success': true, 'expense': expense}));
        } catch (e) {
          return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
        }
      });
    });

    // List Secure E2EE Chat Messages
    router.get('/api/groups/<groupId>/chat', (Request request, String groupId) async {
      return authenticated(request, (userId) async {
        try {
          final cursor = _dbHelper.chatMessages.find({
            'groupId': groupId,
            'deletedFor': {'\$ne': userId}
          });
          final messages = await cursor.toList();
          return Response.ok(jsonEncode(messages));
        } catch (e) {
          return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
        }
      });
    });

    // Delete E2EE Chat Message
    router.delete('/api/groups/<groupId>/chat/<messageId>', (Request request, String groupId, String messageId) async {
      return authenticated(request, (userId) async {
        try {
          final queryParams = request.url.queryParameters;
          final deleteType = queryParams['type'] ?? 'me'; // 'me' or 'everyone'
          
          final List<Map<String, dynamic>> orConditions = [{'id': messageId}, {'_id': messageId}];
          try {
            orConditions.add({'_id': ObjectId.fromHexString(messageId)});
          } catch (_) {}
          
          Map<String, dynamic> query = {'\$or': orConditions};
          
          final message = await _dbHelper.chatMessages.findOne(query);
          if (message == null) {
            return Response.notFound(jsonEncode({'error': 'Message not found'}));
          }

          if (deleteType == 'everyone') {
            // Check if requester is the sender
            if (message['senderId'] != userId) {
              return Response.forbidden(jsonEncode({'error': 'Only the sender can delete a message for everyone'}));
            }
            // Delete from database completely
            await _dbHelper.chatMessages.deleteOne(query);
            return Response.ok(jsonEncode({'success': true, 'deletedForEveryone': true}));
          } else {
            // Delete for me: add userId to deletedFor array
            await _dbHelper.chatMessages.updateOne(
              query,
              {
                '\$addToSet': {'deletedFor': userId}
              }
            );
            return Response.ok(jsonEncode({'success': true, 'deletedForMe': true}));
          }
        } catch (e) {
          return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
        }
      });
    });

    // Send E2EE Chat Message
    router.post('/api/groups/<groupId>/chat', (Request request, String groupId) async {
      return authenticated(request, (userId) async {
        try {
          final payload = jsonDecode(await request.readAsString());
          final String encryptedContent = payload['encryptedContent'] ?? '';

          if (encryptedContent.isEmpty) {
            return Response.badRequest(body: jsonEncode({'error': 'Message content is required'}));
          }

          final sender = await _dbHelper.users.findOne({'id': userId});
          final senderName = sender?['name'] ?? 'User';

          final messageId = ObjectId().toHexString();
          final newMessage = {
            '_id': messageId,
            'id': messageId,
            'groupId': groupId,
            'senderId': userId,
            'senderName': senderName,
            'encryptedContent': encryptedContent,
            'timestamp': DateTime.now().toIso8601String()
          };

          await _dbHelper.chatMessages.insert(newMessage);

          return Response.ok(jsonEncode({'success': true, 'message': newMessage}));
        } catch (e) {
          return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
        }
      });
    });

    // List Activities (Global to User and Friends)
    router.get('/api/activities', (Request request) async {
      return authenticated(request, (userId) async {
        try {
          final user = await _dbHelper.users.findOne({'id': userId});
          final List<String> friendIds = List<String>.from(user?['friendIds'] ?? []);
          final involvedUsers = [userId, ...friendIds];

          // Fetch activities for user and friends, sorted by date desc
          final cursor = _dbHelper.activities.find({
            'userId': {'\$in': involvedUsers}
          });
          final activitiesList = await cursor.toList();
          
          // Sort descending manually (since mongo_dart query modifiers are easier this way)
          activitiesList.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

          return Response.ok(jsonEncode(activitiesList));
        } catch (e) {
          return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
        }
      });
    });

    // Update User Location & Status
    router.put('/api/users/location', (Request request) async {
      return authenticated(request, (userId) async {
        try {
          final payload = jsonDecode(await request.readAsString());
          final latitude = payload['latitude'] as double?;
          final longitude = payload['longitude'] as double?;
          final isOnline = payload['isOnline'] as bool? ?? false;
          final lastActive = DateTime.now().toIso8601String();

          await _dbHelper.users.updateOne(
            {'id': userId},
            {
              '\$set': {
                'latitude': latitude,
                'longitude': longitude,
                'isOnline': isOnline,
                'lastActive': lastActive
              }
            }
          );

          return Response.ok(jsonEncode({
            'success': true,
            'latitude': latitude,
            'longitude': longitude,
            'isOnline': isOnline,
            'lastActive': lastActive
          }));
        } catch (e) {
          return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
        }
      });
    });

    // Update Password
    router.put('/api/users/password', (Request request) async {
      return authenticated(request, (userId) async {
        try {
          final payload = jsonDecode(await request.readAsString());
          final String password = payload['password'] ?? '';

          if (password.isEmpty) {
            return Response.badRequest(body: jsonEncode({'error': 'Password is required'}));
          }

          final user = await _dbHelper.users.findOne({'id': userId});
          if (user == null) {
            return Response.badRequest(body: jsonEncode({'error': 'User not found'}));
          }

          final hashedPassword = hashPassword(password, user['email']);

          await _dbHelper.users.updateOne(
            {'id': userId},
            {
              '\$set': {'password': hashedPassword}
            }
          );

          return Response.ok(jsonEncode({'success': true}));
        } catch (e) {
          return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
        }
      });
    });

    // Get live locations of group members
    router.get('/api/groups/<groupId>/locations', (Request request, String groupId) async {
      return authenticated(request, (userId) async {
        try {
          final group = await _dbHelper.groups.findOne({'id': groupId});
          if (group == null) {
            return Response.notFound(jsonEncode({'error': 'Group not found'}));
          }
          final List<dynamic> memberIds = group['memberIds'] ?? [];
          final cursor = _dbHelper.users.find({
            'id': {'\$in': memberIds}
          });
          final members = await cursor.toList();

          final locationsList = members.map((m) => {
            'userId': m['id'],
            'name': m['name'],
            'email': m['email'],
            'phone': m['phone'],
            'latitude': m['latitude'],
            'longitude': m['longitude'],
            'isOnline': m['isOnline'] ?? false,
            'lastActive': m['lastActive']
          }).toList();

          return Response.ok(jsonEncode(locationsList));
        } catch (e) {
          return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
        }
      });
    });

    // Fallback global helper to retrieve usernames globally
    router.get('/api/users/names', (Request request) async {
      try {
        final cursor = _dbHelper.users.find();
        final allUsers = await cursor.toList();
        final nameMap = {for (var u in allUsers) u['id'] as String: u['name'] as String};
        return Response.ok(jsonEncode(nameMap));
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    return router;
  }

  // --- DATABASE HELPERS ---
  
  Future<void> _logActivity(String userId, String actionText) async {
    final activity = {
      '_id': ObjectId().toHexString(),
      'userId': userId,
      'actionText': actionText,
      'date': DateTime.now().toIso8601String()
    };
    await _dbHelper.activities.insert(activity);
  }
}
