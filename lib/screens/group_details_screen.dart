import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/app_state.dart';
import '../models/user.dart';
import '../models/group.dart';
import '../models/expense.dart';
import 'add_expense_screen.dart';
import 'balance_sheet_screen.dart';
import 'trip_planner_screen.dart';
import '../services/e2ee_helper.dart';
import '../services/csv_export.dart' as csv_exporter;
import 'dart:math';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class GroupDetailsScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailsScreen({super.key, required this.groupId});

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  bool _showCiphertext = false;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      final state = Provider.of<AppState>(context, listen: false);
      
      if (_tabController.index == 2) {
        state.startChatPolling(widget.groupId);
      } else {
        state.stopChatPolling();
      }

      if (_tabController.index == 3) {
        state.startLocationPolling(widget.groupId);
      } else {
        state.stopLocationPolling();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppState>(context, listen: false).fetchGroupExpenses(widget.groupId);
    });
  }

  @override
  void dispose() {
    final state = Provider.of<AppState>(context, listen: false);
    state.stopLocationPolling();
    state.stopChatPolling();
    _tabController.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        final groups = state.myGroups;
        if (groups.isEmpty) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final group = groups.firstWhere((g) => g.id == widget.groupId, orElse: () => groups.first);
        final members = state.getGroupMembers(widget.groupId);
        final expenses = state.getGroupExpenses(widget.groupId);
        final balances = state.getGroupBalances(widget.groupId);

        return DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              title: Text(group.name),
              actions: [
                if (group.type == GroupType.Trip)
                  IconButton(
                    icon: const Icon(Icons.flight_takeoff),
                    tooltip: 'Trip Planner',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TripPlannerScreen(groupId: group.id),
                        ),
                      );
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.person_add),
                  tooltip: 'Add Member',
                  onPressed: () {
                    _showAddMemberDialog(context, state, group);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: 'Copy Invite Link',
                  onPressed: () {
                    final link = 'https://splitwise.app/join/${group.inviteCode}';
                    Clipboard.setData(ClipboardData(text: link));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invite link copied to clipboard!')),
                    );
                  },
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: Theme.of(context).primaryColor,
                tabs: const [
                  Tab(icon: Icon(Icons.receipt_long), text: 'Expenses'),
                  Tab(icon: Icon(Icons.account_balance_wallet), text: 'Balances'),
                  Tab(icon: Icon(Icons.lock), text: 'Secure Chat'),
                  Tab(icon: Icon(Icons.map), text: 'Live Map'),
                ],
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: EXPENSES
                _buildExpensesTab(context, state, expenses),

                // TAB 2: BALANCES
                _buildBalancesTab(context, state, group, members, expenses, balances),

                // TAB 3: SECURE CHAT
                _buildSecureChatTab(context, state, group, members),

                // TAB 4: LIVE MAP
                _buildLiveMapTab(context, state, group, members),
              ],
            ),
            floatingActionButton: AnimatedBuilder(
              animation: _tabController,
              builder: (context, child) {
                return _tabController.index == 0
                    ? FloatingActionButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddExpenseScreen(preselectedGroupId: group.id),
                            ),
                          );
                        },
                        child: const Icon(Icons.add),
                      )
                    : const SizedBox.shrink();
              },
            ),
          ),
        );
      },
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildExpensesTab(BuildContext context, AppState state, List<Expense> expenses) {
    if (expenses.isEmpty) {
      return const Center(child: Text('No expenses in this group yet.'));
    }
    return ListView.builder(
      itemCount: expenses.length,
      padding: const EdgeInsets.only(bottom: 72.0, top: 8.0),
      itemBuilder: (context, index) {
        final expense = expenses[expenses.length - 1 - index];

        // Payers summary
        List<String> payerNames = [];
        expense.payers.forEach((pid, amount) {
          final name = state.getUserName(pid);
          payerNames.add(name);
        });
        final payersStr = payerNames.join(', ');
        
        final isSettlement = expense.description.startsWith('Settlement:');

        return ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSettlement ? Colors.teal[50] : Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isSettlement ? Icons.handshake_outlined : Icons.receipt_long,
              color: isSettlement ? Colors.teal : Colors.grey[800],
            ),
          ),
          title: Text(
            expense.description,
            style: TextStyle(
              fontWeight: isSettlement ? FontWeight.w500 : FontWeight.normal,
              color: isSettlement ? Colors.teal[800] : Colors.black,
            ),
          ),
          subtitle: Text('$payersStr paid ₹${expense.amount.toStringAsFixed(2)}'),
          trailing: Text(
            '₹${expense.amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isSettlement ? Colors.teal : Colors.black,
            ),
          ),
        );
      },
    );
  }

  Widget _buildBalancesTab(
      BuildContext context,
      AppState state,
      Group group,
      List<User> members,
      List<Expense> expenses,
      Map<String, double> balances) {
    final detailedSettlements = _calculateDetailedSettlements(balances, members);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Net Balances Summary Card
          Card(
            elevation: 1,
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Net Balances',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...members.map((member) {
                    final bal = balances[member.id] ?? 0.0;
                    Color balColor = Colors.grey;
                    String balText = 'Settled up';

                    if (bal > 0.01) {
                      balColor = Colors.teal;
                      balText = 'gets back ₹${bal.toStringAsFixed(2)}';
                    } else if (bal < -0.01) {
                      balColor = Colors.orange[800]!;
                      balText = 'owes ₹${(-bal).toStringAsFixed(2)}';
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                child: Text(member.name.isNotEmpty ? member.name[0].toUpperCase() : '?'),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                member.name, 
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)
                              ),
                            ],
                          ),
                          Text(balText, style: TextStyle(color: balColor, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Recommended Settlements Card
          Card(
            elevation: 1,
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recommended Settlement Plan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (detailedSettlements.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                            'All debts are settled! No payments required.',
                            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    )
                  else
                    ...detailedSettlements.map((settlement) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                                  children: [
                                    TextSpan(
                                      text: settlement.debtorName,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const TextSpan(text: ' owes '),
                                    TextSpan(
                                      text: settlement.creditorName,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const TextSpan(text: '\n'),
                                    TextSpan(
                                      text: '₹${settlement.amount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Colors.teal, 
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                                foregroundColor: Theme.of(context).primaryColor,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              onPressed: () {
                                _showSettleUpBottomSheet(context, state, group.id, settlement);
                              },
                              child: const Text('Settle', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Export and Reports Section Card
          Card(
            elevation: 1,
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reports & Exports',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BalanceSheetScreen(groupId: group.id),
                              ),
                            );
                          },
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('PDF Report'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _exportExpensesToCsv(context, state, group);
                          },
                          icon: const Icon(Icons.table_chart),
                          label: const Text('Export CSV'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Payment Reminder Card (visible to Creator only)
          if (group.creatorId == state.currentUser?.id) ...[
            const SizedBox(height: 16),
            Card(
              elevation: 1,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.alarm, color: Theme.of(context).primaryColor, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Payment Reminder',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        if (group.nextReminderTime != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Active',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.secondary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (group.nextReminderTime == null) ...[
                      const Text(
                        'No active payment reminders. You can schedule a timer to remind all members to settle their dues.',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => _showScheduleReminderDialog(context, state, group.id, group.name),
                        icon: const Icon(Icons.schedule, size: 18),
                        label: const Text('Schedule Reminder'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 40),
                        ),
                      ),
                    ] else ...[
                      const Text(
                        'A reminder is scheduled to be sent.',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Message: "${group.reminderMessage}"',
                        style: TextStyle(color: Colors.grey[800], fontSize: 13, fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 4),
                      Builder(
                        builder: (context) {
                          final secondsLeft = group.nextReminderTime!.difference(DateTime.now()).inSeconds;
                          String timeLeftStr = '';
                          if (secondsLeft > 0) {
                            if (secondsLeft < 60) {
                              timeLeftStr = 'in $secondsLeft seconds';
                            } else {
                              timeLeftStr = 'in ${(secondsLeft / 60).round()} minute(s)';
                            }
                          } else {
                            timeLeftStr = 'any second now';
                          }
                          return Text(
                            'Triggers: $timeLeftStr (${group.nextReminderTime!.toLocal().toString().split('.')[0].substring(11, 19)})',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => state.cancelPaymentReminder(group.id),
                        icon: const Icon(Icons.cancel, size: 18),
                        label: const Text('Cancel Reminder'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          minimumSize: const Size(double.infinity, 40),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSecureChatTab(
      BuildContext context, AppState state, Group group, List<User> members) {
    final messages = group.memberChatMessages;
    
    // Auto-scroll to bottom whenever this tab loads or messages change
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Column(
      children: [
        // Security Status Header
        Container(
          color: Colors.grey[100],
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.security, color: Colors.green, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'E2EE Shield Active',
                    style: TextStyle(
                      color: Colors.green[800], 
                      fontWeight: FontWeight.bold, 
                      fontSize: 12
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  // Ciphertext Toggle Icon
                  IconButton(
                    icon: Icon(
                      _showCiphertext ? Icons.visibility : Icons.visibility_off, 
                      size: 18, 
                      color: Colors.grey[700]
                    ),
                    tooltip: _showCiphertext ? 'Show Plaintext' : 'Show Encrypted Ciphertext',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: () {
                      setState(() {
                        _showCiphertext = !_showCiphertext;
                      });
                    },
                  ),
                  // Key Fingerprint Button
                  TextButton.icon(
                    onPressed: () => _showVerifyKeysDialog(context, group, members),
                    icon: const Icon(Icons.key, size: 14),
                    label: const Text('Verify Keys', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Message Feed
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'This is the beginning of your secure group chat.',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'All messages are encrypted end-to-end.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _chatScrollController,
                  itemCount: messages.length,
                  padding: const EdgeInsets.all(16.0),
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['senderId'] == state.currentUser?.id;
                    
                    // Decrypt content using E2EE Helper
                    final rawContent = msg['encryptedContent'] as String;
                    final decryptedText = E2eeHelper.decrypt(rawContent, group.inviteCode);
                    final displayText = _showCiphertext ? rawContent : decryptedText;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Padding(
                                padding: const EdgeInsets.only(left: 4.0, bottom: 2.0),
                                child: Text(
                                  msg['senderName'] ?? 'Member',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                                ),
                              ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (isMe)
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, size: 16, color: Colors.grey),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onSelected: (value) {
                                      state.deleteGroupChatMessage(group.id, msg['id'], value);
                                    },
                                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                      const PopupMenuItem<String>(
                                        value: 'me',
                                        child: Text('Delete for Me'),
                                      ),
                                      const PopupMenuItem<String>(
                                        value: 'everyone',
                                        child: Text('Delete for Everyone', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                Flexible(
                                  child: GestureDetector(
                                    onLongPress: () {
                                      _showDeleteMessageOptions(context, state, group.id, msg, isMe);
                                    },
                                    onSecondaryTap: () {
                                      _showDeleteMessageOptions(context, state, group.id, msg, isMe);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                                      decoration: BoxDecoration(
                                        color: isMe 
                                            ? Theme.of(context).primaryColor 
                                            : Colors.grey[200],
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(16),
                                          topRight: const Radius.circular(16),
                                          bottomLeft: Radius.circular(isMe ? 16 : 0),
                                          bottomRight: Radius.circular(isMe ? 0 : 16),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              displayText,
                                              style: TextStyle(
                                                color: isMe ? Colors.white : Colors.black87,
                                                fontSize: 14,
                                                fontFamily: _showCiphertext ? 'Courier' : null,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Tooltip(
                                            message: _showCiphertext
                                                ? 'Encrypted Ciphertext'
                                                : 'Locally Decrypted (E2EE)',
                                            child: Icon(
                                              _showCiphertext ? Icons.lock : Icons.lock_open,
                                              size: 11,
                                              color: isMe ? Colors.white70 : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                if (!isMe)
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, size: 16, color: Colors.grey),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onSelected: (value) {
                                      state.deleteGroupChatMessage(group.id, msg['id'], value);
                                    },
                                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                      const PopupMenuItem<String>(
                                        value: 'me',
                                        child: Text('Delete for Me'),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        const Divider(height: 1),

        // Message Input
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Type an E2EE message...',
                    hintStyle: const TextStyle(fontSize: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    fillColor: Colors.grey[150],
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) {
                      state.sendGroupChatMessage(group.id, val);
                      _chatController.clear();
                      _scrollToBottom();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: () {
                    final text = _chatController.text.trim();
                    if (text.isNotEmpty) {
                      state.sendGroupChatMessage(group.id, text);
                      _chatController.clear();
                      _scrollToBottom();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showDeleteMessageOptions(
      BuildContext context, AppState state, String groupId, Map<String, dynamic> message, bool isMe) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Delete Message?'),
          content: const Text('Are you sure you want to delete this message?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                state.deleteGroupChatMessage(groupId, message['id'], 'me');
              },
              child: const Text('Delete for Me', style: TextStyle(color: Colors.red)),
            ),
            if (isMe)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  state.deleteGroupChatMessage(groupId, message['id'], 'everyone');
                },
                child: const Text('Delete for Everyone', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
          ],
        );
      },
    );
  }

  // --- ACTIONS & SHEETS ---

  void _showSettleUpBottomSheet(
      BuildContext context, AppState state, String groupId, SettlementItem settlement) {
    String paymentMode = 'UPI'; // Default
    final mockUpiId = '${settlement.creditorName.toLowerCase().replaceAll(' ', '')}@okaxis';
    final upiUri = 'upi://pay?pa=$mockUpiId&pn=${Uri.encodeComponent(settlement.creditorName)}&am=${settlement.amount.toStringAsFixed(2)}&cu=INR&tn=Splitwise%20Settlement';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20.0,
                left: 20.0,
                right: 20.0,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Record Settlement',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Transaction Detail Block
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Column(
                              children: [
                                CircleAvatar(radius: 20, child: Text(settlement.debtorName[0])),
                                const SizedBox(height: 4),
                                Text(settlement.debtorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const Icon(Icons.arrow_forward, color: Colors.teal),
                            Column(
                              children: [
                                CircleAvatar(radius: 20, child: Text(settlement.creditorName[0])),
                                const SizedBox(height: 4),
                                Text(settlement.creditorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '₹${settlement.amount.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Mode Selector
                  const Text('Select Payment Mode:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setSheetState(() {
                              paymentMode = 'UPI';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: paymentMode == 'UPI' ? Colors.teal[50] : Colors.white,
                              border: Border.all(
                                color: paymentMode == 'UPI' ? Colors.teal : Colors.grey[300]!,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.qr_code, color: paymentMode == 'UPI' ? Colors.teal : Colors.grey),
                                const SizedBox(height: 4),
                                Text(
                                  'Pay via UPI QR',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: paymentMode == 'UPI' ? Colors.teal : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setSheetState(() {
                              paymentMode = 'CASH';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: paymentMode == 'CASH' ? Colors.teal[50] : Colors.white,
                              border: Border.all(
                                color: paymentMode == 'CASH' ? Colors.teal : Colors.grey[300]!,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.money, color: paymentMode == 'CASH' ? Colors.teal : Colors.grey),
                                const SizedBox(height: 4),
                                Text(
                                  'Record Cash',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: paymentMode == 'CASH' ? Colors.teal : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Mode content
                  if (paymentMode == 'UPI') ...[
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: Colors.grey[200]!, blurRadius: 10, spreadRadius: 2),
                          ],
                        ),
                        child: QrImageView(
                          data: upiUri,
                          version: QrVersions.auto,
                          size: 160.0,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'UPI ID: $mockUpiId',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Scan this QR code using GPay, PhonePe, or Paytm to initiate the transaction.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ] else ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Column(
                        children: [
                          Icon(Icons.handshake, size: 48, color: Colors.teal),
                          SizedBox(height: 12),
                          Text(
                            'Paid cash or settled outside the app.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          Text(
                            'Confirming this will instantly reset outstanding balances.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Confirm button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: () {
                      state.settleDebt(
                        debtorId: settlement.debtorId,
                        creditorId: settlement.creditorId,
                        amount: settlement.amount,
                        groupId: groupId,
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Recorded settlement: ${settlement.debtorName} settled ₹${settlement.amount.toStringAsFixed(2)} to ${settlement.creditorName}',
                          ),
                          backgroundColor: Colors.teal,
                        ),
                      );
                    },
                    child: Text(
                      paymentMode == 'UPI' ? 'Confirm Payment Received' : 'Record Cash Settlement',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _exportExpensesToCsv(BuildContext context, AppState state, Group group) {
    final expenses = state.getGroupExpenses(group.id);
    if (expenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No expenses to export!')),
      );
      return;
    }

    final csvContent = _generateCsvContent(expenses, state);
    final filename = 'Expenses_${group.name.replaceAll(' ', '_')}.csv';
    csv_exporter.downloadCsv(csvContent, filename);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('CSV file "$filename" downloaded successfully!'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  String _generateCsvContent(List<Expense> expenses, AppState state) {
    final buffer = StringBuffer();
    // Headers
    buffer.writeln("Date,Description,Total Amount,Payer(s),Involved Members");

    for (var exp in expenses) {
      final dateStr = exp.date.toIso8601String().split('T')[0];
      final desc = exp.description.replaceAll('"', '""');
      final amount = exp.amount.toStringAsFixed(2);

      List<String> payersList = [];
      exp.payers.forEach((pid, pAmount) {
        final name = state.getUserName(pid);
        payersList.add("$name ($pAmount)");
      });
      final payersStr = payersList.join(" | ").replaceAll('"', '""');

      final involvedNames = exp.involvedUserIds.map((uid) => state.getUserName(uid)).join(" | ").replaceAll('"', '""');

      buffer.writeln('"$dateStr","$desc",$amount,"$payersStr","$involvedNames"');
    }
    return buffer.toString();
  }

  void _showVerifyKeysDialog(BuildContext context, Group group, List<User> members) {
    final sessionFingerprint = E2eeHelper.getSessionFingerprint(group.inviteCode);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.verified_user, color: Colors.teal),
              SizedBox(width: 8),
              Text('Verify Encryption Keys'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'To verify E2EE integrity, compare these fingerprints with other group members. If they match, your connection is fully secure.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  
                  // Session Key
                  const Text('Active Session Key:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    color: Colors.grey[100],
                    child: Text(
                      group.inviteCode,
                      style: const TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Session Fingerprint
                  const Text('Group Fingerprint (SHA):', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    color: Colors.teal[50],
                    child: Text(
                      sessionFingerprint,
                      style: const TextStyle(fontFamily: 'Courier', color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Member Fingerprints
                  const Text('Member Device Fingerprints:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...members.map((member) {
                    final fingerprint = E2eeHelper.getUserFingerprint(member.id, member.name);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(member.name, style: const TextStyle(fontSize: 13)),
                          Text(
                            fingerprint,
                            style: const TextStyle(fontFamily: 'Courier', fontSize: 11, color: Colors.blueGrey),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  List<SettlementItem> _calculateDetailedSettlements(Map<String, double> balances, List<User> groupMembers) {
    List<SettlementItem> settlements = [];
    List<MapEntry<String, double>> debtors = [];
    List<MapEntry<String, double>> creditors = [];

    balances.forEach((userId, balance) {
      if (balance < -0.01) {
        debtors.add(MapEntry(userId, balance));
      } else if (balance > 0.01) {
        creditors.add(MapEntry(userId, balance));
      }
    });

    int i = 0;
    int j = 0;
    List<MapEntry<String, double>> workingDebtors = List.from(debtors);
    List<MapEntry<String, double>> workingCreditors = List.from(creditors);

    while (i < workingDebtors.length && j < workingCreditors.length) {
      double debt = -workingDebtors[i].value;
      double credit = workingCreditors[j].value;
      double amountToSettle = debt < credit ? debt : credit;
      
      final debtor = groupMembers.firstWhere(
        (u) => u.id == workingDebtors[i].key, 
        orElse: () => User(id: '', name: 'Unknown', email: '', phone: '', password: '', friendIds: [])
      );
      final creditor = groupMembers.firstWhere(
        (u) => u.id == workingCreditors[j].key, 
        orElse: () => User(id: '', name: 'Unknown', email: '', phone: '', password: '', friendIds: [])
      );

      settlements.add(SettlementItem(
        debtorId: debtor.id,
        debtorName: debtor.name,
        creditorId: creditor.id,
        creditorName: creditor.name,
        amount: amountToSettle,
      ));

      workingDebtors[i] = MapEntry(workingDebtors[i].key, workingDebtors[i].value + amountToSettle);
      workingCreditors[j] = MapEntry(workingCreditors[j].key, workingCreditors[j].value - amountToSettle);

      if (-workingDebtors[i].value < 0.01) {
        i++;
      }
      if (workingCreditors[j].value < 0.01) {
        j++;
      }
    }

    return settlements;
  }

  // --- PRE-EXISTING HELPER METHODS ---

  void _showScheduleReminderDialog(
      BuildContext context, AppState state, String groupId, String groupName) {
    final messageController = TextEditingController(
      text: 'Please settle your pending balances in group "$groupName"!',
    );
    int selectedSeconds = 10; // Default 10 seconds for demo

    final Map<int, String> durationOptions = {
      10: '10 Seconds (Demo)',
      60: '1 Minute (Demo)',
      3600: '1 Hour',
      86400: '1 Day',
      604800: '1 Week',
    };

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Schedule Payment Reminder'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This will alert all group members once the timer expires.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: messageController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Reminder Message',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Timer Duration:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: selectedSeconds,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: durationOptions.entries.map((entry) {
                      return DropdownMenuItem<int>(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        selectedSeconds = val!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final message = messageController.text.trim();
                    if (message.isNotEmpty) {
                      state.schedulePaymentReminder(
                        groupId,
                        Duration(seconds: selectedSeconds),
                        message,
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Reminder scheduled in ${durationOptions[selectedSeconds]}!',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Schedule'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddMemberDialog(BuildContext context, AppState state, Group group) {
    final candidates = state.myFriends.where((f) => !group.memberIds.contains(f.id)).toList();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Member to Group'),
          content: SizedBox(
            width: double.maxFinite,
            child: candidates.isEmpty
                ? const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'All of your friends are already in this group!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select a friend to add to this group:',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: candidates.length,
                          itemBuilder: (context, index) {
                            final friend = candidates[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                child: Text(friend.name.isNotEmpty ? friend.name[0].toUpperCase() : '?'),
                              ),
                              title: Text(friend.name),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  state.addFriendToGroup(group.id, friend.id);
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Added ${friend.name} to the group!')),
                                  );
                                },
                                child: const Text('Add'),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  LatLng _getDestinationCoordinates(String destinationName) {
    final name = destinationName.toLowerCase();
    if (name.contains('darjeeling')) return const LatLng(27.0410, 88.2627);
    if (name.contains('goa')) return const LatLng(15.2993, 74.1240);
    if (name.contains('kolkata')) return const LatLng(22.5726, 88.3639);
    if (name.contains('delhi')) return const LatLng(28.7041, 77.1025);
    if (name.contains('mumbai')) return const LatLng(19.0760, 72.8777);
    if (name.contains('udaipur')) return const LatLng(24.5854, 73.7125);
    if (name.contains('mandarmoni') || name.contains('mandarmani')) return const LatLng(21.6628, 87.6010);
    if (name.contains('tajpur')) return const LatLng(21.6582, 87.6253);
    if (name.contains('puri')) return const LatLng(19.8135, 85.8312);
    if (name.contains('manali')) return const LatLng(32.2396, 77.1887);
    if (name.contains('shimla')) return const LatLng(31.1048, 77.1734);
    // Default to Digha
    return const LatLng(21.6264, 87.5074);
  }

  Future<Position?> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        return null;
      } 

      return await Geolocator.getCurrentPosition();
    } catch (e) {
      print("Error getting geolocator position: $e");
      return null;
    }
  }

  Widget _buildLiveMapTab(BuildContext context, AppState state, Group group, List<User> members) {
    final bool isOnline = state.currentUser?.isOnline ?? false;
    final LatLng defaultCenter = _getDestinationCoordinates(group.name);

    // Filter only online members with valid coordinates
    // We map current user's coordinates directly from state.currentUser to avoid waiting for polling
    final onlineMembers = state.currentGroupLocations.map((loc) {
      if (loc['userId'] == state.currentUser?.id) {
        return {
          'userId': state.currentUser!.id,
          'name': state.currentUser!.name,
          'latitude': state.currentUser!.latitude,
          'longitude': state.currentUser!.longitude,
          'isOnline': state.currentUser!.isOnline,
        };
      }
      return loc;
    }).where((loc) => 
      loc['isOnline'] == true && 
      loc['latitude'] != null && 
      loc['longitude'] != null
    ).toList();
    
    // If current user is online but locations list is empty, ensure current user is represented
    if (isOnline && state.currentUser?.latitude != null && state.currentUser?.longitude != null) {
      if (!onlineMembers.any((m) => m['userId'] == state.currentUser!.id)) {
        onlineMembers.add({
          'userId': state.currentUser!.id,
          'name': state.currentUser!.name,
          'latitude': state.currentUser!.latitude,
          'longitude': state.currentUser!.longitude,
          'isOnline': true,
        });
      }
    }

    // Default center dynamically resolved if no locations are available
    LatLng mapCenter = defaultCenter;
    if (onlineMembers.isNotEmpty) {
      mapCenter = LatLng(
        onlineMembers.first['latitude'] as double,
        onlineMembers.first['longitude'] as double,
      );
    }

    return Column(
      children: [
        // Control Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 8,
                    backgroundColor: isOnline ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isOnline ? 'You are sharing location' : 'Location sharing offline',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Switch(
                value: isOnline,
                activeColor: Theme.of(context).primaryColor,
                onChanged: (val) async {
                  if (val) {
                    // Try to get actual GPS coordinates
                    final position = await _determinePosition();
                    if (position != null) {
                      await state.updateMyLocation(position.latitude, position.longitude, true);
                    } else {
                      // Fallback to dynamic geocentered coordinates if permission denied / unavailable
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not access live GPS. Sharing trip destination coordinates instead.')),
                      );
                      final random = Random();
                      final double lat = defaultCenter.latitude + (random.nextDouble() - 0.5) * 0.02;
                      final double lng = defaultCenter.longitude + (random.nextDouble() - 0.5) * 0.02;
                      await state.updateMyLocation(lat, lng, true);
                    }
                  } else {
                    await state.updateMyLocation(null, null, false);
                  }
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        
        // Map View
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: mapCenter,
                  initialZoom: 13.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                    userAgentPackageName: 'com.tripplanner.app',
                  ),
                  MarkerLayer(
                    markers: onlineMembers.map((loc) {
                      final name = loc['name'] as String? ?? 'Member';
                      final lat = loc['latitude'] as double;
                      final lng = loc['longitude'] as double;
                      final isMe = loc['userId'] == state.currentUser?.id;

                      return Marker(
                        point: LatLng(lat, lng),
                        width: 70,
                        height: 70,
                        child: Tooltip(
                          message: isMe ? "You ($name)" : name,
                          triggerMode: TooltipTriggerMode.tap,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isMe ? const Color(0xFF5BC5A7) : Colors.blueGrey[800],
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  isMe ? 'Me' : name.split(' ').first,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 30,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: Theme.of(context).primaryColor,
                  child: const Icon(Icons.my_location),
                  onPressed: () async {
                    if (isOnline) {
                      final position = await _determinePosition();
                      if (position != null) {
                        await state.updateMyLocation(position.latitude, position.longitude, true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Live GPS location updated!')),
                        );
                        _mapController.move(LatLng(position.latitude, position.longitude), 13.0);
                      } else {
                        // Fallback: Jitter the current simulated coordinates
                        final random = Random();
                        final double lat = (state.currentUser?.latitude ?? defaultCenter.latitude) + (random.nextDouble() - 0.5) * 0.003;
                        final double lng = (state.currentUser?.longitude ?? defaultCenter.longitude) + (random.nextDouble() - 0.5) * 0.003;
                        await state.updateMyLocation(lat, lng, true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('GPS unavailable. Updated mock coordinates instead.')),
                        );
                        _mapController.move(LatLng(lat, lng), 13.0);
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please turn location sharing ON to update positions')),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Member Location Status List
        Expanded(
          flex: 2,
          child: Container(
            color: Colors.white,
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: members.length,
              itemBuilder: (context, index) {
                final member = members[index];
                // Find latest status in locations list
                final loc = state.currentGroupLocations.firstWhere(
                  (l) => l['userId'] == member.id,
                  orElse: () => <String, dynamic>{},
                );
                final bool isMe = member.id == state.currentUser?.id;
                final bool memberOnline = isMe 
                    ? (state.currentUser?.isOnline ?? false) 
                    : (loc['isOnline'] as bool? ?? false);
                final double? lat = isMe 
                    ? state.currentUser?.latitude 
                    : (loc['latitude'] as double?);
                final double? lng = isMe 
                    ? state.currentUser?.longitude 
                    : (loc['longitude'] as double?);

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: memberOnline ? Colors.green[50] : Colors.grey[100],
                    child: Icon(
                      Icons.person,
                      color: memberOnline ? Colors.green : Colors.grey,
                    ),
                  ),
                  title: Text(
                    member.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    memberOnline 
                      ? 'Online (Lat: ${lat?.toStringAsFixed(4)}, Lng: ${lng?.toStringAsFixed(4)})'
                      : 'Offline',
                    style: TextStyle(
                      color: memberOnline ? Colors.green[700] : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: memberOnline ? Colors.green[50] : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      memberOnline ? 'Sharing' : 'Offline',
                      style: TextStyle(
                        color: memberOnline ? Colors.green : Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class SettlementItem {
  final String debtorId;
  final String debtorName;
  final String creditorId;
  final String creditorName;
  final double amount;

  SettlementItem({
    required this.debtorId,
    required this.debtorName,
    required this.creditorId,
    required this.creditorName,
    required this.amount,
  });
}
