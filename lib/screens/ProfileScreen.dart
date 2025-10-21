import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoadingUpi = true;

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _loadUpiId();
  }

  // Load username from Firestore, Firebase Auth, or fallback to SharedPreferences
  Future<void> _loadUsername() async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      setState(() {
        userName = "Guest";
      });
      return;
    }

    try {
      // First try to get username from Firestore
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      if (userDoc.exists) {
        final firestoreUsername = userDoc.data()?['username'] as String?;
        if (firestoreUsername != null && firestoreUsername.isNotEmpty) {
          setState(() {
            userName = firestoreUsername;
          });
          // Also save to SharedPreferences for offline access
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString("username", firestoreUsername);
          return;
        }
      }
    } catch (e) {
      debugPrint('Error loading username from Firestore: $e');
    }

    // Fallback to Firebase Auth display name
    if (currentUser.displayName != null &&
        currentUser.displayName!.isNotEmpty) {
      setState(() {
        userName = currentUser.displayName!;
      });
      return;
    }

    // Fallback to SharedPreferences
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString("username");

    setState(() {
      userName = savedName ?? "Guest";
    });
  }

  // Load UPI ID from Firestore (primary) and SharedPreferences (fallback)
  Future<void> _loadUpiId() async {
    setState(() {
      _isLoadingUpi = true;
    });

    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Try to load from Firestore first
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final firestoreUpiId = userDoc.data()?['upiId'] as String?;
          if (firestoreUpiId != null && firestoreUpiId.isNotEmpty) {
            setState(() {
              _upiId = firestoreUpiId;
              _isLoadingUpi = false;
            });
            // Also save to SharedPreferences for offline access
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString("upi_id", firestoreUpiId);
            return;
          }
        }
      }

      // Fallback to SharedPreferences if Firestore doesn't have it
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        _upiId = prefs.getString("upi_id");
        _isLoadingUpi = false;
      });
    } catch (e) {
      debugPrint('Error loading UPI ID: $e');
      // Fallback to SharedPreferences on error
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        _upiId = prefs.getString("upi_id");
        _isLoadingUpi = false;
      });
    }
  }

  // Save UPI ID to both Firestore and SharedPreferences
  Future<void> _saveUpiId(String upiId) async {
    try {
      // Validate UPI ID format (basic validation)
      if (upiId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid UPI ID'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final user = _auth.currentUser;
      if (user != null) {
        // Save to Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'upiId': upiId,
          'upiIdUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Save to SharedPreferences for offline access
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString("upi_id", upiId);

        setState(() {
          _upiId = upiId;
        });

        // Close loading dialog
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('UPI ID saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // If not logged in with Firebase, just save to SharedPreferences
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString("upi_id", upiId);
        setState(() {
          _upiId = upiId;
        });

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('UPI ID saved locally'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving UPI ID: $e');
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save UPI ID: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show dialog to enter UPI ID
  Future<void> _showUpiDialog() async {
    TextEditingController upiController = TextEditingController(
      text: _upiId != null && _upiId!.isNotEmpty ? _upiId : '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Enter UPI ID"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: upiController,
                decoration: const InputDecoration(
                  hintText: "yourname@upi",
                  labelText: "UPI ID",
                  helperText: "e.g., 9876543210@paytm or name@okaxis",
                  prefixIcon: Icon(Icons.payment),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              const Text(
                'This UPI ID will be used for receiving payments when settling expenses.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _saveUpiId(upiController.text.trim());
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
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
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: const Icon(
                    Icons.payment,
                    color: Colors.blue,
                    size: 28,
                  ),
                  title: Text(
                    _isLoadingUpi
                        ? 'Loading...'
                        : (_upiId != null && _upiId!.isNotEmpty)
                        ? _upiId!
                        : 'Enter your UPI ID',
                    style: TextStyle(
                      fontWeight:
                          (_upiId != null && _upiId!.isNotEmpty)
                              ? FontWeight.w600
                              : FontWeight.normal,
                      color:
                          (_upiId != null && _upiId!.isNotEmpty)
                              ? Colors.black87
                              : Colors.grey,
                    ),
                  ),
                  subtitle: const Text(
                    'For receiving payments',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.edit, color: Colors.blue),
                  onTap: _isLoadingUpi ? null : _showUpiDialog,
                ),
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
