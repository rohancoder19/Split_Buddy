import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/app_state.dart';
import '../models/user.dart';

class BalanceSheetScreen extends StatelessWidget {
  final String groupId;

  const BalanceSheetScreen({super.key, required this.groupId});

  // Calculate settlement path using greedy algorithm
  List<String> _calculateSettlements(Map<String, double> balances, List<User> groupMembers) {
    List<String> settlements = [];
    
    // Split debtors and creditors
    List<MapEntry<String, double>> debtors = [];
    List<MapEntry<String, double>> creditors = [];

    balances.forEach((userId, balance) {
      if (balance < -0.01) {
        debtors.add(MapEntry(userId, balance));
      } else if (balance > 0.01) {
        creditors.add(MapEntry(userId, balance));
      }
    });

    // Greedy matching
    int i = 0; // debtors index
    int j = 0; // creditors index

    while (i < debtors.length && j < creditors.length) {
      double debt = -debtors[i].value;
      double credit = creditors[j].value;

      double amountToSettle = debt < credit ? debt : credit;
      
      String debtorName = groupMembers.firstWhere((u) => u.id == debtors[i].key, orElse: () => User(id: '', name: 'Unknown', email: '', phone: '', password: '', friendIds: [])).name;
      String creditorName = groupMembers.firstWhere((u) => u.id == creditors[j].key, orElse: () => User(id: '', name: 'Unknown', email: '', phone: '', password: '', friendIds: [])).name;

      settlements.add('$debtorName owes $creditorName Rs.${amountToSettle.toStringAsFixed(2)}');

      debtors[i] = MapEntry(debtors[i].key, debtors[i].value + amountToSettle);
      creditors[j] = MapEntry(creditors[j].key, creditors[j].value - amountToSettle);

      if (-debtors[i].value < 0.01) {
        i++;
      }
      if (creditors[j].value < 0.01) {
        j++;
      }
    }

    if (settlements.isEmpty) {
      settlements.add('All debts are settled! No payments required.');
    }

    return settlements;
  }

  Future<void> _generateAndDownloadPDF(BuildContext context, String groupName, Map<String, double> balances, List<User> groupMembers) async {
    final pdf = pw.Document();
    
    final settlements = _calculateSettlements(balances, groupMembers);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Text('Split-Buddy Group Balance Sheet - $groupName', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(height: 10),
                pw.Text('Date generated: ${DateTime.now().toLocal().toString().split('.')[0]}'),
                pw.SizedBox(height: 20),
                
                pw.Text('Net Balances', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                
                // Balances Table
                pw.TableHelper.fromTextArray(
                  headers: ['Group Member', 'Net Balance'],
                  data: groupMembers.map((u) {
                    final bal = balances[u.id] ?? 0.0;
                    String balStr = bal == 0 ? 'Settled' : bal > 0 ? '+Rs.${bal.toStringAsFixed(2)}' : '-Rs.${(-bal).toStringAsFixed(2)}';
                    return [u.name, balStr];
                  }).toList(),
                ),
                
                pw.SizedBox(height: 30),
                pw.Text('Recommended Settlements', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                
                // Settlements
                ...settlements.map((s) => pw.Bullet(text: s)),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Balance_Sheet_${groupName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        final group = state.myGroups.firstWhere((g) => g.id == groupId);
        final groupMembers = state.getGroupMembers(groupId);
        final balances = state.getGroupBalances(groupId);
        final settlements = _calculateSettlements(balances, groupMembers);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Detailed Balance Sheet'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      const Text(
                        'Net Balance Summary',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Table(
                        border: TableBorder.all(color: Colors.grey[300]!),
                        columnWidths: const {
                          0: FlexColumnWidth(2),
                          1: FlexColumnWidth(1),
                        },
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: Colors.grey[200]),
                            children: const [
                              Padding(padding: EdgeInsets.all(8.0), child: Text('Member', style: TextStyle(fontWeight: FontWeight.bold))),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('Net Balance', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                          ),
                          ...groupMembers.map((u) {
                            final bal = balances[u.id] ?? 0.0;
                            Color valColor = Colors.grey;
                            String balText = 'Settled';
                            
                            if (bal > 0.01) {
                              valColor = Theme.of(context).primaryColor;
                              balText = '+₹${bal.toStringAsFixed(2)}';
                            } else if (bal < -0.01) {
                              valColor = Theme.of(context).colorScheme.secondary;
                              balText = '-₹${(-bal).toStringAsFixed(2)}';
                            }

                            return TableRow(
                              children: [
                                Padding(padding: const EdgeInsets.all(8.0), child: Text(u.name)),
                                Padding(padding: const EdgeInsets.all(8.0), child: Text(balText, style: TextStyle(color: valColor, fontWeight: FontWeight.bold))),
                              ],
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Debt Settlement Plan',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ...settlements.map((s) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            const Icon(Icons.arrow_right_alt, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(child: Text(s, style: const TextStyle(fontSize: 16))),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _generateAndDownloadPDF(context, group.name, balances, groupMembers),
                  icon: const Icon(Icons.download),
                  label: const Text('Download PDF Balance Sheet'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
