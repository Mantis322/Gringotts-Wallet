import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../screens/pin_unlock_screen.dart';
import '../app/colors.dart';

/// Authentication Guard Widget
/// Wraps the app to require authentication when enabled
class AuthGuard extends StatefulWidget {
  final Widget child;
  
  const AuthGuard({
    super.key,
    required this.child,
  });

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> with WidgetsBindingObserver {
  bool _isAuthenticated = false;
  bool _isLoading = true;
  bool _needsAuthentication = false;
  DateTime? _lastBackgroundTime;
  static const _backgroundTimeout = Duration(minutes: 1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAuthentication();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _lastBackgroundTime = DateTime.now();
        break;
      case AppLifecycleState.resumed:
        _handleAppResume();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _handleAppResume() async {
    if (_lastBackgroundTime == null) return;
    
    final backgroundDuration = DateTime.now().difference(_lastBackgroundTime!);
    
    // If app was in background for more than timeout, require re-authentication
    if (backgroundDuration > _backgroundTimeout) {
      final authRequired = await AuthService.isAuthRequired();
      if (authRequired) {
        setState(() {
          _isAuthenticated = false;
          _needsAuthentication = true;
        });
      }
    }
  }

  Future<void> _checkAuthentication() async {
    try {
      debugPrint('AuthGuard: Starting authentication check...');
      final authRequired = await AuthService.isAuthRequired();
      debugPrint('AuthGuard: Auth required = $authRequired');
      
      if (!authRequired) {
        debugPrint('AuthGuard: No authentication required, allowing access');
        setState(() {
          _isAuthenticated = true;
          _isLoading = false;
          _needsAuthentication = false;
        });
        return;
      }
      
      // Check if we have any authentication methods setup
      final authMethods = await AuthService.getAuthenticationMethods();
      debugPrint('AuthGuard: Auth methods - hasAnyMethod: ${authMethods.hasAnyMethod}, isBiometricReady: ${authMethods.isBiometricReady}');
      
      if (!authMethods.hasAnyMethod) {
        // No auth methods available, allow access
        debugPrint('AuthGuard: No auth methods available, allowing access');
        setState(() {
          _isAuthenticated = true;
          _isLoading = false;
          _needsAuthentication = false;
        });
        return;
      }
      
      // Try automatic authentication only if biometric is available and enabled
      if (authMethods.isBiometricReady) {
        debugPrint('AuthGuard: Attempting automatic biometric authentication...');
        final result = await AuthService.authenticateWithBiometric(
          localizedReason: 'Unlock Gringotts Wallet',
        );
        
        debugPrint('AuthGuard: Biometric authentication result = $result');
        if (result) {
          debugPrint('AuthGuard: Biometric authentication successful, allowing access');
          setState(() {
            _isAuthenticated = true;
            _isLoading = false;
            _needsAuthentication = false;
          });
          return;
        }
      }
      
      // If biometric failed or not available, show PIN unlock
      debugPrint('AuthGuard: Biometric failed or not available, requiring manual authentication');
      setState(() {
        _isAuthenticated = false;
        _isLoading = false;
        _needsAuthentication = true;
      });
      
    } catch (e) {
      // On error, allow access but log the error
      debugPrint('AuthGuard: Authentication check failed: $e');
      setState(() {
        _isAuthenticated = true;
        _isLoading = false;
        _needsAuthentication = false;
      });
    }
  }

  void _onAuthenticationSuccess() {
    debugPrint('AuthGuard: Authentication successful, allowing access');
    setState(() {
      _isAuthenticated = true;
      _needsAuthentication = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: AppColors.background,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.background,
                  AppColors.surface.withAlpha(50),
                ],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.account_balance,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 32),
                  CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Initializing...',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    if (_needsAuthentication && !_isAuthenticated) {
      return MaterialApp(
        home: PinUnlockScreen(
          title: 'Welcome Back',
          subtitle: 'Unlock your Gringotts Wallet',
          onSuccess: _onAuthenticationSuccess,
          canUseBiometric: true,
        ),
      );
    }
    
    return widget.child;
  }
}