import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/registration_screen.dart';
import 'screens/applicant_dashboard.dart';
import 'screens/admin_dashboard.dart';
import 'screens/office_dashboard.dart';
import 'screens/chat_screen.dart';
import 'services/auth_service.dart';
import 'models/user.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _initialized = false;
  User? _currentUser;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Check if user is logged in
      final user = await _authService.getCurrentUser();
      setState(() {
        _currentUser = user;
        _initialized = true;
      });
    } catch (e) {
      print('Error initializing app: $e');
      setState(() {
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'Visa Mediation App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: _currentUser == null ? '/login' : '/dashboard',
      routes: {
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegistrationScreen(),
        '/dashboard': (context) {
          if (_currentUser?.userType == 'applicant') {
            return ApplicantDashboard(userId: _currentUser!.id);
          } else if (_currentUser?.userType == 'admin') {
            return AdminDashboard();
          } else if (_currentUser?.userType == 'office') {
            return OfficeDashboard(officeId: _currentUser!.id);
          } else {
            return LoginScreen();
          }
        },
      },
      onGenerateRoute: (settings) {
        if (settings.name?.startsWith('/chat/') ?? false) {
          final visaRequestId = settings.name!.split('/')[2];
          return MaterialPageRoute(
            builder: (context) => ChatScreen(visaRequestId: visaRequestId),
          );
        }
        return null;
      },
    );
  }
}