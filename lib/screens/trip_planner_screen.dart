import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' show sin, pi;
import '../providers/app_state.dart';
import '../models/group.dart';
import '../models/user.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

class TripPlannerScreen extends StatefulWidget {
  final String groupId;

  const TripPlannerScreen({super.key, required this.groupId});

  @override
  State<TripPlannerScreen> createState() => _TripPlannerScreenState();
}

class _TripPlannerScreenState extends State<TripPlannerScreen> {
  bool _isGeneratingAI = false;
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showAIGenerationDialog(BuildContext context, AppState state, Group group) {
    final destController = TextEditingController();
    int selectedDays = 3;
    String selectedStyle = 'Sightseeing';

    final styles = ['Sightseeing', 'Adventure', 'Relaxing', 'Foodie', 'Budget'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Color(0xFF5BC5A7)),
                  SizedBox(width: 8),
                  Text('AI Travel Assistant'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Let Gemini generate a custom travel itinerary for your group!',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: destController,
                    decoration: const InputDecoration(
                      labelText: 'Destination (e.g., Paris, Goa, Tokyo)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.place),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: selectedDays,
                          decoration: const InputDecoration(
                            labelText: 'Days',
                            border: OutlineInputBorder(),
                          ),
                          items: List.generate(7, (index) => index + 1).map((days) {
                            return DropdownMenuItem(value: days, child: Text('$days Days'));
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedDays = val!;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedStyle,
                          decoration: const InputDecoration(
                            labelText: 'Style',
                            border: OutlineInputBorder(),
                          ),
                          items: styles.map((style) {
                            return DropdownMenuItem(value: style, child: Text(style));
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedStyle = val!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final destination = destController.text.trim();
                    if (destination.isNotEmpty) {
                      Navigator.pop(context);
                      setState(() {
                        _isGeneratingAI = true;
                      });

                      final success = await state.generateAIItinerary(
                        group.id,
                        destination,
                        selectedStyle,
                        selectedDays,
                      );

                      setState(() {
                        _isGeneratingAI = false;
                      });

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Successfully generated a $selectedDays-day itinerary for $destination!'
                                  : 'Failed to generate itinerary. Please try again.',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Generate'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddActivityDialog(BuildContext context, AppState state, Group group) {
    final titleController = TextEditingController();
    final timeController = TextEditingController(text: '10:00 AM');
    final costController = TextEditingController(text: '0');
    int selectedDay = 1;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Activity'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: selectedDay,
                    decoration: const InputDecoration(labelText: 'Day', border: OutlineInputBorder()),
                    items: List.generate(10, (index) => index + 1).map((day) {
                      return DropdownMenuItem(value: day, child: Text('Day $day'));
                    }).toList(),
                    onChanged: (val) => setDialogState(() => selectedDay = val!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Activity Title', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: timeController,
                          decoration: const InputDecoration(labelText: 'Time (e.g., 2:00 PM)', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: costController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Est. Cost (₹)',
                            border: OutlineInputBorder(),
                            prefixText: '₹',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    final cost = double.tryParse(costController.text) ?? 0.0;
                    if (title.isNotEmpty) {
                      state.addTripActivity(group.id, {
                        'day': selectedDay,
                        'time': timeController.text.trim(),
                        'title': title,
                        'cost': cost,
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddResearchDialog(BuildContext context, AppState state, Group group) {
    final titleController = TextEditingController();
    final linkController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pin Recommendation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Place / Option Title', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: linkController,
                decoration: const InputDecoration(
                  labelText: 'Link / URL (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final title = titleController.text.trim();
                final link = linkController.text.trim();
                if (title.isNotEmpty) {
                  state.addResearchItem(group.id, title, link);
                  Navigator.pop(context);
                }
              },
              child: const Text('Pin'),
            ),
          ],
        );
      },
    );
  }

  void _showAddPackingDialog(BuildContext context, AppState state, Group group) {
    final nameController = TextEditingController();
    final members = state.getGroupMembers(group.id);
    String? selectedMemberId;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Packing Item'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Item Name', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedMemberId,
                    decoration: const InputDecoration(
                      labelText: 'Assign Responsibility (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String>(value: null, child: Text('Unassigned (Shared)')),
                      ...members.map((m) {
                        return DropdownMenuItem(value: m.id, child: Text(m.name));
                      }),
                    ],
                    onChanged: (val) {
                      setDialogState(() {
                        selectedMemberId = val;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isNotEmpty) {
                      state.addPackingItem(group.id, name, selectedMemberId);
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Add'),
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
        final group = state.myGroups.firstWhere((g) => g.id == widget.groupId);

        return DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              title: Text('Trip Planner - ${group.name}'),
              bottom: const TabBar(
                indicatorColor: Colors.white,
                isScrollable: true,
                tabs: [
                  Tab(icon: Icon(Icons.calendar_month), text: 'Itinerary'),
                  Tab(icon: Icon(Icons.push_pin), text: 'Research'),
                  Tab(icon: Icon(Icons.check_box), text: 'Packing'),
                  Tab(icon: Icon(Icons.auto_awesome), text: 'AI Chat'),
                ],
              ),
            ),
            body: _isGeneratingAI
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF5BC5A7)),
                        SizedBox(height: 16),
                        Text(
                          'Gemini AI is generating your travel itinerary...',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text('Curating activities, timing, and budget estimates.', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : TabBarView(
                    children: [
                      // --- ITINERARY TAB ---
                      _buildItineraryTab(context, state, group),

                      // --- RESEARCH TAB ---
                      _buildResearchTab(context, state, group),

                      // --- PACKING TAB ---
                      _buildPackingTab(context, state, group),

                      // --- AI CHAT TAB ---
                      _buildChatTab(context, state, group),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildItineraryTab(BuildContext context, AppState state, Group group) {
    if (group.itinerary.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.flight_takeoff, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'No Trip Plan Yet',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Let our AI travel assistant construct a beautiful day-by-day plan or add items manually.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _showAIGenerationDialog(context, state, group),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate with Gemini AI'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _showAddActivityDialog(context, state, group),
                icon: const Icon(Icons.add),
                label: const Text('Add Activity Manually'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(200, 45),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    double totalEstCost = group.itinerary.fold(0.0, (sum, act) => sum + (act['cost'] as double? ?? 0.0));

    // Group activities by day
    final Map<int, List<Map<String, dynamic>>> groupedByDay = {};
    for (var act in group.itinerary) {
      final day = act['day'] as int? ?? 1;
      groupedByDay.putIfAbsent(day, () => []).add(act);
    }
    final sortedDays = groupedByDay.keys.toList()..sort();

    return Scaffold(
      body: Column(
        children: [
          // Header Actions
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${sortedDays.length} Days Planned',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      'Total Estimated Budget: ₹${totalEstCost.toStringAsFixed(2)}',
                      style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.auto_awesome, color: Color(0xFF5BC5A7)),
                      tooltip: 'Regenerate with AI',
                      onPressed: () => _showAIGenerationDialog(context, state, group),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: 'Clear Plan',
                      onPressed: () {
                        state.clearTripItinerary(group.id);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable Timeline
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedDays.length,
              itemBuilder: (context, index) {
                final day = sortedDays[index];
                final dayActivities = groupedByDay[day]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Day Header card
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      margin: const EdgeInsets.only(top: 8, bottom: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Day $day',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),

                    // Activities Timeline
                    ...dayActivities.map((act) {
                      final cost = act['cost'] as double? ?? 0.0;
                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.only(left: 8, bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[200]!),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.access_time, size: 18, color: Colors.grey),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      act['time'] ?? '10:00 AM',
                                      style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      act['title'] ?? '',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                              if (cost > 0)
                                Text(
                                  '₹${cost.toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddActivityDialog(context, state, group),
        tooltip: 'Add Activity',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildResearchTab(BuildContext context, AppState state, Group group) {
    final items = group.researchItems;
    final totalMembers = group.memberIds.length;

    return Scaffold(
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.push_pin_outlined, size: 80, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Research & Wishlist Board',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pin hotels, flights, restaurants, or sight links here. Members can upvote options to decide collaboratively.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _showAddResearchDialog(context, state, group),
                      icon: const Icon(Icons.add),
                      label: const Text('Pin First Idea'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(200, 45),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final votes = List<String>.from(item['votes'] ?? []);
                final hasVoted = state.currentUser != null && votes.contains(state.currentUser!.id);
                
                // Highly recommended badge if >50% vote it
                final isHighlyRecommended = totalMembers > 1 && votes.length >= (totalMembers / 2);

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item['title'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            if (isHighlyRecommended)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star, color: Colors.amber[800], size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Recommended',
                                      style: TextStyle(color: Colors.amber[900], fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (item['link'] != null && (item['link'] as String).isNotEmpty)
                          InkWell(
                            onTap: () {
                              // In real app use url_launcher, here we just show link dialog
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Open External Link'),
                                  content: Text('Simulated opening: ${item['link']}'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
                                  ],
                                ),
                              );
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.link, color: Theme.of(context).primaryColor, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  item['link'] ?? '',
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    decoration: TextDecoration.underline,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          const Text('No reference link pinned', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${votes.length} votes',
                              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: Icon(
                                hasVoted ? Icons.thumb_up : Icons.thumb_up_outlined,
                                color: hasVoted ? Theme.of(context).primaryColor : Colors.grey,
                              ),
                              onPressed: () {
                                state.voteResearchItem(group.id, item['id']);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddResearchDialog(context, state, group),
        tooltip: 'Pin Idea',
        child: const Icon(Icons.push_pin),
      ),
    );
  }

  Widget _buildPackingTab(BuildContext context, AppState state, Group group) {
    final items = group.packingItems;

    return Scaffold(
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.checklist_rtl, size: 80, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Shared Packing List',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Track who is bringing what for the trip. Add items and assign them to members.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _showAddPackingDialog(context, state, group),
                      icon: const Icon(Icons.add),
                      label: const Text('Add First Packing Item'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(200, 45),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isDone = item['isDone'] as bool? ?? false;
                final assignedId = item['assignedUserId'] as String?;
                final assignedName = assignedId != null ? state.getUserName(assignedId) : 'Unassigned (Shared)';

                return Card(
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[100]!),
                  ),
                  child: CheckboxListTile(
                    value: isDone,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (bool? val) {
                      state.togglePackingItem(group.id, item['id']);
                    },
                    title: Text(
                      item['name'] ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        color: isDone ? Colors.grey : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      'Brought by: $assignedName',
                      style: TextStyle(
                        color: assignedId != null ? Theme.of(context).primaryColor : Colors.grey,
                        fontSize: 13,
                        fontWeight: assignedId != null ? FontWeight.w500 : null,
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPackingDialog(context, state, group),
        tooltip: 'Add Item',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildChatTab(BuildContext context, AppState state, Group group) {
    // If chat messages are empty, pre-populate with the greeting in the state on next frame
    if (group.chatMessages.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        state.clearTripChatHistory(group.id);
      });
    }

    final messages = group.chatMessages;

    // Trigger auto scroll to bottom on updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Chat History
          Expanded(
            child: messages.isEmpty
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF5BC5A7)))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isUser = msg['sender'] == 'user';
                      final isTyping = msg['isTyping'] == true;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Row(
                          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isUser) ...[
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: const Color(0xFF5BC5A7).withOpacity(0.1),
                                child: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF5BC5A7)),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isUser ? const Color(0xFF5BC5A7) : Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
                                    bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                  border: isUser ? null : Border.all(color: Colors.grey[200]!),
                                ),
                                child: isTyping
                                    ? const SizedBox(
                                        width: 40,
                                        height: 20,
                                        child: Center(child: TypingIndicator()),
                                      )
                                    : MarkdownBody(
                                        data: msg['text'] ?? '',
                                        styleSheet: MarkdownStyleSheet(
                                          p: TextStyle(
                                            color: isUser ? Colors.white : Colors.black87,
                                            fontSize: 14.5,
                                            height: 1.4,
                                          ),
                                          a: const TextStyle(
                                            color: Colors.blue,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                        onTapLink: (text, href, title) async {
                                          if (href != null) {
                                            final Uri url = Uri.parse(href);
                                            if (await canLaunchUrl(url)) {
                                              await launchUrl(url, mode: LaunchMode.externalApplication);
                                            }
                                          }
                                        },
                                      ),
                              ),
                            ),
                            if (isUser) const SizedBox(width: 40), // Offset spacing on the left for user
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Horizontal Suggestion Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSuggestionChip(context, state, group, "✈️ Suggest Itinerary"),
                  _buildSuggestionChip(context, state, group, "🏨 Recommend Hotels"),
                  _buildSuggestionChip(context, state, group, "🎒 Packing Checklist"),
                  _buildSuggestionChip(context, state, group, "🧼 Clear Chat", isAction: true),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Input Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20, top: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (val) => _sendChatMessage(state, group),
                    decoration: InputDecoration(
                      hintText: 'Ask AI assistant for trip ideas...',
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF5BC5A7),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: () => _sendChatMessage(state, group),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(BuildContext context, AppState state, Group group, String label, {bool isAction = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: ActionChip(
        backgroundColor: isAction ? Colors.red[50] : Colors.grey[100],
        side: BorderSide(color: isAction ? Colors.red[100]! : Colors.grey[200]!),
        label: Text(
          label,
          style: TextStyle(
            color: isAction ? Colors.red[700] : Colors.black87,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
        onPressed: () {
          if (isAction) {
            state.clearTripChatHistory(group.id);
          } else {
            final query = label.replaceFirst(RegExp(r'[^\w\s]'), '').trim();
            state.sendTripChatMessage(group.id, query);
          }
        },
      ),
    );
  }

  void _sendChatMessage(AppState state, Group group) {
    final text = _chatController.text.trim();
    if (text.isNotEmpty) {
      _chatController.clear();
      state.sendTripChatMessage(group.id, text);
    }
  }
}

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final delay = index * 0.2;
            final double value = (sin((_controller.value * 2 * pi) - delay) + 1.0) / 2.0;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3 + (value * 0.7)),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}
