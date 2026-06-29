enum GroupType { Trip, Home, Couple, Others }

class Group {
  final String id;
  final String name;
  final GroupType type;
  final List<String> memberIds;
  final String inviteCode; // A code like 'TRIP-123' that others can use to join
  final String creatorId; // The user ID of the group creator
  DateTime? nextReminderTime; // The scheduled timestamp of the next reminder
  String? reminderMessage; // The scheduled reminder message
  List<Map<String, dynamic>> itinerary; // Travel itinerary activities
  List<Map<String, dynamic>> researchItems; // Pinned travel recommendations
  List<Map<String, dynamic>> packingItems; // Packing lists/checklists
  List<Map<String, dynamic>> chatMessages; // AI Travel Chat messages
  List<Map<String, dynamic>> memberChatMessages; // Secure E2EE group chat messages

  Group({
    required this.id,
    required this.name,
    required this.type,
    required this.memberIds,
    required this.inviteCode,
    required this.creatorId,
    this.nextReminderTime,
    this.reminderMessage,
    List<Map<String, dynamic>>? itinerary,
    List<Map<String, dynamic>>? researchItems,
    List<Map<String, dynamic>>? packingItems,
    List<Map<String, dynamic>>? chatMessages,
    List<Map<String, dynamic>>? memberChatMessages,
  })  : itinerary = itinerary ?? <Map<String, dynamic>>[],
        researchItems = researchItems ?? <Map<String, dynamic>>[],
        packingItems = packingItems ?? <Map<String, dynamic>>[],
        chatMessages = chatMessages ?? <Map<String, dynamic>>[],
        memberChatMessages = memberChatMessages ?? <Map<String, dynamic>>[];
}
