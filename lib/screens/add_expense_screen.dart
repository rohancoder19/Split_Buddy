import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/expense.dart';
import '../models/user.dart';
import '../models/group.dart';

class AddExpenseScreen extends StatefulWidget {
  final String? preselectedGroupId;

  const AddExpenseScreen({super.key, this.preselectedGroupId});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _amountController = TextEditingController();

  String? _selectedGroupId;
  String? _selectedFriendId;
  bool _isGroupSplit = true; // True if splitting with group, false if splitting with single friend

  final Map<String, double> _payers = {};
  final Set<String> _selectedInvolvedIds = {};

  @override
  void initState() {
    super.initState();
    _selectedGroupId = widget.preselectedGroupId;
    
    // Default payers and involved users will be configured in didChangeDependencies or postFrame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateInvolvedUsers();
    });
  }

  void _updateInvolvedUsers() {
    final state = Provider.of<AppState>(context, listen: false);
    final myId = state.currentUser?.id;
    if (myId == null) return;

    setState(() {
      _selectedInvolvedIds.clear();
      _selectedInvolvedIds.add(myId);

      if (_isGroupSplit && _selectedGroupId != null) {
        final members = state.getGroupMembers(_selectedGroupId!);
        for (var m in members) {
          _selectedInvolvedIds.add(m.id);
        }
      } else if (!_isGroupSplit && _selectedFriendId != null) {
        _selectedInvolvedIds.add(_selectedFriendId!);
      }

      // Default payer is the current user paying the full amount
      _payers.clear();
      final amt = double.tryParse(_amountController.text) ?? 0.0;
      if (amt > 0) {
        _payers[myId] = amt;
      }
    });
  }

  void _showPayersDialog(List<User> eligibleUsers) {
    showDialog(
      context: context,
      builder: (context) {
        return _MultiPayerDialog(
          members: eligibleUsers,
          initialPayers: _payers,
          totalAmount: double.tryParse(_amountController.text) ?? 0.0,
          onSave: (newPayers) {
            setState(() {
              _payers.clear();
              _payers.addAll(newPayers);
            });
          },
        );
      },
    );
  }

  void _saveExpense() {
    if (_formKey.currentState!.validate()) {
      final state = Provider.of<AppState>(context, listen: false);
      final myId = state.currentUser?.id;
      if (myId == null) return;

      final amount = double.parse(_amountController.text);

      // If payers is empty, default it to current user paying all
      if (_payers.isEmpty) {
        _payers[myId] = amount;
      }

      // Validate payers sum up to total
      double sumPaid = _payers.values.fold(0.0, (a, b) => a + b);
      if ((sumPaid - amount).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Amounts paid (₹$sumPaid) do not equal total amount (₹$amount).')),
        );
        return;
      }

      if (_selectedInvolvedIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one person involved')),
        );
        return;
      }

      final expense = Expense(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        groupId: _isGroupSplit ? _selectedGroupId : null,
        description: _descController.text,
        amount: amount,
        payers: Map.from(_payers),
        involvedUserIds: _selectedInvolvedIds.toList(),
        date: DateTime.now(),
      );

      state.addExpense(expense);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final myId = state.currentUser?.id;
    if (myId == null) return const SizedBox();

    final groups = state.myGroups;
    final friends = state.myFriends;

    // Get eligible users to split/pay based on group or friend selection
    List<User> eligibleUsers = [];
    eligibleUsers.add(state.currentUser!);
    if (_isGroupSplit && _selectedGroupId != null) {
      eligibleUsers = state.getGroupMembers(_selectedGroupId!);
    } else if (!_isGroupSplit && _selectedFriendId != null) {
      final f = friends.firstWhere((u) => u.id == _selectedFriendId);
      eligibleUsers.add(f);
    }

    // Format payers text
    String payersText = 'You pay full amount';
    if (_payers.isNotEmpty) {
      List<String> pNames = [];
      _payers.forEach((id, amt) {
        final name = id == myId ? 'You' : state.getUserName(id);
        pNames.add('$name (₹${amt.toStringAsFixed(2)})');
      });
      payersText = pNames.join(', ');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveExpense,
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Split Type selector
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(value: true, label: Text('Group'), icon: Icon(Icons.group_work)),
                ButtonSegment<bool>(value: false, label: Text('Single Friend'), icon: Icon(Icons.person)),
              ],
              selected: {_isGroupSplit},
              onSelectionChanged: (val) {
                setState(() {
                  _isGroupSplit = val.first;
                  _updateInvolvedUsers();
                });
              },
            ),
            const SizedBox(height: 16),

            // Select Group or Friend dropdown
            if (_isGroupSplit) ...[
              DropdownButtonFormField<String>(
                value: _selectedGroupId,
                decoration: const InputDecoration(labelText: 'Select Group', border: OutlineInputBorder()),
                items: groups.map((g) {
                  return DropdownMenuItem(value: g.id, child: Text(g.name));
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedGroupId = val;
                    _updateInvolvedUsers();
                  });
                },
                validator: (val) => _isGroupSplit && val == null ? 'Please select a group' : null,
              ),
            ] else ...[
              DropdownButtonFormField<String>(
                value: _selectedFriendId,
                decoration: const InputDecoration(labelText: 'Select Friend', border: OutlineInputBorder()),
                items: friends.map((f) {
                  return DropdownMenuItem(value: f.id, child: Text(f.name));
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedFriendId = val;
                    _updateInvolvedUsers();
                  });
                },
                validator: (val) => !_isGroupSplit && val == null ? 'Please select a friend' : null,
              ),
            ],
            const SizedBox(height: 24),

            // Description
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description)),
              validator: (val) => val == null || val.isEmpty ? 'Enter a description' : null,
            ),
            const SizedBox(height: 16),

            // Amount
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Total Amount', prefixIcon: Icon(Icons.currency_rupee)),
              style: const TextStyle(fontSize: 20),
              onChanged: (val) {
                // Keep default payer updated with the full amount
                final amt = double.tryParse(val) ?? 0.0;
                setState(() {
                  _payers.clear();
                  if (amt > 0) {
                    _payers[myId] = amt;
                  }
                });
              },
              validator: (val) {
                if (val == null || val.isEmpty) return 'Enter an amount';
                if (double.tryParse(val) == null || double.parse(val) <= 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 32),

            // Payers Selector
            const Text('Paid By', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                if (double.tryParse(_amountController.text) == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount first.')));
                  return;
                }
                _showPayersDialog(eligibleUsers);
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(payersText, style: const TextStyle(fontSize: 15))),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Splits checklist
            const Text('Split between members', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ...eligibleUsers.map((u) {
              final name = u.id == myId ? 'You' : u.name;
              return CheckboxListTile(
                title: Text(name),
                value: _selectedInvolvedIds.contains(u.id),
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedInvolvedIds.add(u.id);
                    } else {
                      // Don't allow removing everyone
                      if (_selectedInvolvedIds.length > 1) {
                        _selectedInvolvedIds.remove(u.id);
                      }
                    }
                  });
                },
              );
            }),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveExpense,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              child: const Text('Add Expense', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MultiPayerDialog extends StatefulWidget {
  final List<User> members;
  final Map<String, double> initialPayers;
  final double totalAmount;
  final Function(Map<String, double>) onSave;

  const _MultiPayerDialog({
    required this.members,
    required this.initialPayers,
    required this.totalAmount,
    required this.onSave,
  });

  @override
  State<_MultiPayerDialog> createState() => _MultiPayerDialogState();
}

class _MultiPayerDialogState extends State<_MultiPayerDialog> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    for (var member in widget.members) {
      _controllers[member.id] = TextEditingController(
        text: widget.initialPayers.containsKey(member.id) ? widget.initialPayers[member.id]!.toStringAsFixed(2) : '',
      );
    }
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double currentSum = 0.0;
    _controllers.forEach((key, controller) {
      currentSum += double.tryParse(controller.text) ?? 0.0;
    });
    double remaining = widget.totalAmount - currentSum;

    return AlertDialog(
      title: const Text('Multiple Payers'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Total Amount: ₹${widget.totalAmount.toStringAsFixed(2)}'),
            Text(
              'Remaining: ₹${remaining.toStringAsFixed(2)}',
              style: TextStyle(color: remaining == 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.members.length,
                itemBuilder: (context, index) {
                  final member = widget.members[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Expanded(child: Text(member.name)),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: _controllers[member.id],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(prefixText: '₹'),
                            onChanged: (val) => setState(() {}),
                          ),
                        )
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (remaining.abs() > 0.01) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Total amounts must match exactly.')));
              return;
            }
            Map<String, double> result = {};
            _controllers.forEach((id, controller) {
              double val = double.tryParse(controller.text) ?? 0.0;
              if (val > 0) result[id] = val;
            });
            widget.onSave(result);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
