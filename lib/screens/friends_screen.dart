import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import '../providers/app_state.dart';
import 'add_friend_search_screen.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  Future<void> _addFriendFromNativeContacts(BuildContext context) async {
    final state = Provider.of<AppState>(context, listen: false);
    try {
      // Request permission
      final permission = await fc.FlutterContacts.permissions.request(fc.PermissionType.read);
      if (permission == fc.PermissionStatus.granted || permission == fc.PermissionStatus.limited) {
        // Open native contact picker
        final dynamic picked = await fc.FlutterContacts.native.showPicker();
        if (picked != null) {
          final String contactId = picked is String ? picked : picked.id.toString();
          final contact = await fc.FlutterContacts.get(contactId);
          if (contact != null && contact.phones.isNotEmpty) {
            final String displayName = contact.displayName ?? '';
            final String name = displayName.isEmpty ? 'Unknown' : displayName;
            final String rawPhone = contact.phones.first.number;
            final String phone = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');
            
            final String email = contact.emails.isNotEmpty
                ? contact.emails.first.address
                : '${name.toLowerCase().replaceAll(' ', '')}@gmail.com';
            
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Adding $name as friend ($phone)...')),
              );
            }
            
            // Add friend logic
            final addedByPhone = await state.addFriendByEmailOrPhone(phone);
            if (addedByPhone) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Added $name to friends list!')),
                );
              }
              return;
            }
            
            // Register user dynamically in backend
            await state.registerUser(name, email, phone, 'password');
            final success = await state.addFriendByEmailOrPhone(phone);
            
            if (context.mounted) {
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Added $name to friends list!')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not add $name as a friend.')),
                );
              }
            }
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Selected contact does not have a phone number.')),
              );
            }
          }
        }
      } else {
        // Permission denied, fall back to manual search screen
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddFriendSearchScreen()),
          );
        }
      }
    } catch (e) {
      // Fallback to manual search screen if native picker fails (e.g. Web)
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddFriendSearchScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        final friends = state.myFriends;
        return Scaffold(
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: () => _addFriendFromNativeContacts(context),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Friend from Contacts'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ),
              Expanded(
                child: friends.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.people_outline, size: 80, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text(
                              'No friends to show.',
                              style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: () => _addFriendFromNativeContacts(context),
                              icon: const Icon(Icons.person_add_alt_1),
                              label: const Text('Add more friends'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: friends.length,
                        itemBuilder: (context, index) {
                          final friend = friends[index];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(friend.name.isNotEmpty ? friend.name[0].toUpperCase() : '?'),
                            ),
                            title: Text(friend.name),
                            subtitle: Text(friend.phone),
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
