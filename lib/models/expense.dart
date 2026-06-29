class Expense {
  final String id;
  final String? groupId; // Can be null if it's a direct expense between friends
  final String description;
  final double amount;
  final Map<String, double> payers; // memberId -> amount paid
  final List<String> involvedUserIds;
  final DateTime date;

  Expense({
    required this.id,
    this.groupId,
    required this.description,
    required this.amount,
    required this.payers,
    required this.involvedUserIds,
    required this.date,
  });
}
