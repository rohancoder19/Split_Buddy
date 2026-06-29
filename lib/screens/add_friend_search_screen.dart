import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import '../providers/app_state.dart';
import '../models/user.dart';

class AddFriendSearchScreen extends StatefulWidget {
  const AddFriendSearchScreen({super.key});

  @override
  State<AddFriendSearchScreen> createState() => _AddFriendSearchScreenState();
}

class _AddFriendSearchScreenState extends State<AddFriendSearchScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  List<fc.Contact> _deviceContacts = [];
  bool _permissionDenied = false;
  bool _isLoadingContacts = false;

  // Premium mock contacts list matching the user's screenshot as a fallback!
  final List<Map<String, String>> _mockFallbackContacts = [
    {'name': '+919830147136', 'phone': '+919830147136', 'email': 'contact1@gmail.com'},
    {'name': 'A.k Sir', 'phone': '+919830779645', 'email': 'aksir@gmail.com'},
    {'name': 'AYITRI (NIT)', 'phone': '+919123847015', 'email': 'ayitri@gmail.com'},
    {'name': 'Abhirup Da', 'phone': '+919674043509', 'email': 'abhirup@gmail.com'},
    {'name': 'Abhishek Gupta (NIT)', 'phone': '+918002263894', 'email': 'abhishek@gmail.com'},
    {'name': 'Abirr Sarkar (NIT)', 'phone': '+918768718034', 'email': 'abirr@gmail.com'},
    {'name': 'Adarsh (NIT)', 'phone': '+919835517708', 'email': 'adarsh@gmail.com'},
    {'name': 'Aditya Poddar (NIT)', 'phone': '+917044574355', 'email': 'aditya.p@gmail.com'},
    {'name': 'Aditya Roy', 'phone': '+919674070509', 'email': 'aditya.r@gmail.com'},
    {'name': 'Ajoy Ganguly', 'phone': '+91902804933', 'email': 'ajoy@gmail.com'},
  ];

  @override
  void initState() {
    super.initState();
    _loadDeviceContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceContacts() async {
    setState(() {
      _isLoadingContacts = true;
    });

    try {
      // First, check if permission is already granted, or request it
      final status = await fc.FlutterContacts.permissions.request(fc.PermissionType.read);
      bool permissionGranted = status == fc.PermissionStatus.granted || status == fc.PermissionStatus.limited;
      
      if (permissionGranted) {
        final contacts = await fc.FlutterContacts.getAll(
          properties: {
            fc.ContactProperty.name,
            fc.ContactProperty.phone,
            fc.ContactProperty.email,
            fc.ContactProperty.photoThumbnail,
          },
        );
        setState(() {
          _deviceContacts = contacts;
          _isLoadingContacts = false;
        });
      } else {
        setState(() {
          _permissionDenied = true;
          _isLoadingContacts = false;
        });
      }
    } catch (e) {
      // Fallback if not supported (e.g. running on Web/Chrome)
      setState(() {
        _permissionDenied = true;
        _isLoadingContacts = false;
      });
    }
  }

  Future<void> _addContactAsFriend(String name, String phone, String email) async {
    final state = Provider.of<AppState>(context, listen: false);
    
    // Attempt adding by existing phone or email
    final addedByPhone = await state.addFriendByEmailOrPhone(phone);
    if (addedByPhone) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added $name to friends list!')),
      );
      return;
    }

    final addedByEmail = await state.addFriendByEmailOrPhone(email);
    if (addedByEmail) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added $name to friends list!')),
      );
      return;
    }

    // Register them dynamically in our backend
    await state.registerUser(name, email, phone, 'password');

    // Add them as friend
    final success = await state.addFriendByEmailOrPhone(phone);
    if (!mounted) return;
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

  void _showAddSomeoneNewDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();

    String dialogCountryCode = '+91';
    final Map<String, String> countryLabels = {
      '+91': '🇮🇳 +91',
      '+1': '🇺🇸 +1',
      '+44': '🇬🇧 +44',
      '+971': '🇦🇪 +971',
      '+61': '🇦🇺 +61',
      '+65': '🇸🇬 +65',
      '+81': '🇯🇵 +81',
      '+49': '🇩🇪 +49',
      '+33': '🇫🇷 +33',
    };

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Someone New'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: dialogCountryCode,
                            items: countryLabels.entries.map((entry) {
                              return DropdownMenuItem<String>(
                                value: entry.key,
                                child: Text(entry.value),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() {
                                  dialogCountryCode = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            hintText: '10-digit number',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email (Optional)'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final phoneText = phoneController.text.trim();
                    if (nameController.text.isNotEmpty && phoneText.isNotEmpty) {
                      if (phoneText.length != 10) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Phone number must be exactly 10 digits')),
                        );
                        return;
                      }
                      final fullPhone = '$dialogCountryCode$phoneText';
                      final email = emailController.text.isEmpty 
                          ? '${nameController.text.toLowerCase().replaceAll(' ', '')}@gmail.com' 
                          : emailController.text.trim();
                      
                      _addContactAsFriend(
                        nameController.text.trim(),
                        fullPhone,
                        email,
                      );
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasRealContacts = _deviceContacts.isNotEmpty;

    // Filter logic
    List<Widget> contactListTiles = [];

    if (hasRealContacts) {
      final filtered = _deviceContacts.where((c) {
        final nameMatches = (c.displayName ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
        final phoneMatches = c.phones.any((p) => p.number.contains(_searchQuery));
        return nameMatches || phoneMatches;
      }).toList();

      contactListTiles = filtered.map((c) {
        final phone = c.phones.isNotEmpty ? c.phones.first.number : '';
        final email = c.emails.isNotEmpty ? c.emails.first.address : '${(c.displayName ?? '').toLowerCase().replaceAll(' ', '')}@gmail.com';
        final photoBytes = c.photo?.thumbnail;

        return ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: () => _addContactAsFriend(c.displayName ?? '', phone, email),
          leading: CircleAvatar(
            backgroundColor: Colors.grey[800],
            backgroundImage: photoBytes != null ? MemoryImage(photoBytes) : null,
            child: photoBytes == null ? const Icon(Icons.phone, color: Colors.grey) : null,
          ),
          title: Text(
            c.displayName ?? '',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
          ),
          subtitle: phone.isNotEmpty
              ? Text(phone, style: const TextStyle(color: Colors.grey, fontSize: 14))
              : null,
        );
      }).toList();
    } else {
      // Fallback mock contacts
      final filteredFallback = _mockFallbackContacts.where((c) {
        final nameMatches = c['name']!.toLowerCase().contains(_searchQuery.toLowerCase());
        final phoneMatches = c['phone']!.contains(_searchQuery);
        return nameMatches || phoneMatches;
      }).toList();

      contactListTiles = filteredFallback.map((c) {
        final isJustNumber = c['name'] == c['phone'];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: () => _addContactAsFriend(c['name']!, c['phone']!, c['email']!),
          leading: CircleAvatar(
            backgroundColor: Colors.grey[800],
            child: const Icon(Icons.phone, color: Colors.grey),
          ),
          title: Text(
            c['name']!,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
          ),
          subtitle: isJustNumber
              ? null
              : Text(c['phone']!, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        );
      }).toList();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: const InputDecoration(
            hintText: 'Enter name, email, or phone #',
            hintStyle: TextStyle(color: Colors.grey, fontSize: 18),
            border: InputBorder.none,
          ),
          onChanged: (val) {
            setState(() {
              _searchQuery = val;
            });
          },
        ),
        actions: [
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.white),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                });
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            children: [
              const SizedBox(height: 8),
              
              // Add someone new row
              InkWell(
                onTap: _showAddSomeoneNewDialog,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_add, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Add someone new',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'From your contacts',
                    style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  if (_isLoadingContacts)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
                    )
                  else if (_permissionDenied && !hasRealContacts)
                    TextButton.icon(
                      onPressed: _loadDeviceContacts,
                      icon: const Icon(Icons.refresh, size: 14, color: Color(0xFF1DE9B6)),
                      label: const Text(
                        'Access Contacts',
                        style: TextStyle(color: Color(0xFF1DE9B6), fontSize: 12),
                      ),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                    )
                ],
              ),
              const SizedBox(height: 16),
              
              if (contactListTiles.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32.0),
                  child: Center(
                    child: Text(
                      'No contacts found',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                )
              else
                ...contactListTiles,
              
              const SizedBox(height: 100),
            ],
          ),
          
          // Done floating button at bottom left
          Positioned(
            bottom: 24,
            left: 24,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1DE9B6),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check, color: Colors.black),
                    SizedBox(width: 8),
                    Text(
                      'Done!',
                      style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
