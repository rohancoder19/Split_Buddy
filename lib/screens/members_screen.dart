import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class MembersScreen extends StatelessWidget {
  const MembersScreen({super.key});

  void _showAddMemberDialog(BuildContext context) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Member'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: 'Enter member name'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  Provider.of<AppState>(context, listen: false).addMember(nameController.text);
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        final members = state.users;
        
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: () => _showAddMemberDialog(context),
                icon: const Icon(Icons.person_add),
                label: const Text('Add New Member'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
            Expanded(
              child: members.isEmpty
                  ? const Center(child: Text('No members in this shared account yet.'))
                  : ListView.builder(
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        final member = members[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(member.name.isNotEmpty ? member.name[0].toUpperCase() : '?'),
                          ),
                          title: Text(member.name),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
