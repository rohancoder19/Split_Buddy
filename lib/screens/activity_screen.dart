import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        final activities = state.myActivities;

        return Scaffold(
          body: activities.isEmpty
              ? const Center(
                  child: Text(
                    'No activities yet.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: activities.length,
                  itemBuilder: (context, index) {
                    final activity = activities[index];
                    final actorName = state.getUserName(activity.userId);
                    final isMe = activity.userId == state.currentUser?.id;
                    final displayActor = isMe ? "You" : actorName;

                    // Format date
                    final timeStr = "${activity.date.hour}:${activity.date.minute.toString().padLeft(2, '0')}";

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isMe ? Colors.green[100] : Colors.blue[100],
                        child: Icon(
                          isMe ? Icons.person : Icons.people,
                          color: isMe ? Colors.green[700] : Colors.blue[700],
                        ),
                      ),
                      title: Text('$displayActor ${activity.actionText}'),
                      subtitle: Text(timeStr),
                    );
                  },
                ),
        );
      },
    );
  }
}
