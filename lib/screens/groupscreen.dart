import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'UserChatScreen.dart';

class GroupScreen extends StatefulWidget {
  @override
  _GroupScreenState createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Stream<QuerySnapshot> _groupsStream;
  List<Map<String, dynamic>> _friends = [];
  bool _isLoadingFriends = false;

  @override
  void initState() {
    super.initState();
    _loadGroups();
    _loadFriends();
  }

  void _loadGroups() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    _groupsStream = _firestore
        .collection('groups')
        .where('members', arrayContains: currentUser.uid)
        .snapshots();
  }

  Future<void> _loadFriends() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isLoadingFriends = true;
    });

    try {
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        final List<dynamic> friendIds = userData?['friends'] ?? [];
        
        if (friendIds.isNotEmpty) {
          final friendsQuery = await _firestore
              .collection('users')
              .where(FieldPath.documentId, whereIn: friendIds)
              .get();

          _friends = friendsQuery.docs.map((doc) {
            return {
              'id': doc.id,
              'username': doc.data()['username'] ?? 'Unknown',
              'email': doc.data()['email'] ?? '',
            };
          }).toList();
        }
      }
    } catch (e) {
      debugPrint('Error loading friends: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFriends = false;
        });
      }
    }
  }

  Future<void> _showAddPeopleDialog(String groupId, List<dynamic> currentMembers) async {
    if (_isLoadingFriends) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading friends...')),
      );
      return;
    }

    Set<String> selectedFriends = {};
    
    // Filter out friends who are already in the group
    final availableFriends = _friends.where((friend) => 
      !currentMembers.contains(friend['id'])
    ).toList();

    if (availableFriends.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No friends available to add to this group')),
        );
      }
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add People to Group'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Select friends to add to the group:'),
                  const SizedBox(height: 16),
                  ...availableFriends.map((friend) {
                    return CheckboxListTile(
                      title: Text(friend['username'] ?? 'Unknown'),
                      subtitle: Text(friend['email'] ?? ''),
                      value: selectedFriends.contains(friend['id']),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            selectedFriends.add(friend['id']);
                          } else {
                            selectedFriends.remove(friend['id']);
                          }
                        });
                      },
                    );
                  }).toList(),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedFriends.isEmpty
                    ? null
                    : () async {
                        await _addPeopleToGroup(groupId, selectedFriends.toList());
                        if (mounted) {
                          Navigator.pop(context);
                        }
                      },
                child: const Text('Add Selected'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addPeopleToGroup(String groupId, List<String> userIds) async {
    if (userIds.isEmpty) return;

    try {
      final groupRef = _firestore.collection('groups').doc(groupId);
      
      // Get current group data
      final groupDoc = await groupRef.get();
      if (!groupDoc.exists) return;
      
      final groupData = groupDoc.data();
      if (groupData == null) return;

      // Update members list
      final currentMembers = List<String>.from(groupData['members'] ?? []);
      final newMembers = [...currentMembers];
      
      // Add new members if not already in the group
      for (final userId in userIds) {
        if (!newMembers.contains(userId)) {
          newMembers.add(userId);
        }
      }

      // Update memberDetails if it exists
      Map<String, dynamic> updates = {
        'members': newMembers,
      };

      if (groupData['memberDetails'] != null) {
        final memberDetails = List<Map<String, dynamic>>.from(groupData['memberDetails']);
        
        // Get details for new members
        final newMemberDetails = await _getUserDetails(userIds);
        
        // Add only new member details that aren't already in the group
        for (final newMember in newMemberDetails) {
          if (!memberDetails.any((m) => m['id'] == newMember['id'])) {
            memberDetails.add(newMember);
          }
        }
        
        updates['memberDetails'] = memberDetails;
      }

      // Update the group
      await groupRef.update(updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added members to group')),
        );
      }
    } catch (e) {
      debugPrint('Error adding people to group: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add members to group')),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _getUserDetails(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    
    try {
      final usersQuery = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: userIds)
          .get();

      return usersQuery.docs.map((doc) {
        return {
          'id': doc.id,
          'username': doc.data()['username'] ?? 'Unknown',
          'email': doc.data()['email'] ?? '',
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting user details: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFAF3E0),
      body: StreamBuilder<QuerySnapshot>(
        stream: _groupsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading groups'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final groups = snapshot.data?.docs ?? [];

          if (groups.isEmpty) {
            return Center(child: Text("No groups created yet."));
          }

          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index].data() as Map<String, dynamic>;
              final groupId = groups[index].id;
              
              // Get member usernames from memberDetails if available
              List<String> memberNames = [];
              if (group['memberDetails'] != null) {
                memberNames = (group['memberDetails'] as List)
                    .map<String>((m) => m['username']?.toString() ?? 'Unknown')
                    .toList();
              } else if (group['members'] != null) {
                memberNames = (group['members'] as List).map((e) => e.toString()).toList();
              }

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  title: Text(
                    group["name"]?.toString() ?? "Unnamed Group",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("Members: ${memberNames.join(", ")}"),
                  trailing: PopupMenuButton(
                    icon: Icon(Icons.more_vert),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'add_people',
                        child: Row(
                          children: [
                            Icon(Icons.person_add, color: Colors.black87),
                            SizedBox(width: 8),
                            Text('Add People'),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'add_people') {
                        _showAddPeopleDialog(groupId, group['members'] ?? []);
                      }
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserChatScreen(
                          groupId: groupId,
                          groupName: group["name"]?.toString() ?? "Group Chat",
                          members: memberNames,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),

    );
  }
}
