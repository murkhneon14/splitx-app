import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'HomeScreen.dart' as home;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isNewUser = false;
  final TextEditingController _nameController = TextEditingController();
  String? userName; // Store name
  bool isAuthenticated = false; // Track authentication status

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("auth_token");

    if (token != null) {
      // User is authenticated, navigate to LoginScreen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => home.HomeScreen()),
        );
      });
    }
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove("auth_token");
    await prefs.remove("userId");
    await prefs.remove("username");

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Logged out successfully!")));

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFFF8E1),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              userName != null ? "Welcome, $userName" : "Welcome,",
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            isNewUser && userName == null
                ? TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: "Enter your first name",
                    hintStyle: TextStyle(fontSize: 24, color: Colors.grey),
                    border: InputBorder.none,
                  ),
                  style: TextStyle(fontSize: 24),
                )
                : SizedBox(height: 30),
            SizedBox(height: 20),
            Text(
              "Embark on a journey of seamless financial harmony with your beloved ones. Our app tenderly weaves your expenses into a shared tapestry, simplifying your collective aspirations with elegance and ease.",
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            SizedBox(height: 30),

            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );
              },
              icon: Icon(Icons.power_settings_new),
              label: Text("Login", style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
              ),
            ),

            SizedBox(height: 10),

            OutlinedButton.icon(
              onPressed: () {
                if (!isNewUser) {
                  setState(() {
                    isNewUser = true;
                  });
                } else {
                  String name = _nameController.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Please enter your name first!"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } else {
                    setState(() {
                      userName = name;
                    });
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SignupScreen()),
                    );
                  }
                }
              },
              icon: Icon(Icons.vpn_key),
              label: Text("Signup", style: TextStyle(fontSize: 18)),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                side: BorderSide(color: Colors.black),
              ),
            ),
            SizedBox(height: 20),

            // Show logout button only if user is authenticated
            if (isAuthenticated)
              ElevatedButton.icon(
                onPressed: _logout,
                icon: Icon(Icons.exit_to_app),
                label: Text("Logout", style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
