import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app/constants.dart';

/// Secure Storage Service
/// Handles secure storage of sensitive wallet data
class StorageService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_PKCS1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    wOptions: WindowsOptions(),
    lOptions: LinuxOptions(),
  );

  /// Save wallet secret key securely
  static Future<void> saveSecretKey(String secretKey) async {
    await _secureStorage.write(key: AppConstants.keyWalletSecretKey, value: secretKey);
  }

  /// Get wallet secret key
  static Future<String?> getSecretKey() async {
    return await _secureStorage.read(key: AppConstants.keyWalletSecretKey);
  }

  /// Save wallet public key
  static Future<void> savePublicKey(String publicKey) async {
    await _secureStorage.write(key: AppConstants.keyWalletPublicKey, value: publicKey);
  }

  /// Get wallet public key
  static Future<String?> getPublicKey() async {
    return await _secureStorage.read(key: AppConstants.keyWalletPublicKey);
  }

  /// Save wallet mnemonic securely
  static Future<void> saveMnemonic(String mnemonic) async {
    await _secureStorage.write(key: AppConstants.keyWalletMnemonic, value: mnemonic);
  }

  /// Get wallet mnemonic
  static Future<String?> getMnemonic() async {
    return await _secureStorage.read(key: AppConstants.keyWalletMnemonic);
  }

  /// Check if wallet exists
  static Future<bool> hasWallet() async {
    final publicKey = await getPublicKey();
    final secretKey = await getSecretKey();
    return publicKey != null && secretKey != null;
  }

  /// Clear all wallet data
  static Future<void> clearWalletData() async {
    await _secureStorage.delete(key: AppConstants.keyWalletSecretKey);
    await _secureStorage.delete(key: AppConstants.keyWalletPublicKey);
    await _secureStorage.delete(key: AppConstants.keyWalletMnemonic);
  }

  /// Clear all secure storage
  static Future<void> clearAll() async {
    await _secureStorage.deleteAll();
  }

  // Preferences Storage (Non-sensitive data)
  
  /// Save first launch status
  static Future<void> saveFirstLaunchStatus(bool isFirstLaunch) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyIsFirstLaunch, isFirstLaunch);
  }

  /// Get first launch status
  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.keyIsFirstLaunch) ?? true;
  }

  /// Save selected network
  static Future<void> saveSelectedNetwork(String network) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keySelectedNetwork, network);
  }

  /// Get selected network
  static Future<String> getSelectedNetwork() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.keySelectedNetwork) ?? AppConstants.defaultNetwork;
  }

  /// Save theme mode
  static Future<void> saveThemeMode(String themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyThemeMode, themeMode);
  }

  /// Get theme mode
  static Future<String> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.keyThemeMode) ?? 'dark';
  }

  /// Save biometric setting
  static Future<void> saveBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyBiometricEnabled, enabled);
  }

  /// Get biometric setting
  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.keyBiometricEnabled) ?? AppConstants.defaultBiometric;
  }

  /// Clear all preferences
  static Future<void> clearPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}