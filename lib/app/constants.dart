/// Application Constants
/// Global constants and configurations for Stellar Wallet
class AppConstants {
  AppConstants._();
  
  // App Information
  static const String appName = 'Gringotts Wallet';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Premium Stellar Blockchain Wallet - Your magical vault for digital treasures';
  
  // Stellar Network Configuration
  static const String stellarTestnetUrl = 'https://horizon-testnet.stellar.org';
  static const String stellarMainnetUrl = 'https://horizon.stellar.org';
  static const String friendbotUrl = 'https://friendbot.stellar.org';
  
  // Storage Keys
  static const String keyWalletSecretKey = 'wallet_secret_key';
  static const String keyWalletPublicKey = 'wallet_public_key';
  static const String keyWalletMnemonic = 'wallet_mnemonic';
  static const String keyIsFirstLaunch = 'is_first_launch';
  static const String keySelectedNetwork = 'selected_network';
  static const String keyBiometricEnabled = 'biometric_enabled';
  
  // Network Types
  static const String networkTestnet = 'testnet';
  static const String networkMainnet = 'mainnet';
  
  // Asset Codes
  static const String xlmAssetCode = 'XLM';
  static const String xlmAssetName = 'Stellar Lumens';
  
  // UI Constants
  static const double defaultPadding = 16.0;
  static const double largePadding = 24.0;
  static const double smallPadding = 8.0;
  static const double defaultRadius = 16.0;
  static const double largeRadius = 24.0;
  static const double smallRadius = 8.0;
  
  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);
  static const Duration splashDuration = Duration(milliseconds: 2000);
  
  // Transaction Limits
  static const double minTransactionAmount = 0.0000001;
  static const double maxTransactionAmount = 922337203685.4775807;
  static const int maxMemoLength = 28;
  
  // Validation Patterns
  static const String stellarAddressPattern = r'^G[A-Z2-7]{55}$';
  static const String stellarSecretPattern = r'^S[A-Z2-7]{55}$';
  
  // Error Messages
  static const String errorNetworkConnection = 'Network connection error';
  static const String errorInvalidAddress = 'Invalid Stellar address';
  static const String errorInsufficientBalance = 'Insufficient balance';
  static const String errorTransactionFailed = 'Transaction failed';
  static const String errorWalletNotFound = 'Wallet not found';
  static const String errorInvalidAmount = 'Invalid amount';
  
  // Success Messages
  static const String successWalletCreated = 'Wallet created successfully';
  static const String successTransactionSent = 'Transaction sent successfully';
  static const String successWalletImported = 'Wallet imported successfully';
  
  // Feature Flags
  static const bool enableBiometrics = true;
  static const bool enableMainnet = true;
  static const bool enableAnalytics = false;
  static const bool enableCrashReporting = false;
  
  // URLs
  static const String stellarExplorerTestnet = 'https://testnet.steexp.com';
  static const String stellarExplorerMainnet = 'https://steexp.com';
  static const String supportUrl = 'https://stellar.org/support';
  static const String termsUrl = 'https://stellar.org/terms';
  static const String privacyUrl = 'https://stellar.org/privacy';
  
  // Decimal Precision
  static const int xlmDecimalPlaces = 7;
  static const int fiatDecimalPlaces = 2;
  
  // Default Values
  static const String defaultMemo = '';
  static const String defaultNetwork = networkTestnet;
  static const bool defaultBiometric = false;
}