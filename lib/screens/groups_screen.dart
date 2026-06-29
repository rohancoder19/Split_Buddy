import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/group.dart';
import 'group_details_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final _joinCodeController = TextEditingController();

  void _showCreateGroupDialog(BuildContext context) {
    final state = Provider.of<AppState>(context, listen: false);
    final friends = state.myFriends;
    final nameController = TextEditingController();
    GroupType selectedType = GroupType.Trip;
    final List<String> selectedFriendIds = [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create a Group'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(hintText: 'Group Name'),
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),
                    DropdownButton<GroupType>(
                      value: selectedType,
                      isExpanded: true,
                      onChanged: (val) {
                        setDialogState(() {
                          selectedType = val!;
                        });
                      },
                      items: GroupType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.name),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Add friends to group:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    if (friends.isEmpty)
                      const Text(
                        'No friends added yet. You can add them under the Friends tab.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      )
                    else
                      Flexible(
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: friends.length,
                            itemBuilder: (context, index) {
                              final friend = friends[index];
                              final isChecked = selectedFriendIds.contains(friend.id);
                              return CheckboxListTile(
                                title: Text(friend.name),
                                value: isChecked,
                                dense: true,
                                controlAffinity: ListTileControlAffinity.leading,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                onChanged: (bool? checked) {
                                  setDialogState(() {
                                    if (checked == true) {
                                      selectedFriendIds.add(friend.id);
                                    } else {
                                      selectedFriendIds.remove(friend.id);
                                    }
                                  });
                                },
                              );
                            },
                          ),
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
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.isNotEmpty) {
                      state.createGroup(
                        nameController.text.trim(),
                        selectedType,
                        selectedFriendIds,
                      );
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showJoinGroupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Join a Group'),
          content: TextField(
            controller: _joinCodeController,
            decoration: const InputDecoration(hintText: 'Enter Invite Code (e.g., TRIP-1234)'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                _joinCodeController.clear();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_joinCodeController.text.isNotEmpty) {
                   final bool success = await Provider.of<AppState>(context, listen: false)
                      .joinGroupWithCode(_joinCodeController.text.trim());
                  _joinCodeController.clear();
                  Navigator.pop(context);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Successfully joined the group!')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Group not found or already joined.')),
                    );
                  }
                }
              },
              child: const Text('Join'),
            ),
          ],
        );
      },
    );
  }

  IconData _getGroupIcon(GroupType type) {
    switch (type) {
      case GroupType.Trip:
        return Icons.flight;
      case GroupType.Home:
        return Icons.home;
      case GroupType.Couple:
        return Icons.favorite;
      case GroupType.Others:
        return Icons.group;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        final groups = state.myGroups;
        return Scaffold(
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showCreateGroupDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Create Group'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showJoinGroupDialog(context),
                        icon: const Icon(Icons.link),
                        label: const Text('Join Group'),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: groups.isEmpty
                    ? const Center(child: Text('You are not in any groups yet.'))
                    : ListView.builder(
                        itemCount: groups.length,
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          final membersCount = group.memberIds.length;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                              child: Icon(_getGroupIcon(group.type), color: Theme.of(context).primaryColor),
                            ),
                            title: Text(group.name),
                            subtitle: Text('$membersCount members • Invite code: ${group.inviteCode}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => GroupDetailsScreen(groupId: group.id),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
