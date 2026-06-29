class Activity {
  final String id;
  final String userId; // The person who performed the activity
  final String actionText; // E.g., "created the group 'Trip'" or "added 'Dinner'"
  final DateTime date;

  Activity({
    required this.id,
    required this.userId,
    required this.actionText,
    required this.date,
  });
}
