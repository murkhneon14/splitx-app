import 'package:flutter/material.dart';
import 'package:splitx/screens/calculation.dart';
import '../widgets/custom_bottom_nav.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class NewExpenseScreen extends StatefulWidget {
  const NewExpenseScreen({super.key});

  @override
  _NewExpenseScreenState createState() => _NewExpenseScreenState();
}

class _NewExpenseScreenState extends State<NewExpenseScreen> {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> friends = [];
  List<Map<String, dynamic>> groups = [];
  late PageController _pageController;

  Set<String> selectedFriends = {}; // Store selected friend IDs
  TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? youEntry; // Store the current user's data

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    _loadData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([_loadFriends(), _loadGroups()]);
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error loading data')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Save friends to local storage
  Future<void> _saveFriendsToLocal(
    List<Map<String, dynamic>> friendsList,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final friendsJson = jsonEncode(friendsList);
      await prefs.setString('cached_friends', friendsJson);
    } catch (e) {
      debugPrint('Error saving friends to local storage: $e');
    }
  }

  // Load friends from local storage
  Future<List<Map<String, dynamic>>?> _loadFriendsFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final friendsJson = prefs.getString('cached_friends');
      if (friendsJson != null) {
        final List<dynamic> decoded = jsonDecode(friendsJson);
        return List<Map<String, dynamic>>.from(decoded);
      }
    } catch (e) {
      debugPrint('Error loading friends from local storage: $e');
    }
    return null;
  }

  // Save groups to local storage
  Future<void> _saveGroupsToLocal(List<Map<String, dynamic>> groupsList) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final groupsJson = jsonEncode(groupsList);
      await prefs.setString('cached_groups', groupsJson);
    } catch (e) {
      debugPrint('Error saving groups to local storage: $e');
    }
  }

  // Load groups from local storage
  Future<List<Map<String, dynamic>>?> _loadGroupsFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final groupsJson = prefs.getString('cached_groups');
      if (groupsJson != null) {
        final List<dynamic> decoded = jsonDecode(groupsJson);
        return List<Map<String, dynamic>>.from(decoded);
      }
    } catch (e) {
      debugPrint('Error loading groups from local storage: $e');
    }
    return null;
  }

  Future<void> _loadFriends() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Try to load from local storage first
    final cachedFriends = await _loadFriendsFromLocal();
    if (cachedFriends != null && cachedFriends.isNotEmpty && mounted) {
      setState(() {
        friends = cachedFriends;
        // Set "youEntry" for the current user
        youEntry = cachedFriends.firstWhere(
          (friend) => friend['isCurrentUser'] == true,
          orElse: () => {},
        );
        // Auto-select current user
        if (youEntry != null && youEntry!['id'] != null) {
          selectedFriends.add(youEntry!['id']);
        }
      });
    }

    try {
      // Get current user's data from Firestore
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data() as Map<String, dynamic>;
      final friendsList = userData['friends'] as List<dynamic>? ?? [];

      // Add current user as "You" at the top
      final currentUserData = {
        'id': currentUser.uid,
        'username': userData['username'] ?? 'You',
        'email': currentUser.email ?? '',
        'isCurrentUser': true,
      };

      // Add friends
      final friendsData = <Map<String, dynamic>>[currentUserData];

      // Fetch friend details
      for (var friendId in friendsList) {
        if (friendId is String) {
          final friendDoc =
              await _firestore.collection('users').doc(friendId).get();
          if (friendDoc.exists) {
            final friendData = friendDoc.data()!;
            friendsData.add({
              'id': friendId,
              'username': friendData['username'] ?? 'Unknown',
              'email': friendData['email'] ?? '',
              'isCurrentUser': false,
            });
          }
        }
      }

      // Save the updated friends list to local storage
      await _saveFriendsToLocal(friendsData);

      if (mounted) {
        setState(() {
          friends = friendsData;
          youEntry = currentUserData;
          selectedFriends.add(currentUser.uid);
        });
      }
    } catch (e) {
      debugPrint('Error loading friends: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to load friends')));
      }
    }
  }

  Future<void> _loadGroups() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Try to load from local storage first
    final cachedGroups = await _loadGroupsFromLocal();
    if (cachedGroups != null && mounted) {
      setState(() {
        groups = cachedGroups;
      });
    }

    try {
      // Get groups where current user is a member
      final groupsSnapshot =
          await _firestore
              .collection('groups')
              .where('members', arrayContains: currentUser.uid)
              .get();

      final List<Map<String, dynamic>> loadedGroups = [];

      for (var doc in groupsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Use memberDetails if available, otherwise fetch member details
        List<Map<String, dynamic>> memberDetails = [];

        if (data['memberDetails'] != null) {
          // Use existing member details if available
          memberDetails = List<Map<String, dynamic>>.from(
            (data['memberDetails'] as List).map(
              (m) => m is Map<String, dynamic> ? m : {},
            ),
          );
        } else {
          // Fallback to fetching member details
          final members = data['members'] as List<dynamic>? ?? [];
          for (var memberId in members) {
            if (memberId is String) {
              final memberDoc =
                  await _firestore.collection('users').doc(memberId).get();
              if (memberDoc.exists) {
                final memberData = memberDoc.data()!;
                memberDetails.add({
                  'id': memberId,
                  'username': memberData['username'] ?? 'Unknown',
                  'email': memberData['email'] ?? '',
                });
              }
            }
          }
        }

        loadedGroups.add({
          'id': doc.id,
          'name': data['name'] ?? 'Unnamed Group',
          'members': memberDetails,
          'createdAt': data['createdAt'],
        });
      }

      // Save to local storage
      await _saveGroupsToLocal(loadedGroups);

      if (mounted) {
        setState(() {
          groups = loadedGroups;
        });
      }
    } catch (e) {
      debugPrint('Error loading groups: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to load groups')));
      }
    }
  }

  Future<void> _createGroup() async {
    if (selectedFriends.isEmpty) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    TextEditingController _groupNameController = TextEditingController();

    // Show dialog to get group name
    String? groupName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Enter Group Name"),
          content: TextField(
            controller: _groupNameController,
            decoration: const InputDecoration(hintText: "Group Name"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (_groupNameController.text.trim().isNotEmpty) {
                  Navigator.pop(context, _groupNameController.text);
                }
              },
              child: const Text("Create"),
            ),
          ],
        );
      },
    );

    if (groupName == null || groupName.trim().isEmpty) return;

    try {
      // Get member details for selected friends
      final memberDetails = <Map<String, dynamic>>[];

      // Add current user as a member
      final currentUserDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      if (currentUserDoc.exists) {
        final userData = currentUserDoc.data()!;
        memberDetails.add({
          'id': currentUser.uid,
          'username': userData['username'] ?? 'You',
          'email': currentUser.email ?? '',
        });
      }

      // Add selected friends
      for (var friendId in selectedFriends) {
        if (friendId != currentUser.uid) {
          // Skip current user if already added
          final friendDoc =
              await _firestore
                  .collection('users')
                  .doc(friendId.toString())
                  .get();
          if (friendDoc.exists) {
            final friendData = friendDoc.data()!;
            memberDetails.add({
              'id': friendId,
              'username': friendData['username'] ?? 'Unknown',
              'email': friendData['email'] ?? '',
            });
          }
        }
      }

      // Create group in Firestore
      await _firestore.collection('groups').add({
        'name': groupName,
        'createdBy': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'members': memberDetails.map((m) => m['id']).toList(),
        'memberDetails': memberDetails,
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Group '$groupName' created successfully!")),
        );

        // Navigate to group screen or refresh groups list
        _loadGroups();
      }
    } catch (e) {
      debugPrint('Error creating group: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to create group')));
      }
    }
  }

  void _toggleFriendSelection(String id) {
    setState(() {
      if (selectedFriends.contains(id)) {
        selectedFriends.remove(id);
      } else {
        selectedFriends.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFAF3E0),
      bottomNavigationBar: CustomBottomNavBar(currentIndex: 2),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 40,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "New Expense",
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: "Search Friends or Groups",
                          prefixIcon: Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    // Horizontal Scrollable Tabs
                    Container(
                      height: 50,
                      width: double.infinity, // Take full width
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: BouncingScrollPhysics(),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(width: 8), // Left padding
                              // Friends Tab
                              Container(
                                margin: EdgeInsets.symmetric(horizontal: 8),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedIndex = 0;
                                    });
                                    _pageController.animateToPage(
                                      0,
                                      duration: Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color:
                                              _selectedIndex == 0
                                                  ? Colors.orange
                                                  : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      "Friends",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight:
                                            _selectedIndex == 0
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                        color:
                                            _selectedIndex == 0
                                                ? Colors.orange
                                                : Colors.black54,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Groups Tab
                              Container(
                                margin: EdgeInsets.symmetric(horizontal: 8),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedIndex = 1;
                                    });
                                    _pageController.animateToPage(
                                      1,
                                      duration: Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color:
                                              _selectedIndex == 1
                                                  ? Colors.orange
                                                  : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      "Groups",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight:
                                            _selectedIndex == 1
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                        color:
                                            _selectedIndex == 1
                                                ? Colors.orange
                                                : Colors.black54,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8), // Right padding
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() => _selectedIndex = index);
                        },
                        physics:
                            AlwaysScrollableScrollPhysics(), // Update this line
                        children: [
                          // Friends Tab
                          ListView(
                            children: [
                              // Add "You" entry at the top
                              ListTile(
                                onTap: () {
                                  _toggleFriendSelection(youEntry!["id"]);
                                },
                                leading: CircleAvatar(
                                  backgroundColor: Colors.orange,
                                  child: Text(
                                    "Y",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text("You"),
                                trailing: Checkbox(
                                  value: selectedFriends.contains(
                                    youEntry!["id"],
                                  ),
                                  onChanged: (value) {
                                    _toggleFriendSelection(youEntry!["id"]);
                                  },
                                ),
                              ),
                              // List other friends
                              ...friends.map((friend) {
                                final isSelected = selectedFriends.contains(
                                  friend["id"],
                                );
                                return ListTile(
                                  onTap: () {
                                    _toggleFriendSelection(friend["id"]);
                                  },
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blue,
                                    child: Text(
                                      (friend['username']?.toUpperCase() ??
                                          "U")[0],
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  title: Text(friend["username"] ?? 'Unknown'),
                                  subtitle: Text("User ID: ${friend["id"]}"),
                                  trailing: Checkbox(
                                    value: isSelected,
                                    onChanged: (value) {
                                      _toggleFriendSelection(friend["id"]);
                                    },
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                          // Groups Tab
                          groups.isNotEmpty
                              ? ListView.builder(
                                itemCount: groups.length,
                                itemBuilder: (context, index) {
                                  final group = groups[index];
                                  return ListTile(
                                    leading: Icon(
                                      Icons.group,
                                      color: Colors.green,
                                    ),
                                    title: Text(
                                      group["name"] ?? 'Unnamed Group',
                                    ),
                                    subtitle: Text(
                                      "Members: ${(group["members"] as List?)?.length ?? 0}",
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => ExpenseSplitScreen(
                                                selectedFriends:
                                                    (group["members"]
                                                            as List<dynamic>?)
                                                        ?.whereType<
                                                          Map<String, dynamic>
                                                        >()
                                                        .toList() ??
                                                    [],
                                              ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              )
                              : Center(
                                child: Text(
                                  "No groups yet",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                    // Continue button
                    if (selectedFriends.length >
                        1) // Show only if at least one friend apart from "You" is selected
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ElevatedButton(
                          onPressed: () {
                            List<Map<String, dynamic>> selectedFriendDetails =
                                friends
                                    .where(
                                      (friend) => selectedFriends.contains(
                                        friend["id"],
                                      ),
                                    ) // Find friends by ID
                                    .toList();
                            // Add "You" explicitly
                            selectedFriendDetails.insert(0, {
                              "id": 0,
                              "username": "You",
                            });

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => ExpenseSplitScreen(
                                      selectedFriends: selectedFriendDetails,
                                    ),
                              ),
                            );
                          },

                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),

                          child: Text(
                            "Continue with these friends",
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ),
                      ),

                    // Create Group button
                    if (selectedFriends.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ElevatedButton(
                          onPressed: () {
                            _createGroup();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            "Create Group",
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
    );
  }
}
