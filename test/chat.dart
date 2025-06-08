import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constant.dart';
import '../widgets/custom_bottom_nav.dart';
import 'groupscreen.dart';
import 'UserChatScreen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> friends = [];
  TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  // Multi-select state
  bool _isSelecting = false;
  Set<String> _selectedFriendIds = {};

  // PageView controller for swipe navigation
  late PageController _pageController;
  int _currentPage = 0;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _friendsSubscription;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    // Initialize the friends list
    _listenToFriends();
  }

  @override
  void dispose() {
    _friendsSubscription?.cancel();
    _pageController.dispose();
    _searchController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _listenToFriends() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Cancel any existing subscription
    _friendsSubscription?.cancel();

    // Set up a real-time listener for the current user's document
    _friendsSubscription = _firestore
        .collection('users')
        .doc(currentUser.uid)
        .snapshots()
        .listen(
          (docSnapshot) async {
            if (!docSnapshot.exists) return;

            final data = docSnapshot.data();
            if (data == null) return;

            List<dynamic> friendIds = data['friends'] ?? [];
            if (friendIds.isEmpty) {
              if (mounted) {
                setState(() {
                  friends = [];
                });
              }
              return;
            }

            try {
              // Fetch all friend documents in one query
              final friendsQuery =
                  await _firestore
                      .collection('users')
                      .where(FieldPath.documentId, whereIn: friendIds)
                      .get();

              final updatedFriends =
                  friendsQuery.docs.map((doc) {
                    return {
                      'id': doc.id,
                      'username': doc.data()['username'] ?? 'Unknown',
                      'email': doc.data()['email'] ?? '',
                    };
                  }).toList();

              if (mounted) {
                setState(() {
                  friends = updatedFriends;
                });
              }
            } catch (e) {
              debugPrint('Error fetching friends: $e');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Error loading friends')),
                );
              }
            }
          },
          onError: (error) {
            debugPrint('Friends listener error: $error');
          },
        );
  }

  Future<void> _searchUser(String query) async {
    if (query.isEmpty) return;
    try {
      final result =
          await _firestore
              .collection('users')
              .where('username', isEqualTo: query)
              .get();

      if (result.docs.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("User not found!")));
        return;
      }

      final userDoc = result.docs.first;
      final userId = userDoc.id;
      final username = userDoc['username'] ?? "Unknown";

      final isFriend = friends.any((friend) => friend['id'] == userId);

      _showFriendPopup(username, userId, isFriend);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Search failed: $e")));
    }
  }

  Future<void> _addFriend(String userId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final userDocRef = _firestore.collection('users').doc(currentUser.uid);

      // Add friendId to current user's friends array (if not already added)
      await userDocRef.update({
        'friends': FieldValue.arrayUnion([userId]),
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Friend added successfully!")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to add friend!")));
    }
  }

  void _showFriendPopup(String username, String userId, bool isFriend) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: EdgeInsets.all(20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(radius: 30),
              SizedBox(height: 10),
              Text(
                username,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                "User ID: $userId",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              SizedBox(height: 15),
              if (!isFriend)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  ),
                  onPressed: () {
                    _addFriend(userId);
                    Navigator.pop(context);
                  },
                  child: Text(
                    "Add Friend",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showCreateGroupDialog({String? groupId}) async {
    if (_selectedFriendIds.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one friend')),
        );
      }
      return;
    }

    final groupNameController = TextEditingController();
    final groupName = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Create Group'),
            content: TextField(
              controller: groupNameController,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                hintText: 'Enter group name',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = groupNameController.text.trim();
                  if (name.isNotEmpty) {
                    Navigator.pop(context, name);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a group name'),
                      ),
                    );
                  }
                },
                child: const Text('Create'),
              ),
            ],
          ),
    );

    if (groupName == null || groupName.trim().isEmpty) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      // Get selected friends' data
      final selectedFriends =
          friends.where((f) => _selectedFriendIds.contains(f['id'])).toList();

      // Create members list with user data
      final members =
          selectedFriends
              .map(
                (friend) => {
                  'id': friend['id'],
                  'username': friend['username'] ?? 'Unknown',
                  'email': friend['email'] ?? '',
                },
              )
              .toList();

      // Add current user to members with their actual username
      try {
        final currentUserDoc =
            await _firestore.collection('users').doc(currentUser.uid).get();
        final userData = currentUserDoc.data();
        final currentUsername =
            userData?['username']?.toString() ??
            currentUser.displayName ??
            currentUser.email?.split('@').first ??
            'User';

        members.add({
          'id': currentUser.uid,
          'username': currentUsername,
          'email': currentUser.email ?? '',
        });
      } catch (e) {
        // Fallback if there's an error fetching user data
        members.add({
          'id': currentUser.uid,
          'username':
              currentUser.displayName ??
              currentUser.email?.split('@').first ??
              'User',
          'email': currentUser.email ?? '',
        });
      }

      // Create or update group data
      final groupData = {
        'name': groupName,
        'members': members.map((m) => m['id']).toList(),
        'memberDetails': members,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (groupId == null) {
        // Creating a new group
        groupData['createdBy'] = currentUser.uid;
        groupData['createdAt'] = FieldValue.serverTimestamp();

        // Add to Firestore
        final docRef = await _firestore.collection('groups').add(groupData);

        // Update the group document with its own ID
        await docRef.update({'id': docRef.id});
      } else {
        // Updating existing group
        await _firestore.collection('groups').doc(groupId).update(groupData);
      }

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Group "$groupName" ${groupId == null ? 'created' : 'updated'} successfully!',
            ),
          ),
        );

        // Reset selection state
        setState(() {
          _isSelecting = false;
          _selectedFriendIds.clear();
        });

        // Navigate to Groups tab
        _pageController.animateToPage(
          1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } catch (e) {
      debugPrint('Error in _showCreateGroupDialog: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create/update group')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFAF3E0),
      bottomNavigationBar: CustomBottomNavBar(currentIndex: 1),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40, vertical: 40),
              child: Column(
                children: [
                  // Heading
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Your Circle",
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  // Styled search box with icon
                  Container(
                    margin: EdgeInsets.only(bottom: 24),
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: Colors.black38),
                        SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: "Search Friends or Groups",
                              border: InputBorder.none,
                            ),
                            onSubmitted: (val) => _searchUser(val.trim()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Custom tab bar for Friends/Groups
                  Container(
                    margin: EdgeInsets.only(bottom: 18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap:
                              () => _pageController.animateToPage(
                                0,
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              ),
                          child: Column(
                            children: [
                              Text(
                                'Friends',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      _currentPage == 0
                                          ? Colors.orange
                                          : Colors.black,
                                  fontSize: 18,
                                ),
                              ),
                              SizedBox(height: 2),
                              Container(
                                height: 3,
                                width: 60,
                                color:
                                    _currentPage == 0
                                        ? Colors.orange
                                        : Colors.transparent,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 32),
                        GestureDetector(
                          onTap:
                              () => _pageController.animateToPage(
                                1,
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              ),
                          child: Column(
                            children: [
                              Text(
                                'Groups',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      _currentPage == 1
                                          ? Colors.orange
                                          : Colors.black,
                                  fontSize: 18,
                                ),
                              ),
                              SizedBox(height: 2),
                              Container(
                                height: 3,
                                width: 60,
                                color:
                                    _currentPage == 1
                                        ? Colors.orange
                                        : Colors.transparent,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  // Page 0: Friends List
                  Column(
                    children: [
                      Expanded(
                        child:
                            friends.isEmpty
                                ? Center(
                                  child: Text("No friends added to SplitX"),
                                )
                                : ListView.builder(
                                  itemCount: friends.length,
                                  itemBuilder: (context, index) {
                                    final friend = friends[index];
                                    final isSelected = _selectedFriendIds
                                        .contains(friend['id']);
                                    return GestureDetector(
                                      onLongPress: () {
                                        setState(() {
                                          _isSelecting = true;
                                          _selectedFriendIds.add(friend['id']);
                                        });
                                      },
                                      onTap: () {
                                        if (_isSelecting) {
                                          setState(() {
                                            if (isSelected) {
                                              _selectedFriendIds.remove(
                                                friend['id'],
                                              );
                                              if (_selectedFriendIds.isEmpty)
                                                _isSelecting = false;
                                            } else {
                                              _selectedFriendIds.add(
                                                friend['id'],
                                              );
                                            }
                                          });
                                        } else {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) => UserChatScreen(
                                                    groupId: 'direct_message',
                                                    groupName:
                                                        friend['username'],
                                                    members: [
                                                      friend['id'], // Use user ID instead of username
                                                      FirebaseAuth
                                                              .instance
                                                              .currentUser
                                                              ?.uid ??
                                                          '',
                                                    ],
                                                  ),
                                            ),
                                          );
                                          // Clear the message controller after navigation
                                          if (_messageController
                                              .text
                                              .isNotEmpty) {
                                            _messageController.clear();
                                          }
                                        }
                                      },
                                      child: ListTile(
                                        leading: CircleAvatar(),
                                        title: Text(friend["username"]),
                                        subtitle: Text(
                                          "User ID: ${friend["id"]}",
                                        ),
                                        selected: isSelected,
                                        selectedTileColor: Colors.blue[50],
                                        trailing:
                                            _isSelecting
                                                ? Checkbox(
                                                  value: isSelected,
                                                  onChanged: (checked) {
                                                    setState(() {
                                                      if (checked == true) {
                                                        _selectedFriendIds.add(
                                                          friend['id'],
                                                        );
                                                      } else {
                                                        _selectedFriendIds
                                                            .remove(
                                                              friend['id'],
                                                            );
                                                        if (_selectedFriendIds
                                                            .isEmpty)
                                                          _isSelecting = false;
                                                      }
                                                    });
                                                  },
                                                )
                                                : null,
                                      ),
                                    );
                                  },
                                ),
                      ),
                      if (_isSelecting && _selectedFriendIds.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.group_add),
                            label: Text("Create Group"),
                            onPressed: _showCreateGroupDialog,
                          ),
                        ),
                    ],
                  ),
                  // Page 1: Groups Screen
                  GroupScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
