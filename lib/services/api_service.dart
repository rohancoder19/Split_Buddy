import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static final ApiService _instance = ApiService._internal();
  
  // Base URL resolves dynamically on web to support any hosting provider (Render, Cloud Run, etc.)
  String get baseUrl {
    if (kIsWeb) {
      return Uri.base.origin;
    }
    // Fallback for mobile platforms (update this to your Render URL for mobile testing)
    return 'https://splitwise-backend-bpsrtue25q-uc.a.run.app';
  }
  
  String? _token;

  factory ApiService() => _instance;

  ApiService._internal();

  void setToken(String? token) {
    _token = token;
  }

  bool get hasToken => _token != null;

  Map<String, String> _headers() {
    final headers = {
      'Content-Type': 'application/json; charset=UTF-8',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // --- HTTP HELPERS ---

  Future<http.Response> get(String path) async {
    final url = Uri.parse('$baseUrl$path');
    return await http.get(url, headers: _headers());
  }

  Future<http.Response> post(String path, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseUrl$path');
    return await http.post(
      url,
      headers: _headers(),
      body: jsonEncode(body),
    );
  }

  Future<http.Response> put(String path, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseUrl$path');
    return await http.put(
      url,
      headers: _headers(),
      body: jsonEncode(body),
    );
  }

  Future<http.Response> delete(String path) async {
    final url = Uri.parse('$baseUrl$path');
    return await http.delete(url, headers: _headers());
  }

  // --- OTP ENDPOINTS ---

  Future<String?> sendOtp(String type, String target) async {
    print('[OTP] Sending OTP for $type: $target');
    final response = await post('/api/auth/otp/send', {
      'type': type,
      'target': target,
    });
    print('[OTP] sendOtp response: ${response.statusCode} ${response.body}');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['code']?.toString();
    }
    throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to send OTP');
  }

  Future<bool> verifyOtp(String target, String code) async {
    print('[OTP] Verifying OTP for target: $target, code: $code');
    final response = await post('/api/auth/otp/verify', {
      'target': target,
      'code': code,
    });
    print('[OTP] verifyOtp response: ${response.statusCode} ${response.body}');
    return response.statusCode == 200;
  }

  // --- AUTH ENDPOINTS ---

  Future<Map<String, dynamic>?> register(String name, String email, String phone, String password) async {
    final response = await post('/api/auth/register', {
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
    });
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(jsonDecode(response.body)['error'] ?? 'Registration failed');
  }

  Future<Map<String, dynamic>?> login(String email, String password) async {
    final response = await post('/api/auth/login', {
      'email': email,
      'password': password,
    });
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _token = data['token'];
      return data;
    }
    throw Exception(jsonDecode(response.body)['error'] ?? 'Login failed');
  }

  void logout() {
    _token = null;
  }

  // --- FRIENDS ENDPOINTS ---

  Future<List<dynamic>> getFriends() async {
    final response = await get('/api/friends');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load friends');
  }

  Future<Map<String, dynamic>> addFriend(String query) async {
    final response = await post('/api/friends/add', {'query': query});
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to add friend');
  }

  // --- GROUPS ENDPOINTS ---

  Future<List<dynamic>> getGroups() async {
    final response = await get('/api/groups');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load groups');
  }

  Future<Map<String, dynamic>> createGroup(String name, String type, List<String> memberIds) async {
    final response = await post('/api/groups', {
      'name': name,
      'type': type,
      'members': memberIds,
    });
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to create group');
  }

  Future<Map<String, dynamic>> joinGroup(String inviteCode) async {
    final response = await post('/api/groups/join', {'inviteCode': inviteCode});
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to join group');
  }

  Future<void> addFriendToGroup(String groupId, String friendId) async {
    final response = await post('/api/groups/$groupId/members', {'friendId': friendId});
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to add member to group');
    }
  }

  // --- EXPENSES ENDPOINTS ---

  Future<List<dynamic>> getExpenses(String groupId) async {
    final response = await get('/api/groups/$groupId/expenses');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load expenses');
  }

  Future<Map<String, dynamic>> createExpense({
    String? groupId,
    required String description,
    required double amount,
    required Map<String, double> payers,
    required List<String> involvedUserIds,
  }) async {
    final response = await post('/api/expenses', {
      if (groupId != null) 'groupId': groupId,
      'description': description,
      'amount': amount,
      'payers': payers,
      'involvedUserIds': involvedUserIds,
    });
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to create expense');
  }

  // --- CHAT ENDPOINTS ---

  Future<List<dynamic>> getChatMessages(String groupId) async {
    final response = await get('/api/groups/$groupId/chat');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load chat messages');
  }

  Future<Map<String, dynamic>> sendChatMessage(String groupId, String encryptedContent) async {
    final response = await post('/api/groups/$groupId/chat', {
      'encryptedContent': encryptedContent,
    });
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to send message');
  }

  Future<void> deleteChatMessage(String groupId, String messageId, String type) async {
    final response = await delete('/api/groups/$groupId/chat/$messageId?type=$type');
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to delete message');
    }
  }

  // --- ACTIVITIES ENDPOINTS ---

  Future<List<dynamic>> getActivities() async {
    final response = await get('/api/activities');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load activities');
  }

  // --- GLOBAL USERNAMES MAP ---

  Future<Map<String, String>> getUserNames() async {
    final response = await get('/api/users/names');
    if (response.statusCode == 200) {
      final Map<String, dynamic> raw = jsonDecode(response.body);
      return raw.map((k, v) => MapEntry(k, v.toString()));
    }
    return {};
  }

  Future<Map<String, dynamic>> updateMyLocation(double? lat, double? lng, bool isOnline) async {
    final response = await put('/api/users/location', {
      'latitude': lat,
      'longitude': lng,
      'isOnline': isOnline,
    });
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to update location');
  }

  Future<void> updatePassword(String newPassword) async {
    final response = await put('/api/users/password', {
      'password': newPassword,
    });
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to update password');
    }
  }

  Future<List<dynamic>> getGroupLocations(String groupId) async {
    final response = await get('/api/groups/$groupId/locations');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load group locations');
  }

  Future<void> updateGroup(String groupId, Map<String, dynamic> updates) async {
    final response = await put('/api/groups/$groupId', updates);
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to update group details');
    }
  }
}
