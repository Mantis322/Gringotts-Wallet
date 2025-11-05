import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app/constants.dart';
import '../models/wallet_model.dart';

/// Secure Storage Service
/// Handles secure storage of sensitive wallet data with multi-wallet support
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

  // Multi-wallet storage keys
  static const String _multiWalletDataKey = 'multi_wallet_data';
  
  // Legacy storage keys (for backward compatibility)
  static const String _legacySecretKey = AppConstants.keyWalletSecretKey;
  static const String _legacyPublicKey = AppConstants.keyWalletPublicKey;
  static const String _legacyMnemonic = AppConstants.keyWalletMnemonic;

  /// Save multi-wallet data securely
  static Future<void> saveMultiWalletData(MultiWalletModel multiWallet) async {
    final jsonString = jsonEncode(multiWallet.toJson());
    await _secureStorage.write(key: _multiWalletDataKey, value: jsonString);
  }

  /// Get multi-wallet data
  static Future<MultiWalletModel> getMultiWalletData() async {
    final jsonString = await _secureStorage.read(key: _multiWalletDataKey);
    
    if (jsonString != null) {
      try {
        final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
        return MultiWalletModel.fromJson(jsonData);
      } catch (e) {
        // If corrupted, try to migrate legacy data
        return await _migrateLegacyWallet();
      }
    }
    
    // Try to migrate legacy wallet if no multi-wallet data exists
    return await _migrateLegacyWallet();
  }

  /// Migrate legacy single wallet to multi-wallet format
  static Future<MultiWalletModel> _migrateLegacyWallet() async {
    try {
      final secretKey = await _secureStorage.read(key: _legacySecretKey);
      final publicKey = await _secureStorage.read(key: _legacyPublicKey);
      final mnemonic = await _secureStorage.read(key: _legacyMnemonic);
      
      if (publicKey != null && publicKey.isNotEmpty) {
        // Get network preference
        final selectedNetwork = await getSelectedNetwork();
        final isTestnet = selectedNetwork == AppConstants.networkTestnet;
        
        // Create legacy wallet
        final legacyWallet = WalletModel.create(
          name: 'Main Wallet',
          publicKey: publicKey,
          secretKey: secretKey,
          mnemonic: mnemonic,
          isTestnet: isTestnet,
          isActive: true,
        );
        
        final multiWallet = MultiWalletModel.empty().addWallet(legacyWallet);
        
        // Save the migrated data
        await saveMultiWalletData(multiWallet);
        
        // Clear legacy keys
        await _clearLegacyKeys();
        
        return multiWallet;
      }
    } catch (e) {
      // Migration failed, return empty
    }
    
    return MultiWalletModel.empty();
  }

  /// Clear legacy storage keys
  static Future<void> _clearLegacyKeys() async {
    await _secureStorage.delete(key: _legacySecretKey);
    await _secureStorage.delete(key: _legacyPublicKey);
    await _secureStorage.delete(key: _legacyMnemonic);
  }

  /// Add a new wallet to the multi-wallet data
  static Future<void> addWallet(WalletModel wallet) async {
    final multiWallet = await getMultiWalletData();
    final updatedMultiWallet = multiWallet.addWallet(wallet);
    await saveMultiWalletData(updatedMultiWallet);
  }

  /// Remove a wallet from the multi-wallet data
  static Future<void> removeWallet(String walletId) async {
    final multiWallet = await getMultiWalletData();
    final updatedMultiWallet = multiWallet.removeWallet(walletId);
    await saveMultiWalletData(updatedMultiWallet);
  }

  /// Update a wallet in the multi-wallet data
  static Future<void> updateWallet(WalletModel wallet) async {
    final multiWallet = await getMultiWalletData();
    final updatedMultiWallet = multiWallet.updateWallet(wallet);
    await saveMultiWalletData(updatedMultiWallet);
  }

  /// Set active wallet
  static Future<void> setActiveWallet(String walletId) async {
    final multiWallet = await getMultiWalletData();
    final updatedMultiWallet = multiWallet.setActiveWallet(walletId);
    await saveMultiWalletData(updatedMultiWallet);
  }

  /// Get active wallet
  static Future<WalletModel?> getActiveWallet() async {
    final multiWallet = await getMultiWalletData();
    return multiWallet.activeWallet;
  }

  /// Update wallet balance
  static Future<void> updateWalletBalance(String walletId, double balance) async {
    final multiWallet = await getMultiWalletData();
    final updatedMultiWallet = multiWallet.updateWalletBalance(walletId, balance);
    await saveMultiWalletData(updatedMultiWallet);
  }

  // Legacy methods for backward compatibility
  /// Save wallet secret key securely (Legacy - use addWallet instead)
  static Future<void> saveSecretKey(String secretKey) async {
    await _secureStorage.write(key: _legacySecretKey, value: secretKey);
  }

  /// Get wallet secret key (Legacy - use getActiveWallet instead)
  static Future<String?> getSecretKey() async {
    final activeWallet = await getActiveWallet();
    return activeWallet?.secretKey ?? await _secureStorage.read(key: _legacySecretKey);
  }

  /// Save wallet public key (Legacy - use addWallet instead)
  static Future<void> savePublicKey(String publicKey) async {
    await _secureStorage.write(key: _legacyPublicKey, value: publicKey);
  }

  /// Get wallet public key (Legacy - use getActiveWallet instead)
  static Future<String?> getPublicKey() async {
    final activeWallet = await getActiveWallet();
    return activeWallet?.publicKey ?? await _secureStorage.read(key: _legacyPublicKey);
  }

  /// Save wallet mnemonic securely (Legacy - use addWallet instead)
  static Future<void> saveMnemonic(String mnemonic) async {
    await _secureStorage.write(key: _legacyMnemonic, value: mnemonic);
  }

  /// Get wallet mnemonic (Legacy - use getActiveWallet instead)
  static Future<String?> getMnemonic() async {
    final activeWallet = await getActiveWallet();
    return activeWallet?.mnemonic ?? await _secureStorage.read(key: _legacyMnemonic);
  }

  /// Check if any wallet exists
  static Future<bool> hasWallet() async {
    final multiWallet = await getMultiWalletData();
    return multiWallet.hasWallets;
  }

  /// Check if active wallet exists
  static Future<bool> hasActiveWallet() async {
    final multiWallet = await getMultiWalletData();
    return multiWallet.hasActiveWallet;
  }

  /// Clear all wallet data
  static Future<void> clearWalletData() async {
    await _secureStorage.delete(key: _multiWalletDataKey);
    await _clearLegacyKeys();
  }

  /// Clear specific wallet data
  static Future<void> clearWalletById(String walletId) async {
    await removeWallet(walletId);
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