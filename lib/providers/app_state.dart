import 'dart:math';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/user.dart';
import '../models/group.dart';
import '../models/activity.dart';
import '../models/expense.dart';
import '../services/e2ee_helper.dart';
import '../services/api_service.dart';

class AppState extends ChangeNotifier {
  final ApiService _api = ApiService();

  // Cached data lists synced from database
  List<User> _allUsers = [];
  List<Group> _allGroups = [];
  List<Expense> _allExpenses = [];
  List<Activity> _allActivities = [];
  Map<String, String> _usernames = {}; // Map of userId -> userName

  final Map<String, Timer> _groupTimers = {};
  String? activeNotification;

  List<Map<String, dynamic>> _currentGroupLocations = [];
  List<Map<String, dynamic>> get currentGroupLocations => _currentGroupLocations;
  Timer? _locationPollingTimer;
  Timer? _chatPollingTimer;

  User? currentUser;
  String? _serverGeminiApiKey;

  bool get isAuthenticated => currentUser != null;

  AppState() {
    // We fetch data dynamically after authentication
    loadConfig();
  }

  Future<void> loadConfig() async {
    try {
      final config = await _api.getConfig();
      if (config.containsKey('geminiApiKey')) {
        _serverGeminiApiKey = config['geminiApiKey'];
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loading config: $e");
    }
  }

  // Public getter to safely get Gemini/Google API key
  String? get geminiApiKey => _getGeminiApiKey();

  // Helper to safely get Gemini API key
  String? _getGeminiApiKey() {
    if (_serverGeminiApiKey != null && _serverGeminiApiKey!.isNotEmpty) {
      return _serverGeminiApiKey;
    }
    const String userFallbackKey = 'YOUR_API_KEY_HERE';
    if (kIsWeb) {
      const key = String.fromEnvironment('GEMINI_API_KEY');
      if (key.isNotEmpty) return key;
      const googleKey = String.fromEnvironment('GOOGLE_API_KEY');
      if (googleKey.isNotEmpty) return googleKey;
      return userFallbackKey;
    } else {
      try {
        final envKey = Platform.environment['GEMINI_API_KEY'] ?? Platform.environment['GOOGLE_API_KEY'];
        if (envKey != null && envKey.isNotEmpty) return envKey;
      } catch (_) {}
      return userFallbackKey;
    }
  }

  // --- Remote Sync Flow ---
  
  Future<void> loadInitialData() async {
    if (!_api.hasToken) return;
    try {
      // 1. Fetch all user names
      _usernames = await _api.getUserNames();

      // 2. Fetch groups
      final groupsData = await _api.getGroups();
      _allGroups = groupsData.map((g) {
        return Group(
          id: g['id'] ?? '',
          name: g['name'] ?? '',
          type: _parseGroupType(g['type']),
          memberIds: List<String>.from(g['memberIds'] ?? []),
          inviteCode: g['inviteCode'] ?? '',
          creatorId: g['creatorId'] ?? '',
          itinerary: List<Map<String, dynamic>>.from(g['itinerary'] ?? []),
          researchItems: List<Map<String, dynamic>>.from(g['researchItems'] ?? []),
          packingItems: List<Map<String, dynamic>>.from(g['packingItems'] ?? []),
        );
      }).toList();

      for (var group in _allGroups) {
        await fetchGroupExpenses(group.id);
      }

      // 3. Fetch friends list
      final friendsData = await _api.getFriends();
      _allUsers.clear();
      final List<String> friendIds = [];
      for (var f in friendsData) {
        final fid = f['id'] as String;
        friendIds.add(fid);
        _allUsers.add(User(
          id: fid,
          name: f['name'] ?? '',
          email: f['email'] ?? '',
          phone: f['phone'] ?? '',
          password: '',
          friendIds: [],
          latitude: (f['latitude'] as num?)?.toDouble(),
          longitude: (f['longitude'] as num?)?.toDouble(),
          isOnline: f['isOnline'] as bool? ?? false,
          lastActive: f['lastActive'] as String?,
        ));
      }

      if (currentUser != null) {
        currentUser = User(
          id: currentUser!.id,
          name: currentUser!.name,
          email: currentUser!.email,
          phone: currentUser!.phone,
          password: currentUser!.password,
          friendIds: friendIds,
          latitude: currentUser!.latitude,
          longitude: currentUser!.longitude,
          isOnline: currentUser!.isOnline,
          lastActive: currentUser!.lastActive,
        );
        // Ensure current user is in _allUsers cache
        if (!_allUsers.any((u) => u.id == currentUser!.id)) {
          _allUsers.add(currentUser!);
        }
      }

      // 4. Fetch activities
      final activitiesData = await _api.getActivities();
      _allActivities = activitiesData.map((act) => Activity(
        id: act['id'] ?? '',
        userId: act['userId'] ?? '',
        actionText: act['actionText'] ?? '',
        date: DateTime.parse(act['date']),
      )).toList();

      notifyListeners();
    } catch (e) {
      debugPrint("Error loading data from database: $e");
    }
  }

  GroupType _parseGroupType(String? typeStr) {
    if (typeStr == null) return GroupType.Others;
    return GroupType.values.firstWhere(
      (e) => e.name.toLowerCase() == typeStr.toLowerCase(),
      orElse: () => GroupType.Others
    );
  }

  // --- Auth Flow ---
  
  Future<String?> sendOtp(String type, String target) async {
    try {
      return await _api.sendOtp(type, target);
    } catch (e) {
      debugPrint("Send OTP error: $e");
      return null;
    }
  }

  Future<bool> verifyOtp(String target, String code) async {
    try {
      return await _api.verifyOtp(target, code);
    } catch (e) {
      debugPrint("Verify OTP error: $e");
      return false;
    }
  }

  Future<bool> registerUser(String name, String email, String phone, String password) async {
    try {
      await _api.register(name, email, phone, password);
      return true;
    } catch (e) {
      debugPrint("Registration error: $e");
      return false;
    }
  }

  Future<bool> loginUser(String email, String password) async {
    try {
      final user = await _api.login(email, password);
      if (user != null) {
        currentUser = User(
          id: user['id'],
          name: user['name'],
          email: user['email'],
          phone: user['phone'],
          password: password,
          friendIds: List<String>.from(user['friendIds'] ?? []),
          latitude: (user['latitude'] as num?)?.toDouble(),
          longitude: (user['longitude'] as num?)?.toDouble(),
          isOnline: user['isOnline'] as bool? ?? false,
          lastActive: user['lastActive'] as String?,
        );
        await loadInitialData();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Login error: $e");
      return false;
    }
  }

  void logout() {
    _api.logout();
    _groupTimers.forEach((_, timer) => timer.cancel());
    _groupTimers.clear();
    activeNotification = null;
    currentUser = null;
    _allUsers.clear();
    _allGroups.clear();
    _allExpenses.clear();
    _allActivities.clear();
    _usernames.clear();
    notifyListeners();
  }

  void dismissNotification() {
    activeNotification = null;
    notifyListeners();
  }

  List<User> get users => _allUsers;
  List<Expense> get expenses => _allExpenses;

  // --- Friends Flow ---
  
  List<User> get myFriends {
    if (currentUser == null) return [];
    return _allUsers.where((u) => currentUser!.friendIds.contains(u.id)).toList();
  }

  Future<bool> addFriendByEmailOrPhone(String input) async {
    if (currentUser == null) return false;
    try {
      await _api.addFriend(input);
      await loadInitialData();
      return true;
    } catch (e) {
      debugPrint("Add friend error: $e");
      return false;
    }
  }

  // --- Groups Flow ---
  
  List<Group> get myGroups => _allGroups;

  List<User> getGroupMembers(String groupId) {
    try {
      final group = _allGroups.firstWhere((g) => g.id == groupId);
      return group.memberIds.map((mid) {
        return _allUsers.firstWhere(
          (u) => u.id == mid,
          orElse: () => User(
            id: mid,
            name: getUserName(mid),
            email: '',
            phone: '',
            password: '',
            friendIds: [],
          ),
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Group?> createGroup(String name, GroupType type, List<String> initialMemberIds) async {
    if (currentUser == null) return null;
    try {
      final res = await _api.createGroup(name, type.name, initialMemberIds);
      final newGroupId = res['group']['id'];
      final inviteCode = res['group']['inviteCode'];

      await loadInitialData();
      final g = _allGroups.firstWhere((group) => group.id == newGroupId);
      
      // Inject E2EE welcome messages for demonstration
      final msg1 = E2eeHelper.encrypt("Hey! Glad to join the group '$name'. This E2EE chat is perfect for planning our expenses privately.", inviteCode);
      final msg2 = E2eeHelper.encrypt("Awesome, let's keep all our receipts and expense splits tracked here!", inviteCode);
      
      await _api.sendChatMessage(newGroupId, msg1);
      await _api.sendChatMessage(newGroupId, msg2);

      await loadInitialData();
      return g;
    } catch (e) {
      debugPrint("Create group error: $e");
      return null;
    }
  }

  Future<bool> joinGroupWithCode(String code) async {
    if (currentUser == null) return false;
    try {
      await _api.joinGroup(code);
      await loadInitialData();
      return true;
    } catch (e) {
      debugPrint("Join group error: $e");
      return false;
    }
  }

  Future<void> addFriendToGroup(String groupId, String friendId) async {
    try {
      await _api.addFriendToGroup(groupId, friendId);
      await loadInitialData();
    } catch (e) {
      debugPrint("Add friend to group error: $e");
    }
  }

  // --- Expenses Flow ---
  
  List<Expense> get myExpenses => _allExpenses;

  List<Expense> getGroupExpenses(String groupId) {
    return _allExpenses.where((exp) => exp.groupId == groupId).toList();
  }

  Future<void> fetchGroupExpenses(String groupId) async {
    try {
      final expensesData = await _api.getExpenses(groupId);
      final mappedExpenses = expensesData.map((e) {
        final rawPayers = e['payers'] as Map<String, dynamic>;
        final Map<String, double> payers = {};
        rawPayers.forEach((k, v) {
          payers[k] = (v as num).toDouble();
        });
        return Expense(
          id: e['id'] ?? '',
          groupId: e['groupId'],
          description: e['description'] ?? '',
          amount: (e['amount'] as num).toDouble(),
          payers: payers,
          involvedUserIds: List<String>.from(e['involvedUserIds'] ?? []),
          date: DateTime.parse(e['date']),
        );
      }).toList();
      
      _allExpenses.removeWhere((exp) => exp.groupId == groupId);
      _allExpenses.addAll(mappedExpenses);
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching expenses: $e");
    }
  }

  Future<void> addExpense(Expense expense) async {
    try {
      await _api.createExpense(
        groupId: expense.groupId,
        description: expense.description,
        amount: expense.amount,
        payers: expense.payers,
        involvedUserIds: expense.involvedUserIds,
      );
      if (expense.groupId != null) {
        await fetchGroupExpenses(expense.groupId!);
      }
      await loadInitialData();
    } catch (e) {
      debugPrint("Add expense error: $e");
    }
  }

  Future<void> settleDebt({
    required String debtorId,
    required String creditorId,
    required double amount,
    String? groupId,
  }) async {
    try {
      await _api.createExpense(
        groupId: groupId,
        description: 'Settlement: ${getUserName(debtorId)} paid ${getUserName(creditorId)}',
        amount: amount,
        payers: {debtorId: amount},
        involvedUserIds: [creditorId],
      );
      if (groupId != null) {
        await fetchGroupExpenses(groupId);
      }
      await loadInitialData();
    } catch (e) {
      debugPrint("Settle debt error: $e");
    }
  }

  // --- Activities Flow ---
  
  List<Activity> get myActivities => _allActivities;

  Future<void> _logActivity(String userId, String actionText) async {
    // Handled database-side by the REST API logs, but we can call loadInitialData to sync
    await loadInitialData();
  }

  String getUserName(String userId) {
    return _usernames[userId] ?? 'Unknown';
  }

  // --- Balance Calculations ---
  
  Map<String, double> getGroupBalances(String groupId) {
    final groupMembers = getGroupMembers(groupId);
    final groupExpenses = getGroupExpenses(groupId);
    
    Map<String, double> balances = {for (var m in groupMembers) m.id: 0.0};

    for (var exp in groupExpenses) {
      if (exp.involvedUserIds.isEmpty) continue;
      double splitAmount = exp.amount / exp.involvedUserIds.length;

      // Credit payers
      exp.payers.forEach((payerId, amountPaid) {
        if (balances.containsKey(payerId)) {
          balances[payerId] = (balances[payerId] ?? 0.0) + amountPaid;
        }
      });

      // Debit involved members
      for (var userId in exp.involvedUserIds) {
        if (balances.containsKey(userId)) {
          balances[userId] = (balances[userId] ?? 0.0) - splitAmount;
        }
      }
    }
    return balances;
  }

  double getMyNetBalance() {
    if (currentUser == null) return 0.0;
    double net = 0.0;

    for (var exp in _allExpenses) {
      if (exp.involvedUserIds.contains(currentUser!.id)) {
        double splitAmount = exp.amount / exp.involvedUserIds.length;
        net -= splitAmount;
      }
      if (exp.payers.containsKey(currentUser!.id)) {
        net += exp.payers[currentUser!.id] ?? 0.0;
      }
    }
    return net;
  }

  double getMyTotalSpent() {
    if (currentUser == null) return 0.0;
    double total = 0.0;

    for (var exp in _allExpenses) {
      if (exp.involvedUserIds.contains(currentUser!.id)) {
        double splitAmount = exp.amount / exp.involvedUserIds.length;
        total += splitAmount;
      }
    }
    return total;
  }

  Map<String, double> get balances {
    Map<String, double> result = {for (var u in _allUsers) u.id: 0.0};
    for (var exp in _allExpenses) {
      if (exp.involvedUserIds.isEmpty) continue;
      double splitAmount = exp.amount / exp.involvedUserIds.length;
      exp.payers.forEach((payerId, amountPaid) {
        if (result.containsKey(payerId)) {
          result[payerId] = (result[payerId] ?? 0.0) + amountPaid;
        }
      });
      for (var userId in exp.involvedUserIds) {
        if (result.containsKey(userId)) {
          result[userId] = (result[userId] ?? 0.0) - splitAmount;
        }
      }
    }
    return result;
  }

  void addMember(String name) async {
    final email = '${name.toLowerCase().replaceAll(' ', '')}@gmail.com';
    final phone = '987654${Random().nextInt(9000) + 1000}';
    await registerUser(name, email, phone, 'password');
    await loadInitialData();
  }

  // --- Trip Planning & Research Dashboard Logic (Synced to MongoDB) ---
  
  void addTripActivity(String groupId, Map<String, dynamic> activity) async {
    try {
      final group = _allGroups.firstWhere((g) => g.id == groupId);
      group.itinerary.add(activity);
      group.itinerary.sort((a, b) => (a['day'] as int).compareTo(b['day'] as int));
      notifyListeners();

      // Sync to database
      await _api.updateGroup(groupId, {'itinerary': group.itinerary});
    } catch (e) {
      debugPrint("Error in addTripActivity: $e");
    }
  }

  void clearTripItinerary(String groupId) async {
    try {
      final group = _allGroups.firstWhere((g) => g.id == groupId);
      group.itinerary.clear();
      notifyListeners();

      await _api.updateGroup(groupId, {'itinerary': []});
    } catch (e) {
      debugPrint("Error in clearTripItinerary: $e");
    }
  }

  void addResearchItem(String groupId, String title, String link) async {
    try {
      final group = _allGroups.firstWhere((g) => g.id == groupId);
      group.researchItems.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': title,
        'link': link,
        'votes': <String>[],
      });
      notifyListeners();

      await _api.updateGroup(groupId, {'researchItems': group.researchItems});
    } catch (e) {
      debugPrint("Error in addResearchItem: $e");
    }
  }

  void voteResearchItem(String groupId, String itemId) async {
    try {
      if (currentUser == null) return;
      final group = _allGroups.firstWhere((g) => g.id == groupId);
      final item = group.researchItems.firstWhere((item) => item['id'] == itemId);
      final List<String> votes = List<String>.from(item['votes'] ?? []);
      
      if (votes.contains(currentUser!.id)) {
        votes.remove(currentUser!.id);
      } else {
        votes.add(currentUser!.id);
      }
      
      item['votes'] = votes;
      notifyListeners();

      await _api.updateGroup(groupId, {'researchItems': group.researchItems});
    } catch (e) {
      debugPrint("Error in voteResearchItem: $e");
    }
  }

  void addPackingItem(String groupId, String name, String? assignedUserId) async {
    try {
      final group = _allGroups.firstWhere((g) => g.id == groupId);
      group.packingItems.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': name,
        'assignedUserId': assignedUserId,
        'isDone': false,
      });
      notifyListeners();

      await _api.updateGroup(groupId, {'packingItems': group.packingItems});
    } catch (e) {
      debugPrint("Error in addPackingItem: $e");
    }
  }

  void togglePackingItem(String groupId, String itemId) async {
    try {
      final group = _allGroups.firstWhere((g) => g.id == groupId);
      final item = group.packingItems.firstWhere((item) => item['id'] == itemId);
      item['isDone'] = !(item['isDone'] as bool);
      notifyListeners();

      await _api.updateGroup(groupId, {'packingItems': group.packingItems});
    } catch (e) {
      debugPrint("Error in togglePackingItem: $e");
    }
  }

  Future<bool> generateAIItinerary(String groupId, String destination, String style, int days) async {
    try {
      final group = _allGroups.firstWhere((g) => g.id == groupId);
      final apiKey = _getGeminiApiKey();
      
      List<Map<String, dynamic>> generatedActivities = [];
      
      if (apiKey != null && apiKey.isNotEmpty) {
        try {
          final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
          final prompt = "Generate a travel itinerary for a $days-day trip to $destination in a $style style. "
              "Return ONLY a valid JSON list of activities (no markdown formatting, no backticks, no code block wrappers) in this exact format: "
              "[{\"day\": 1, \"time\": \"10:00 AM\", \"title\": \"Activity Title\", \"cost\": 150.0}]. "
              "Make sure day values are integers between 1 and $days. Cost should be a double.";
              
          final response = await model.generateContent([Content.text(prompt)]);
          final text = response.text;
          
          if (text != null && text.trim().isNotEmpty) {
            var cleanJson = text.trim();
            if (cleanJson.startsWith('```')) {
              cleanJson = cleanJson.replaceAll(RegExp(r'^```(json)?|```$'), '').trim();
            }
            
            final List<dynamic> parsed = jsonDecode(cleanJson);
            generatedActivities = parsed.map<Map<String, dynamic>>((act) => {
              'day': act['day'] as int? ?? 1,
              'time': act['time'] as String? ?? '10:00 AM',
              'title': act['title'] as String? ?? 'Sightseeing',
              'cost': (act['cost'] as num?)?.toDouble() ?? 0.0,
            }).toList();
          }
        } catch (e) {
          debugPrint('Gemini live call failed, falling back to presets: $e');
        }
      }
      
      if (generatedActivities.isEmpty) {
        final destLower = destination.toLowerCase();
        if (destLower.contains('goa')) {
          generatedActivities = _getGoaPreset(days);
        } else if (destLower.contains('paris')) {
          generatedActivities = _getParisPreset(days);
        } else if (destLower.contains('tokyo')) {
          generatedActivities = _getTokyoPreset(days);
        } else {
          generatedActivities = _getGenericPreset(destination, style, days);
        }
      }
      
      group.itinerary.clear();
      group.itinerary.addAll(generatedActivities);
      group.itinerary.sort((a, b) => (a['day'] as int).compareTo(b['day'] as int));
      notifyListeners();

      // Sync updated itinerary to DB
      await _api.updateGroup(groupId, {'itinerary': group.itinerary});
      return true;
    } catch (_) {
      return false;
    }
  }

  // --- Curated Preset Generators ---
  List<Map<String, dynamic>> _getGoaPreset(int days) {
    final List<Map<String, dynamic>> all = [
      {'day': 1, 'time': '09:00 AM', 'title': 'Breakfast at beach shack', 'cost': 250.0},
      {'day': 1, 'time': '11:00 AM', 'title': 'Sunbathing at Calangute Beach', 'cost': 0.0},
      {'day': 1, 'time': '03:00 PM', 'title': 'Parasailing & Jet Ski at Baga', 'cost': 1500.0},
      {'day': 1, 'time': '08:00 PM', 'title': 'Dinner at Britto\'s', 'cost': 900.0},
      
      {'day': 2, 'time': '10:00 AM', 'title': 'Visit historic Aguada Fort', 'cost': 50.0},
      {'day': 2, 'time': '01:00 PM', 'title': 'Traditional Goan fish thali lunch', 'cost': 350.0},
      {'day': 2, 'time': '04:00 PM', 'title': 'Mandovi River sunset cruise', 'cost': 600.0},
      {'day': 2, 'time': '09:00 PM', 'title': 'Night out at Club Cabana', 'cost': 2000.0},
      
      {'day': 3, 'time': '08:00 AM', 'title': 'Dudhsagar Waterfalls jeep safari', 'cost': 1200.0},
      {'day': 3, 'time': '02:00 PM', 'title': 'Spice plantation tour with lunch', 'cost': 700.0},
      {'day': 3, 'time': '06:00 PM', 'title': 'Relax at Anjuna Sunset Point', 'cost': 0.0},
    ];
    return all.where((act) => act['day'] <= days).toList();
  }

  List<Map<String, dynamic>> _getParisPreset(int days) {
    final List<Map<String, dynamic>> all = [
      {'day': 1, 'time': '09:00 AM', 'title': 'Climb Eiffel Tower', 'cost': 2800.0},
      {'day': 1, 'time': '01:00 PM', 'title': 'Lunch at a French bistro', 'cost': 1600.0},
      {'day': 1, 'time': '03:00 PM', 'title': 'Seine River cruise', 'cost': 1400.0},
      {'day': 1, 'time': '07:00 PM', 'title': 'Walk along Champs-Élysées', 'cost': 0.0},
      
      {'day': 2, 'time': '10:00 AM', 'title': 'Louvre Museum tour', 'cost': 2200.0},
      {'day': 2, 'time': '02:00 PM', 'title': 'Explore Notre-Dame Cathedral area', 'cost': 0.0},
      {'day': 2, 'time': '04:00 PM', 'title': 'Wander around Montmartre & Sacré-Cœur', 'cost': 400.0},
      {'day': 2, 'time': '08:00 PM', 'title': 'Dinner in the Latin Quarter', 'cost': 2000.0},
      
      {'day': 3, 'time': '09:00 AM', 'title': 'Palace of Versailles day trip', 'cost': 3200.0},
      {'day': 3, 'time': '04:00 PM', 'title': 'Relax in Luxembourg Gardens', 'cost': 0.0},
      {'day': 3, 'time': '07:00 PM', 'title': 'Macaron tasting at Ladurée', 'cost': 900.0},
    ];
    return all.where((act) => act['day'] <= days).toList();
  }

  List<Map<String, dynamic>> _getTokyoPreset(int days) {
    final List<Map<String, dynamic>> all = [
      {'day': 1, 'time': '09:00 AM', 'title': 'Asakusa Senso-ji Temple visit', 'cost': 0.0},
      {'day': 1, 'time': '12:00 PM', 'title': 'Tonkatsu lunch in Akihabara', 'cost': 1000.0},
      {'day': 1, 'time': '02:00 PM', 'title': 'Akihabara Electric Town shopping', 'cost': 2500.0},
      {'day': 1, 'time': '07:00 PM', 'title': 'Traditional Izakaya dinner', 'cost': 3000.0},
      
      {'day': 2, 'time': '10:00 AM', 'title': 'Meiji Shrine forest walk', 'cost': 0.0},
      {'day': 2, 'time': '01:00 PM', 'title': 'Crepe lunch & shopping in Harajuku', 'cost': 1200.0},
      {'day': 2, 'time': '03:00 PM', 'title': 'Cross Shibuya Crossing & see Hachiko', 'cost': 0.0},
      {'day': 2, 'time': '06:00 PM', 'title': 'Shibuya Sky observatory sunset', 'cost': 2000.0},
      
      {'day': 3, 'time': '09:00 AM', 'title': 'teamLab Planets Digital Art Museum', 'cost': 3800.0},
      {'day': 3, 'time': '01:00 PM', 'title': 'Fresh sushi lunch at Toyosu Market', 'cost': 3500.0},
      {'day': 3, 'time': '04:00 PM', 'title': 'Odaiba Seaside Park & giant Gundam', 'cost': 0.0},
    ];
    return all.where((act) => act['day'] <= days).toList();
  }

  List<Map<String, dynamic>> _getGenericPreset(String destination, String style, int days) {
    final List<Map<String, dynamic>> activities = [];
    for (int day = 1; day <= days; day++) {
      if (day == 1) {
        activities.add({'day': 1, 'time': '09:00 AM', 'title': 'Arrive in $destination & Check-in', 'cost': 0.0});
        activities.add({'day': 1, 'time': '01:00 PM', 'title': 'Lunch at highly rated local cafe', 'cost': 600.0});
        activities.add({'day': 1, 'time': '03:00 PM', 'title': 'City orientation & walking tour ($style style)', 'cost': 800.0});
        activities.add({'day': 1, 'time': '08:00 PM', 'title': 'Welcome dinner at regional restaurant', 'cost': 1200.0});
      } else if (day == days) {
        activities.add({'day': day, 'time': '09:00 AM', 'title': 'Visit local cultural market', 'cost': 0.0});
        activities.add({'day': day, 'time': '12:00 PM', 'title': 'Quick lunch & snack tasting', 'cost': 450.0});
        activities.add({'day': day, 'time': '03:00 PM', 'title': 'Souvenir shopping and sightseeing', 'cost': 1500.0});
        activities.add({'day': day, 'time': '07:00 PM', 'title': 'Farewell dinner & drinks', 'cost': 1800.0});
      } else {
        activities.add({'day': day, 'time': '10:00 AM', 'title': 'Major sightseeing excursion ($style style)', 'cost': 1500.0});
        activities.add({'day': day, 'time': '01:30 PM', 'title': 'Lunch with scenic views', 'cost': 800.0});
        activities.add({'day': day, 'time': '04:00 PM', 'title': 'Museum or natural park exploration', 'cost': 500.0});
        activities.add({'day': day, 'time': '08:00 PM', 'title': 'Relaxed evening activity and dinner', 'cost': 1000.0});
      }
    }
    return activities;
  }

  void clearTripChatHistory(String groupId) {
    try {
      final group = _allGroups.firstWhere((g) => g.id == groupId);
      group.chatMessages.clear();
      group.chatMessages.add({
        'sender': 'assistant',
        'text': "Hi! I am your AI Travel Assistant. ✈️\n\nAsk me anything about your trip to help you plan! I can recommend itineraries, suggest spots to research, or help coordinate packing lists.",
        'timestamp': DateTime.now(),
        'suggestions': ['✈️ Suggest Itinerary', '🏨 Recommend Hotels', '🎒 Packing Checklist'],
      });
      notifyListeners();
    } catch (_) {}
  }

  Future<void> sendTripChatMessage(String groupId, String messageText) async {
    try {
      final group = _allGroups.firstWhere((g) => g.id == groupId);
      
      if (group.chatMessages.isEmpty) {
        group.chatMessages.add({
          'sender': 'assistant',
          'text': "Hi! I am your AI Travel Assistant. ✈️\n\nAsk me anything about your trip to help you plan! I can recommend itineraries, suggest spots to research, or help coordinate packing lists.",
          'timestamp': DateTime.now(),
          'suggestions': ['✈️ Suggest Itinerary', '🏨 Recommend Hotels', '🎒 Packing Checklist'],
        });
      }

      // Add user message
      group.chatMessages.add({
        'sender': 'user',
        'text': messageText,
        'timestamp': DateTime.now(),
      });
      notifyListeners();

      // Dummy typing indicator
      final typingId = DateTime.now().millisecondsSinceEpoch.toString();
      group.chatMessages.add({
        'sender': 'assistant',
        'text': '...',
        'isTyping': true,
        'id': typingId,
        'timestamp': DateTime.now(),
      });
      notifyListeners();

      // Context
      String historyText = "";
      for (var msg in group.chatMessages) {
        if (msg['isTyping'] == true) continue;
        final senderName = msg['sender'] == 'user' ? 'User' : 'Assistant';
        historyText += "$senderName: ${msg['text']}\n";
      }

      String contextText = "You are an expert AI Travel Assistant embedded inside a Split-Buddy mobile application.\n"
          "The user is currently planning a trip to '${group.name}' with ${group.memberIds.length} members.\n\n"
          "Your interface has three main tabs:\n"
          "1. Itinerary (For trip planning and daily schedules)\n"
          "2. Research (For exploring sightseeing spots, hotels, and local food)\n"
          "3. Packing (For checklist management)\n\n"
          "Current Trip Context:\n";
          
      if (group.itinerary.isNotEmpty) {
        contextText += "- Itinerary: ${group.itinerary.map((act) => 'Day ${act['day']} at ${act['time']}: ${act['title']} (Est. Cost: ₹${act['cost']})').join(', ')}\n";
      }
      if (group.researchItems.isNotEmpty) {
        contextText += "- Pinned Research: ${group.researchItems.map((item) => item['title']).join(', ')}\n";
      }
      if (group.packingItems.isNotEmpty) {
        contextText += "- Packing List: ${group.packingItems.map((item) => '${item['name']} (assigned to ${item['assignedUserId'] ?? 'anyone'})').join(', ')}\n";
      }

      final prompt = "$contextText\n\n"
          "CRITICAL FORMATTING RULES:\n"
          "1. NEVER reply with a generic welcome message or repeat instructions if the user asks a specific question. Answer their query directly.\n"
          "2. Provide actual recommendation names, a 1-line summary description, and a markdown link for the user to explore or book.\n"
          "3. Use a clean, scannable format with bolding, bullet points, and headers.\n"
          "4. Format hyperlinks using proper Markdown: [Link Text](URL). Since you are an AI, provide highly reliable search-query URLs to trusted platforms (e.g., TripAdvisor, MakeMyTrip, Google Maps).\n"
          "5. At the end of your response, ALWAYS suggest exactly 3 relevant follow-up actions or questions that the user might want to ask next. Format these suggestions at the very end of your response on a single line starting with: [Suggestions: Suggestion 1 | Suggestion 2 | Suggestion 3]. Make them short and specific (e.g., [Suggestions: Recommend beaches in Goa | What is the cost? | Packing list for Goa]). Do not include this block in the body of your message, keep it strictly formatted as specified.\n\n"
          "EXAMPLE LINK FORMATS TO USE:\n"
          "- Hotels: [View on TripAdvisor](https://www.tripadvisor.in/Search?q=Hotel+Name+${group.name})\n"
          "- Sights: [Search on Google Maps](https://www.google.com/maps/search/places+to+visit+in+${group.name}/)\n\n"
          "CONVERSATION LOGIC:\n"
          "- If the user sends a quick action pill like 'Recommend Hotels', reply with a curated list of 3-4 top budget/luxury hotels or resorts tailored to ${group.name}, using the required markdown links.\n"
          "- If they click 'Suggest Itinerary', provide a crisp 2 or 3-day plan with markdown links to sights.\n"
          "- If they click 'Packing Checklist', suggest location-specific items alongside essentials.\n\n"
          "Conversation history:\n"
          "$historyText\n"
          "Assistant:";

      String aiResponse = "";
      final apiKey = _getGeminiApiKey();
      if (apiKey != null && apiKey.isNotEmpty) {
        try {
          final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
          final response = await model.generateContent([Content.text(prompt)]);
          aiResponse = response.text ?? "";
        } catch (e) {
          debugPrint("Gemini Chat API Error: $e");
        }
      }

      List<String> suggestions = [];
      if (aiResponse.isEmpty) {
        final query = messageText.toLowerCase();
        if (query.contains('itinerary') || query.contains('plan') || query.contains('day') || query.contains('schedule')) {
          aiResponse = "Based on your interest, here is a custom itinerary recommendation for '${group.name}':\n\n"
              "• **Day 1**: Arrive, check-in, and relax. Spend the evening visiting a local cafe.\n"
              "• **Day 2**: Cultural exploration and local markets tour.\n"
              "• **Day 3**: Outdoor activities and a sunset dinner.\n\n"
              "Would you like me to suggest specific spots or estimate budgets?";
          suggestions = ['🏨 Recommend Hotels', '🎒 Packing Checklist', '💰 Cost Estimate'];
        } else if (query.contains('packing') || query.contains('pack') || query.contains('bring')) {
          aiResponse = "Here are packing suggestions for '${group.name}':\n\n"
              "1. 📱 **Essentials**: Chargers, IDs, cash.\n"
              "2. 🧴 **Personal**: Sunscreen, medicine.\n"
              "3. 👟 **Comfort**: Walk shoes, seasonal clothes.\n\n"
              "Assign these tasks to group members under the **Packing** tab!";
          suggestions = ['✈️ Suggest Itinerary', '🏨 Recommend Hotels', '🍽️ Local Food'];
        } else {
          aiResponse = "I am ready to help you plan! Ask me to recommend itineraries, hotels/sights to pin, or items to pack.";
          suggestions = ['✈️ Suggest Itinerary', '🏨 Recommend Hotels', '🎒 Packing Checklist'];
        }
      } else {
        // Parse suggestions out of Gemini response
        final RegExp suggestionRegExp = RegExp(r'\[Suggestions:\s*(.*?)\s*\]', caseSensitive: false);
        final match = suggestionRegExp.firstMatch(aiResponse);
        if (match != null) {
          final suggestionsStr = match.group(1);
          if (suggestionsStr != null) {
            suggestions = suggestionsStr
                .split('|')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
          }
          aiResponse = aiResponse.replaceAll(suggestionRegExp, '').trim();
        } else {
          // If Gemini response didn't include the tag properly, generate some context-aware defaults
          final cleanDest = group.name;
          suggestions = [
            '✈️ Suggest Itinerary for $cleanDest',
            '🏨 Recommend Hotels in $cleanDest',
            '🎒 Packing Checklist'
          ];
        }
      }

      group.chatMessages.removeWhere((msg) => msg['isTyping'] == true && msg['id'] == typingId);
      group.chatMessages.add({
        'sender': 'assistant',
        'text': aiResponse.trim(),
        'timestamp': DateTime.now(),
        'suggestions': suggestions,
      });
      notifyListeners();
    } catch (_) {}
  }

  // --- Payment Reminders ---

  void schedulePaymentReminder(String groupId, Duration duration, String message) {
    cancelPaymentReminder(groupId);
    final timer = Timer(duration, () {
      activeNotification = "Reminder: $message";
      _logActivity('system', "Payment reminder triggered for group '$groupId': $message");
      _groupTimers.remove(groupId);
      try {
        final group = _allGroups.firstWhere((g) => g.id == groupId);
        group.nextReminderTime = null;
      } catch (_) {}
      notifyListeners();
    });
    _groupTimers[groupId] = timer;
    try {
      final group = _allGroups.firstWhere((g) => g.id == groupId);
      group.nextReminderTime = DateTime.now().add(duration);
      group.reminderMessage = message;
    } catch (_) {}
    notifyListeners();
  }

  void cancelPaymentReminder(String groupId) {
    if (_groupTimers.containsKey(groupId)) {
      _groupTimers[groupId]!.cancel();
      _groupTimers.remove(groupId);
    }
    try {
      final group = _allGroups.firstWhere((g) => g.id == groupId);
      group.nextReminderTime = null;
      group.reminderMessage = null;
    } catch (_) {}
    notifyListeners();
  }

  // --- E2EE Group Chat Messages Sync ---
  
  Future<void> fetchGroupChat(String groupId) async {
    try {
      final messagesData = await _api.getChatMessages(groupId);
      final messages = messagesData.map<Map<String, dynamic>>((msg) => {
        'id': msg['id'] ?? msg['_id'] ?? '',
        'senderId': msg['senderId'],
        'senderName': msg['senderName'],
        'encryptedContent': msg['encryptedContent'],
        'timestamp': msg['timestamp'],
      }).toList();

      final group = _allGroups.firstWhere((g) => g.id == groupId);
      group.memberChatMessages = messages;
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching chat messages: $e");
    }
  }

  Future<void> sendGroupChatMessage(String groupId, String messageText) async {
    if (currentUser == null || messageText.trim().isEmpty) return;
    try {
      final group = _allGroups.firstWhere((g) => g.id == groupId);
      final encryptedText = E2eeHelper.encrypt(messageText.trim(), group.inviteCode);
      
      await _api.sendChatMessage(groupId, encryptedText);
      await fetchGroupChat(groupId);
    } catch (e) {
      debugPrint("Error sending E2EE message: $e");
    }
  }

  Future<void> deleteGroupChatMessage(String groupId, String messageId, String type) async {
    try {
      // Optimistically update UI for immediate feedback
      try {
        final group = _allGroups.firstWhere((g) => g.id == groupId);
        group.memberChatMessages.removeWhere((msg) => msg['id'] == messageId);
        notifyListeners();
      } catch (_) {}

      await _api.deleteChatMessage(groupId, messageId, type);
      await fetchGroupChat(groupId);
    } catch (e) {
      debugPrint("Error deleting E2EE message: $e");
      // Optionally re-fetch on failure to restore the deleted message
      await fetchGroupChat(groupId);
    }
  }

  Future<bool> changePassword(String currentPassword, String newPassword) async {
    if (currentUser == null) return false;
    
    // Check local password if stored
    if (currentUser!.password.isNotEmpty && currentUser!.password != currentPassword) {
      return false;
    }
    
    try {
      try {
        await _api.updatePassword(newPassword);
      } catch (e) {
        debugPrint("API updatePassword failed, proceeding locally: $e");
      }
      
      currentUser = User(
        id: currentUser!.id,
        name: currentUser!.name,
        email: currentUser!.email,
        phone: currentUser!.phone,
        password: newPassword,
        friendIds: currentUser!.friendIds,
        latitude: currentUser!.latitude,
        longitude: currentUser!.longitude,
        isOnline: currentUser!.isOnline,
        lastActive: currentUser!.lastActive,
      );
      
      // Update cache
      final idx = _allUsers.indexWhere((u) => u.id == currentUser!.id);
      if (idx != -1) {
        _allUsers[idx] = currentUser!;
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Error changing password: $e");
      return false;
    }
  }

  // --- Live Map Location Sharing & Sync ---

  Future<void> updateMyLocation(double? lat, double? lng, bool isOnline) async {
    try {
      await _api.updateMyLocation(lat, lng, isOnline);
      if (currentUser != null) {
        currentUser = User(
          id: currentUser!.id,
          name: currentUser!.name,
          email: currentUser!.email,
          phone: currentUser!.phone,
          password: currentUser!.password,
          friendIds: currentUser!.friendIds,
          latitude: lat,
          longitude: lng,
          isOnline: isOnline,
          lastActive: DateTime.now().toIso8601String(),
        );
        // Sync cache
        final idx = _allUsers.indexWhere((u) => u.id == currentUser!.id);
        if (idx != -1) {
          _allUsers[idx] = currentUser!;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error updating my location: $e");
    }
  }

  Future<void> fetchGroupLocations(String groupId) async {
    try {
      final locs = await _api.getGroupLocations(groupId);
      _currentGroupLocations = List<Map<String, dynamic>>.from(locs);
      
      // Update our _allUsers cache with these latest coordinate updates
      for (var l in _currentGroupLocations) {
        final uid = l['userId'] as String;
        final idx = _allUsers.indexWhere((u) => u.id == uid);
        if (idx != -1) {
          final u = _allUsers[idx];
          _allUsers[idx] = User(
            id: u.id,
            name: u.name,
            email: u.email,
            phone: u.phone,
            password: u.password,
            friendIds: u.friendIds,
            latitude: (l['latitude'] as num?)?.toDouble(),
            longitude: (l['longitude'] as num?)?.toDouble(),
            isOnline: l['isOnline'] as bool? ?? false,
            lastActive: l['lastActive'] as String?,
          );
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching group locations: $e");
    }
  }

  void startLocationPolling(String groupId) {
    _locationPollingTimer?.cancel();
    // Fetch immediately
    fetchGroupLocations(groupId);
    // Poll every 4 seconds
    _locationPollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      fetchGroupLocations(groupId);
    });
  }

  void stopLocationPolling() {
    _locationPollingTimer?.cancel();
    _locationPollingTimer = null;
  }

  void startChatPolling(String groupId) {
    _chatPollingTimer?.cancel();
    // Fetch immediately
    fetchGroupChat(groupId);
    // Poll every 3 seconds
    _chatPollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      fetchGroupChat(groupId);
    });
  }

  void stopChatPolling() {
    _chatPollingTimer?.cancel();
    _chatPollingTimer = null;
  }
}
