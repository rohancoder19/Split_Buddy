import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/user.dart';
import 'add_expense_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<AppState>(
        builder: (context, state, child) {
          final members = state.users;
          if (members.isEmpty) return const Center(child: Text('No members yet. Go to the Members tab to add some.'));
          
          final balances = state.balances;
          final expenses = state.expenses;
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Group Balances Section
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Group Balances',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...members.map((member) {
                      final bal = balances[member.id] ?? 0.0;
                      Color balColor = Colors.grey;
                      String balText = 'Settled up';
                      
                      if (bal > 0.01) {
                        balColor = Theme.of(context).primaryColor;
                        balText = 'gets back ₹${bal.toStringAsFixed(2)}';
                      } else if (bal < -0.01) {
                        balColor = Theme.of(context).colorScheme.secondary;
                        balText = 'owes ₹${(-bal).toStringAsFixed(2)}';
                      }
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.grey[300],
                              child: Text(member.name.isNotEmpty ? member.name[0].toUpperCase() : '?'),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                member.name,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            Text(
                              balText,
                              style: TextStyle(
                                color: balColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1),
              
              // Expenses List Section
              Expanded(
                child: expenses.isEmpty
                    ? const Center(
                        child: Text(
                          'No expenses yet.\nTap + to add one.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('All Expenses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: expenses.length,
                              itemBuilder: (context, index) {
                                final expense = expenses[expenses.length - 1 - index];
                                
                                // Format payers string
                                List<String> payerNames = [];
                                expense.payers.forEach((pid, amount) {
                                  final payer = state.users.firstWhere((u) => u.id == pid, orElse: () => User(id: '', name: 'Unknown', email: '', phone: '', password: '', friendIds: []));
                                  payerNames.add(payer.name);
                                });
                                String paidByText = payerNames.isEmpty ? 'Unknown' : payerNames.join(', ');

                                return ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.receipt_long, color: Colors.grey),
                                  ),
                                  title: Text(expense.description),
                                  subtitle: Text('$paidByText paid ₹${expense.amount.toStringAsFixed(2)}'),
                                  trailing: Text(
                                    '₹${expense.amount.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
