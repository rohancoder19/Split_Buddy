import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/user.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        final expenses = state.expenses;
        final members = state.users;

        // Filter by month/year
        final filteredExpenses = expenses.where((exp) => 
          exp.date.year == _selectedYear && exp.date.month == _selectedMonth
        ).toList();

        double totalMonthlySpend = 0.0;
        Map<String, double> memberMonthlySpend = {for (var m in members) m.id: 0.0};

        for (var exp in filteredExpenses) {
          totalMonthlySpend += exp.amount;
          if (exp.involvedUserIds.isNotEmpty) {
            double split = exp.amount / exp.involvedUserIds.length;
            for (var uid in exp.involvedUserIds) {
              memberMonthlySpend[uid] = (memberMonthlySpend[uid] ?? 0.0) + split;
            }
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  DropdownButton<int>(
                    value: _selectedMonth,
                    items: List.generate(12, (index) => DropdownMenuItem(value: index + 1, child: Text('Month ${index + 1}'))),
                    onChanged: (val) => setState(() => _selectedMonth = val!),
                  ),
                  DropdownButton<int>(
                    value: _selectedYear,
                    items: List.generate(10, (index) => DropdownMenuItem(value: DateTime.now().year - index, child: Text('${DateTime.now().year - index}'))),
                    onChanged: (val) => setState(() => _selectedYear = val!),
                  ),
                ],
              ),
            ),
            Container(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Text('Total Spent This Month', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text('₹${totalMonthlySpend.toStringAsFixed(2)}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Individual Spending', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: members.isEmpty
                  ? const Center(child: Text('No members.'))
                  : ListView.builder(
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        final member = members[index];
                        final spent = memberMonthlySpend[member.id] ?? 0.0;
                        return ListTile(
                          leading: CircleAvatar(child: Text(member.name.isNotEmpty ? member.name[0].toUpperCase() : '?')),
                          title: Text(member.name),
                          trailing: Text('₹${spent.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        );
                      },
                    ),
            ),
          ],
        );
      }
    );
  }
}
