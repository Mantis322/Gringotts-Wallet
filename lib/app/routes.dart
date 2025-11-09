import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/home_screen.dart';
import '../screens/create_wallet_screen.dart';
import '../screens/send_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/qr_receive_screen.dart';
import '../screens/qr_scanner_screen.dart';
import '../screens/pin_receive_screen.dart';

/// Application Route Management
/// Centralized navigation and route handling
class AppRoutes {
  AppRoutes._();
  
  // Route Names
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String createWallet = '/create-wallet';
  static const String send = '/send';
  static const String settings = '/settings';
  static const String qrReceive = '/qr-receive';
  static const String qrScanner = '/qr-scanner';
  static const String pinReceive = '/pin-receive';
  
  // Generate Routes
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return _createRoute(const SplashScreen());
      
      case onboarding:
        return _createRoute(const OnboardingScreen());
      
      case home:
        return _createRoute(const HomeScreen());
      
      case createWallet:
        return _createRoute(const CreateWalletScreen());
      
      case send:
        return _createRoute(const SendScreen());
      
      case '/settings':
        return _createRoute(const SettingsScreen());
      
      case qrReceive:
        return _createRoute(const QRReceiveScreen());
      
      case qrScanner:
        return _createRoute(const QRScannerScreen());
      
      case pinReceive:
        return _createRoute(const PinReceiveScreen());
      
      default:
        return _createRoute(
          const Scaffold(
            body: Center(
              child: Text(
                'Route not found',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
        );
    }
  }
  
  // Custom Page Route with Animations
  static PageRoute<T> _createRoute<T extends Object?>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Slide transition with fade
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;
        
        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );
        var offsetAnimation = animation.drive(tween);
        
        var fadeAnimation = Tween(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: curve),
        );
        
        return SlideTransition(
          position: offsetAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: child,
          ),
        );
      },
    );
  }
  
  // Navigation Helper Methods
  static Future<void> pushAndClearStack(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.of(context).pushNamedAndRemoveUntil(
      routeName,
      (route) => false,
      arguments: arguments,
    );
  }
  
  static Future<void> pushReplacement(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.of(context).pushReplacementNamed(
      routeName,
      arguments: arguments,
    );
  }
  
  static Future<void> push(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.of(context).pushNamed(
      routeName,
      arguments: arguments,
    );
  }
  
  static void pop(BuildContext context, [Object? result]) {
    Navigator.of(context).pop(result);
  }
  
  static bool canPop(BuildContext context) {
    return Navigator.of(context).canPop();
  }
}