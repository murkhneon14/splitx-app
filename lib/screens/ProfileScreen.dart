import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/custom_bottom_nav.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? userName;
  String? _upiId; // UPI ID variable

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _loadUpiId();
  }

  // Load username from SharedPreferences
  Future<void> _loadUsername() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString("username") ?? "Guest";
    });
  }

  // Load UPI ID from SharedPreferences
  Future<void> _loadUpiId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _upiId = prefs.getString("upi_id") ?? "Enter your UPI ID";
    });
  }

  // Save UPI ID to SharedPreferences
  Future<void> _saveUpiId(String upiId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString("upi_id", upiId);
    setState(() {
      _upiId = upiId;
    });
  }

  // Show dialog to enter UPI ID
  Future<void> _showUpiDialog() async {
    TextEditingController upiController = TextEditingController(text: _upiId);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Enter UPI ID"),
          content: TextField(
            controller: upiController,
            decoration: const InputDecoration(hintText: "Enter your UPI ID"),
            keyboardType: TextInputType.text,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                _saveUpiId(upiController.text);
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  // Logout function
  Future<void> _logout() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(child: CircularProgressIndicator());
        },
      );

      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();

      // Clear all stored data
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully logged out'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to login screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false, // This removes all previous routes
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during logout: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF3E0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Your Profile",
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 40),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.black12,
                        child: Icon(
                          Icons.person,
                          size: 50,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Text(
                        userName ?? "Loading...",
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.qr_code, size: 40, color: Colors.black54),
                ],
              ),

              const SizedBox(height: 40),

              // UPI ID Entry Section
              ListTile(
                leading: const Icon(Icons.payment, color: Colors.blue),
                title: Text(_upiId ?? "Enter your UPI ID"),
                trailing: const Icon(Icons.edit, color: Colors.black),
                onTap: _showUpiDialog,
              ),

              const SizedBox(height: 10),

              // Invite Friends Section
              ListTile(
                leading: const Icon(Icons.card_giftcard, color: Colors.green),
                title: const Text("Invite friends and earn rewards"),
                subtitle: const Text("3 months of Netflix on us!"),
                trailing: TextButton(
                  onPressed: () {
                    Share.share(
                      'Check out SplitX - The easiest way to split bills with friends! Download now: https://splitx-gold.vercel.app/',
                      subject: 'SplitX - Split bills with friends',
                    );
                  },
                  child: const Text("Share"),
                ),
              ),

              const Spacer(),

              Column(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: () {},
                    child: const Text("Delete Account"),
                  ),
                  const SizedBox(height: 10),

                  // Show logout button if user is logged in with Firebase
                  if (FirebaseAuth.instance.currentUser != null)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                      onPressed: () {
                        // Show confirmation dialog before logout
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Logout'),
                              content: const Text(
                                'Are you sure you want to logout?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context); // Close dialog
                                    _logout(); // Proceed with logout
                                  },
                                  child: const Text(
                                    'Logout',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout, size: 20),
                          SizedBox(width: 8),
                          Text("Logout"),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),

      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 4),
    );
  }
}
