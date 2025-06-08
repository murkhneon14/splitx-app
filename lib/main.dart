import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'firebase_config.dart';
import 'services/notification_service.dart';

// Global BuildContext for error handling
BuildContext? globalContext;

// Global key for root ScaffoldMessenger
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await FirebaseConfig.initialize();
    debugPrint('Firebase initialized successfully');
    
    // Initialize notification service
    await NotificationService().initialize();
    debugPrint('Notification service initialized');
    
    runApp(const MyApp());
  } catch (e, stackTrace) {
    debugPrint('Error initializing app: $e');
    debugPrint('Stack trace: $stackTrace');
    
    // Show error UI instead of crashing
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 20),
                    Text(
                      'Error Initializing App',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Please check your internet connection and try again.\n\nError details: $e',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        // Try to restart the app
                        main();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Widget _defaultScreen = const Scaffold(body: Center(child: CircularProgressIndicator()));
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (mounted) {
        setState(() {
_defaultScreen = (token != null && token.isNotEmpty)
              ? const HomeScreen()
              : const LoginScreen();
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error checking login status: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() {
_error = 'Error loading app data. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    globalContext = context; // Store context for global access
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      home: _error != null
          ? Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _checkLoginStatus,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : _defaultScreen,
    );
  }
}
