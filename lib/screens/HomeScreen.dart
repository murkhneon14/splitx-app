import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/custom_bottom_nav.dart';
import 'ProfileScreen.dart';
import '../constant.dart';
import 'NewExpense.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String userName = "";
  final TextEditingController expenseController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController memberController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    // First try to get from Firebase Auth
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      // Try to get from Firestore
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      if (userDoc.exists) {
        setState(() {
          userName =
              userDoc.data()?['username'] ?? currentUser.displayName ?? 'User';
        });
      } else {
        // Fallback to email prefix if username not found
        setState(() {
          userName = currentUser.email?.split('@').first ?? 'User';
        });
      }
    } else {
      // Fallback to SharedPreferences if not logged in with Firebase
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        userName = prefs.getString('username') ?? 'User';
      });
    }
  }

  // Kept for backward compatibility if needed
  Future<void> fetchUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString("auth_token");

    if (authToken != null) {
      try {
        final response = await http.get(
          Uri.parse("$backendUrl/user"),
          headers: {"token": authToken},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            userName = data['user']['username'] ?? "";
          });
          prefs.setInt("userId", data['user']['id']);
          prefs.setString("username", data['user']['username']);
        }
      } catch (e) {
        debugPrint('Error in fetchUserData: $e');
      }
    } else {
      // If no auth token, try loading from Firebase
      await _loadUserData();
    }
  }

  // Save data to SharedPreferences
  Future<void> saveData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString("expense", expenseController.text);
    await prefs.setString("amount", amountController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFAF3E0),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Hello, ${userName.isNotEmpty ? userName : 'there'}!",
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProfileScreen(),
                            ),
                          );
                        },
                        child: CircleAvatar(
                          backgroundColor: Colors.grey.shade300,
                          radius: 25,
                          child: Icon(
                            Icons.person,
                            color: Colors.black,
                            size: 36,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 46),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 5,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.shopping_basket,
                                    color: Colors.green,
                                    size: 40,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: expenseController,
                                      decoration: InputDecoration(
                                        hintText: "Add a new expense",
                                        border: InputBorder.none,
                                      ),
                                      keyboardType: TextInputType.text,
                                      textInputAction: TextInputAction.next,
                                      onChanged: (value) => saveData(),
                                    ),
                                  ),
                                ],
                              ),
                              Divider(),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: amountController,
                                      decoration: InputDecoration(
                                        hintText: "Amount",
                                        border: InputBorder.none,
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (value) => saveData(),
                                    ),
                                  ),
                                  DropdownButton<String>(
                                    items:
                                        ["INR", "USD", "EUR"]
                                            .map(
                                              (e) => DropdownMenuItem(
                                                value: e,
                                                child: Text(e),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (val) {},
                                    hint: Text("INR"),
                                  ),
                                ],
                              ),
                              Divider(),
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) => NewExpenseScreen(),
                                          ),
                                        );
                                      },
                                      child: AbsorbPointer(
                                        child: TextField(
                                          controller: memberController,
                                          decoration: const InputDecoration(
                                            hintText: "Add members",
                                            border: InputBorder.none,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => NewExpenseScreen(),
                                        ),
                                      );
                                    },
                                    child: const Icon(Icons.send),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: kBottomNavigationBarHeight + 00,
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 20),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade900,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 5,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Alone in this app?",
                      style: TextStyle(color: Colors.white70),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "Bring Your Crew!",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "This app works best when you're dividing expenses with the people who make life awesome.",
                      style: TextStyle(color: Colors.white70),
                    ),
                    SizedBox(height: 10),
                    GestureDetector(
                      onTap: () {
                        Share.share(
                          'Check out SplitX - The easiest way to split bills with friends! Download now: https://splitx-gold.vercel.app/',
                          subject: 'SplitX - Split bills with friends',
                        );
                      },
                      child: Row(
                        children: [
                          Text(
                            "Send Invite",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Icon(Icons.arrow_right_alt, color: Colors.white),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(currentIndex: 0),
    );
  }
}
