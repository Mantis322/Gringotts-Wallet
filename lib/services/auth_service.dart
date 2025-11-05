import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AuthMethod {
  none,
  pin,
  biometric,
}

class AuthenticationResult {
  final bool success;
  final AuthMethod method;
  final String? error;

  AuthenticationResult({
    required this.success,
    required this.method,
    this.error,
  });
}

class AuthenticationMethods {
  final bool biometricAvailable;
  final bool biometricEnabled;
  final bool pinSetup;
  final bool authRequired;

  AuthenticationMethods({
    required this.biometricAvailable,
    required this.biometricEnabled,
    required this.pinSetup,
    required this.authRequired,
  });

  bool get hasAnyMethod => pinSetup || (biometricAvailable && biometricEnabled);
  bool get isBiometricReady => biometricAvailable && biometricEnabled;
}

/// Authentication Service
/// Handles biometric and PIN authentication for app security
class AuthService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );
  static const _pinKey = 'app_pin_hash';
  static const _biometricEnabledKey = 'biometric_enabled';
  static const _authRequiredKey = 'auth_required';
  
  static final LocalAuthentication _localAuth = LocalAuthentication();
  
  /// Check if biometric authentication is available
  static Future<bool> isBiometricAvailable() async {
    try {
      debugPrint('AuthService: Starting biometric availability check...');
      
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      debugPrint('AuthService.isBiometricAvailable: isDeviceSupported = $isDeviceSupported');
      
      if (!isDeviceSupported) {
        debugPrint('AuthService: Device does not support local authentication');
        debugPrint('AuthService: This is normal for Android emulators without fingerprint setup');
        return false;
      }
      
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      debugPrint('AuthService.isBiometricAvailable: canCheckBiometrics = $canCheckBiometrics');
      
      if (!canCheckBiometrics) {
        debugPrint('AuthService: Cannot check biometrics');
        return false;
      }
      
      final List<BiometricType> availableBiometrics = await _localAuth.getAvailableBiometrics();
      debugPrint('AuthService.isBiometricAvailable: availableBiometrics = $availableBiometrics');
      
      final hasAnyBiometric = availableBiometrics.isNotEmpty;
      debugPrint('AuthService.isBiometricAvailable: final result = $hasAnyBiometric');
      
      return hasAnyBiometric;
    } catch (e) {
      debugPrint('Error checking biometric availability: $e');
      return false;
    }
  }
  
  /// Get available biometric types
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      final biometrics = await _localAuth.getAvailableBiometrics();
      debugPrint('AuthService.getAvailableBiometrics: $biometrics');
      return biometrics;
    } catch (e) {
      debugPrint('Error getting available biometrics: $e');
      return [];
    }
  }
  
  /// Check if biometric authentication is enabled
  static Future<bool> isBiometricEnabled() async {
    try {
      final value = await _storage.read(key: _biometricEnabledKey);
      return value == 'true';
    } catch (e) {
      debugPrint('Error checking biometric enabled: $e');
      return false;
    }
  }
  
  /// Enable/disable biometric authentication
  static Future<void> setBiometricEnabled(bool enabled) async {
    try {
      debugPrint('AuthService.setBiometricEnabled: Setting to $enabled');
      
      await _storage.write(key: _biometricEnabledKey, value: enabled.toString());
      debugPrint('AuthService.setBiometricEnabled: $enabled');
      
      // If enabling biometric or if PIN is set, require authentication
      final bool pinSetup = await isPinSetup();
      debugPrint('AuthService.setBiometricEnabled: PIN setup = $pinSetup');
      
      if (enabled || pinSetup) {
        await _storage.write(key: _authRequiredKey, value: 'true');
        debugPrint('AuthService: Authentication now required (biometric: $enabled, pin: $pinSetup)');
      } else {
        await _storage.write(key: _authRequiredKey, value: 'false');
        debugPrint('AuthService: Authentication not required');
      }
    } catch (e) {
      debugPrint('Error setting biometric enabled: $e');
    }
  }
  
  /// Check if authentication is required
  static Future<bool> isAuthRequired() async {
    try {
      final value = await _storage.read(key: _authRequiredKey);
      debugPrint('AuthService.isAuthRequired: value = $value');
      return value == 'true';
    } catch (e) {
      debugPrint('Error checking auth required: $e');
      return false;
    }
  }
  
  /// Set authentication requirement
  static Future<void> setAuthRequired(bool required) async {
    try {
      await _storage.write(key: _authRequiredKey, value: required.toString());
      debugPrint('AuthService.setAuthRequired: set to $required');
    } catch (e) {
      debugPrint('Error setting auth required: $e');
    }
  }

  /// Check if PIN is setup
  static Future<bool> isPinSetup() async {
    try {
      final pinHash = await _storage.read(key: _pinKey);
      final result = pinHash != null && pinHash.isNotEmpty;
      debugPrint('AuthService.isPinSetup: pinHash = ${pinHash != null ? "exists" : "null"}, result = $result');
      return result;
    } catch (e) {
      debugPrint('Error checking PIN setup: $e');
      return false;
    }
  }

  /// Set up PIN
  static Future<void> setupPin(String pin) async {
    try {
      final pinHash = _hashPin(pin);
      await _storage.write(key: _pinKey, value: pinHash);
      debugPrint('AuthService.setupPin: PIN saved successfully');
      
      // Enable authentication requirement when PIN is set
      await _storage.write(key: _authRequiredKey, value: 'true');
      debugPrint('AuthService: Authentication now required (PIN setup)');
    } catch (e) {
      debugPrint('Error setting up PIN: $e');
      throw Exception('Failed to setup PIN');
    }
  }

  /// Verify PIN
  static Future<bool> verifyPin(String pin) async {
    try {
      final storedHash = await _storage.read(key: _pinKey);
      if (storedHash == null) return false;
      
      final pinHash = _hashPin(pin);
      return pinHash == storedHash;
    } catch (e) {
      debugPrint('Error verifying PIN: $e');
      return false;
    }
  }

  /// Change PIN
  static Future<bool> changePin(String oldPin, String newPin) async {
    try {
      // Verify old PIN first
      final isValid = await verifyPin(oldPin);
      if (!isValid) return false;
      
      // Set new PIN
      await setupPin(newPin);
      return true;
    } catch (e) {
      debugPrint('Error changing PIN: $e');
      return false;
    }
  }
  
  /// Authenticate with biometric
  static Future<bool> authenticateWithBiometric({
    String localizedReason = 'Please authenticate to access your wallet',
  }) async {
    try {
      debugPrint('AuthService: Starting biometric authentication...');
      
      final bool isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        debugPrint('AuthService: Biometric not available, cannot authenticate');
        return false;
      }
      
      debugPrint('AuthService: Attempting biometric authentication with reason: $localizedReason');
      
      final bool isAuthenticated = await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      
      debugPrint('AuthService: Biometric authentication result: $isAuthenticated');
      return isAuthenticated;
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
      return false;
    }
  }

  /// Authenticate with any available method
  static Future<AuthenticationResult> authenticate({
    String localizedReason = 'Please authenticate to access your wallet',
    bool allowBiometric = true,
  }) async {
    try {
      // Check if auth is required
      final bool authRequired = await isAuthRequired();
      if (!authRequired) {
        return AuthenticationResult(success: true, method: AuthMethod.none);
      }
      
      // Try biometric first if enabled and allowed
      if (allowBiometric) {
        final bool biometricEnabled = await isBiometricEnabled();
        final bool biometricAvailable = await isBiometricAvailable();
        
        if (biometricEnabled && biometricAvailable) {
          final result = await authenticateWithBiometric(localizedReason: localizedReason);
          if (result) {
            return AuthenticationResult(success: true, method: AuthMethod.biometric);
          }
        }
      }
      
      // If biometric failed or not available, require PIN
      final bool pinSetup = await isPinSetup();
      if (pinSetup) {
        return AuthenticationResult(
          success: false, 
          method: AuthMethod.pin,
          error: 'PIN required',
        );
      }
      
      // No authentication methods available
      return AuthenticationResult(
        success: false,
        method: AuthMethod.none,
        error: 'No authentication methods available',
      );
    } catch (e) {
      return AuthenticationResult(
        success: false,
        method: AuthMethod.none,
        error: e.toString(),
      );
    }
  }

  /// Clear all authentication data
  static Future<void> clearAuthData() async {
    try {
      await _storage.delete(key: _pinKey);
      await _storage.delete(key: _biometricEnabledKey);
      await _storage.delete(key: _authRequiredKey);
      debugPrint('AuthService: All authentication data cleared');
    } catch (e) {
      debugPrint('Error clearing auth data: $e');
    }
  }

  /// Hash PIN for secure storage
  static String _hashPin(String pin) {
    final bytes = utf8.encode(pin + 'gringotts_salt'); // Add salt
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  /// Get authentication methods summary
  static Future<AuthenticationMethods> getAuthenticationMethods() async {
    final biometricAvailable = await isBiometricAvailable();
    final biometricEnabled = await isBiometricEnabled();
    final pinSetup = await isPinSetup();
    final authRequired = await isAuthRequired();
    
    debugPrint('AuthService.getAuthenticationMethods: biometricAvailable=$biometricAvailable, biometricEnabled=$biometricEnabled, pinSetup=$pinSetup, authRequired=$authRequired');
    
    return AuthenticationMethods(
      biometricAvailable: biometricAvailable,
      biometricEnabled: biometricEnabled,
      pinSetup: pinSetup,
      authRequired: authRequired,
    );
  }
}