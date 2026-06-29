import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import 'login_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  void _showChangePasswordDialog(BuildContext context, AppState state) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;
    String errorMessage = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(errorMessage, style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                    TextField(
                      controller: currentPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Current Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm New Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final current = currentPasswordController.text;
                          final newPass = newPasswordController.text;
                          final confirm = confirmPasswordController.text;

                          if (newPass != confirm) {
                            setDialogState(() => errorMessage = 'New passwords do not match');
                            return;
                          }
                          if (newPass.length < 6) {
                            setDialogState(() => errorMessage = 'Password must be at least 6 characters');
                            return;
                          }

                          setDialogState(() {
                            isLoading = true;
                            errorMessage = '';
                          });

                          final success = await state.changePassword(current, newPass);

                          setDialogState(() {
                            isLoading = false;
                          });

                          if (success) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Password changed successfully!'), backgroundColor: Colors.teal),
                            );
                          } else {
                            setDialogState(() {
                              errorMessage = 'Failed to change password. Check current password.';
                            });
                          }
                        },
                  child: isLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Change'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        final user = state.currentUser;
        if (user == null) return const SizedBox();

        final netBalance = state.getMyNetBalance();
        final totalSpent = state.getMyTotalSpent();

        Color balColor = Colors.grey;
        String balText = 'You are settled up';

        if (netBalance > 0.01) {
          balColor = Theme.of(context).primaryColor;
          balText = 'You are owed ₹${netBalance.toStringAsFixed(2)} overall';
        } else if (netBalance < -0.01) {
          balColor = Theme.of(context).colorScheme.secondary;
          balText = 'You owe ₹${(-netBalance).toStringAsFixed(2)} overall';
        }

        return Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                        child: Text(
                          user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                          style: TextStyle(fontSize: 40, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(user.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(user.email, style: const TextStyle(color: Colors.grey, fontSize: 16)),
                      Text(user.phone, style: const TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Balance cards
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Text(
                          balText,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: balColor),
                          textAlign: TextAlign.center,
                        ),
                        const Divider(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text('Total Spent', style: TextStyle(color: Colors.grey)),
                                const SizedBox(height: 8),
                                Text(
                                  '₹${totalSpent.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Container(width: 1, height: 40, color: Colors.grey[300]),
                            Column(
                              children: [
                                const Text('Net Balance', style: TextStyle(color: Colors.grey)),
                                const SizedBox(height: 8),
                                Text(
                                  '₹${netBalance.toStringAsFixed(2)}',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: balColor),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Change Password Button
                ElevatedButton.icon(
                  onPressed: () {
                    _showChangePasswordDialog(context, state);
                  },
                  icon: const Icon(Icons.lock_reset),
                  label: const Text('Change Password'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[50],
                    foregroundColor: Colors.teal,
                    shadowColor: Colors.transparent,
                    minimumSize: const Size(double.infinity, 50),
                    side: BorderSide(color: Colors.teal.shade200),
                  ),
                ),
                const SizedBox(height: 16),

                // Logout Button
                ElevatedButton.icon(
                  onPressed: () {
                    state.logout();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Log Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    foregroundColor: Colors.red,
                    shadowColor: Colors.transparent,
                    minimumSize: const Size(double.infinity, 50),
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
