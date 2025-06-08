import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/custom_bottom_nav.dart';
import 'UserChatScreen.dart';

class GroupScreen extends StatefulWidget {
  @override
  _GroupScreenState createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  List<Map<String, dynamic>> groups = [];

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  // Load groups from SharedPreferences
  Future<void> _loadGroups() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? storedGroups = prefs.getString('groups_list');

    if (storedGroups != null) {
      setState(() {
        groups = List<Map<String, dynamic>>.from(json.decode(storedGroups));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Groups")),
      body:
          groups.isEmpty
              ? Center(child: Text("No groups created yet."))
              : ListView.builder(
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final group = groups[index];
                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: ListTile(
                      title: Text(
                        group["groupName"],
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text("Members: ${group["members"].join(", ")}"),
                      onTap: () {
                        try {
                          final String groupName =
                              group["groupName"]?.toString() ??
                              "Unnamed Group"; // Ensure String
                          final List<String> members =
                              (group["members"] as List)
                                  .map(
                                    (e) => e.toString(),
                                  ) // Ensure every item is a String
                                  .toList();

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => UserChatScreen(
                                    groupName: groupName,
                                    members: members,
                                  ),
                            ),
                          );
                        } catch (e) {
                          print("Error in navigation: $e"); // Debugging line
                        }
                      },
                    ),
                  );
                },
              ),

      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 4),
    );
  }
}
