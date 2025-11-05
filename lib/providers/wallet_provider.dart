import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/wallet_model.dart';
import '../services/stellar_service.dart';
import '../services/storage_service.dart';
import '../services/transaction_service.dart';
import '../app/constants.dart';

/// Wallet Provider
/// Manages wallet state and operations using Provider pattern
class WalletProvider with ChangeNotifier {
  // Private state variables
  WalletModel? _wallet;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  List<TransactionModel> _transactions = [];
  bool _isLoadingTransactions = false;
  String _selectedNetwork = AppConstants.defaultNetwork;
  
  // Getters
  WalletModel? get wallet => _wallet;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  List<TransactionModel> get transactions => _transactions;
  bool get isLoadingTransactions => _isLoadingTransactions;
  String get selectedNetwork => _selectedNetwork;
  
  bool get hasWallet => _wallet != null && _wallet!.hasWallet;
  bool get isTestnet => _selectedNetwork == AppConstants.networkTestnet;
  double get balance => _wallet?.balance ?? 0.0;
  String get publicKey => _wallet?.publicKey ?? '';
  String get displayBalance => _wallet?.displayBalance ?? '0.0000000';
  
  /// Initialize wallet provider
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Set loading state without notifying listeners during build
    _isLoading = true;
    _error = null;
    
    try {
      // Load saved network preference
      _selectedNetwork = await StorageService.getSelectedNetwork();
      StellarService.initialize(useTestnet: isTestnet);
      
      // Check if wallet exists
      final hasStoredWallet = await StorageService.hasWallet();
      
      if (hasStoredWallet) {
        await _loadWalletFromStorage();
      }
      
      _isInitialized = true;
    } catch (e) {
      _error = 'Failed to initialize wallet: $e';
    } finally {
      _isLoading = false;
      // Only notify listeners after initialization is complete
      notifyListeners();
    }
  }
  
  /// Create new wallet
  Future<bool> createWallet() async {
    _setLoading(true);
    _clearError();
    
    try {
      // Create wallet via Stellar service
      final newWallet = await StellarService.createWallet();
      
      // Save to secure storage
      await StorageService.savePublicKey(newWallet.publicKey);
      if (newWallet.secretKey != null) {
        await StorageService.saveSecretKey(newWallet.secretKey!);
      }
      if (newWallet.mnemonic != null) {
        await StorageService.saveMnemonic(newWallet.mnemonic!);
      }
      
      // Update state
      _wallet = newWallet;
      notifyListeners();
      
      // Load transaction history
      await loadTransactionHistory();
      
      return true;
    } catch (e) {
      _setError('Failed to create wallet: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Import wallet from secret key
  Future<bool> importWallet(String secretKey) async {
    _setLoading(true);
    _clearError();
    
    try {
      // Validate secret key
      if (!StellarService.isValidSecretKey(secretKey)) {
        throw Exception('Invalid secret key format');
      }
      
      // Import wallet via Stellar service
      final importedWallet = await StellarService.importWallet(secretKey);
      
      // Save to secure storage
      await StorageService.savePublicKey(importedWallet.publicKey);
      await StorageService.saveSecretKey(secretKey);
      
      // Update state
      _wallet = importedWallet;
      notifyListeners();
      
      // Load transaction history
      await loadTransactionHistory();
      
      return true;
    } catch (e) {
      _setError('Failed to import wallet: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Load wallet from storage
  Future<void> _loadWalletFromStorage() async {
    try {
      final publicKey = await StorageService.getPublicKey();
      final secretKey = await StorageService.getSecretKey();
      
      if (publicKey != null) {
        // Get current balance
        final balance = await StellarService.getBalance(publicKey);
        
        _wallet = WalletModel(
          publicKey: publicKey,
          secretKey: secretKey,
          balance: balance,
          isTestnet: isTestnet,
          createdAt: DateTime.now(), // We don't store creation date
          lastUpdated: DateTime.now(),
        );
        
        notifyListeners();
        
        // Load transaction history
        await loadTransactionHistory();
      }
    } catch (e) {
      _setError('Failed to load wallet: $e');
    }
  }
  
  /// Refresh wallet balance
  Future<void> refreshBalance() async {
    if (!hasWallet) return;
    
    try {
      final newBalance = await StellarService.getBalance(_wallet!.publicKey);
      
      _wallet = _wallet!.copyWith(
        balance: newBalance,
        lastUpdated: DateTime.now(),
      );
      
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to refresh balance: $e');
    }
  }
  
  /// Send transaction
  Future<bool> sendTransaction({
    required String destinationAddress,
    required double amount,
    String memo = '',
  }) async {
    if (!hasWallet || _wallet!.secretKey == null) {
      _setError('No wallet available');
      return false;
    }
    
    _setLoading(true);
    _clearError();
    
    try {
      final result = await TransactionService.sendTransaction(
        secretKey: _wallet!.secretKey!,
        destinationAddress: destinationAddress,
        amount: amount,
        memo: memo,
      );
      
      if (result.success) {
        // Refresh balance and transactions
        await refreshBalance();
        await loadTransactionHistory();
        return true;
      } else {
        _setError(result.error ?? 'Transaction failed');
        return false;
      }
    } catch (e) {
      _setError('Failed to send transaction: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Load transaction history
  Future<void> loadTransactionHistory() async {
    if (!hasWallet) return;
    
    _isLoadingTransactions = true;
    notifyListeners();
    
    try {
      final history = await StellarService.getTransactionHistory(_wallet!.publicKey);
      _transactions = history;
    } catch (e) {
      debugPrint('Failed to load transaction history: $e');
    } finally {
      _isLoadingTransactions = false;
      notifyListeners();
    }
  }
  
  /// Switch network
  Future<void> switchNetwork(String network) async {
    if (network == _selectedNetwork) return;
    
    _setLoading(true);
    _clearError();
    
    try {
      _selectedNetwork = network;
      await StorageService.saveSelectedNetwork(network);
      
      // Reinitialize Stellar service with new network
      StellarService.initialize(useTestnet: isTestnet);
      
      // Reload wallet data if exists
      if (hasWallet) {
        await _loadWalletFromStorage();
      }
    } catch (e) {
      _setError('Failed to switch network: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  /// Clear wallet and reset state
  Future<void> clearWallet() async {
    _setLoading(true);
    
    try {
      await StorageService.clearWalletData();
      _wallet = null;
      _transactions = [];
      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Failed to clear wallet: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  /// Validate transaction
  TransactionValidationResult validateTransaction({
    required String destinationAddress,
    required String amount,
    String memo = '',
  }) {
    return TransactionService.validateTransaction(
      destinationAddress: destinationAddress,
      amount: amount,
      currentBalance: balance,
      memo: memo,
    );
  }
  
  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setError(String error) {
    _error = error;
    notifyListeners();
  }
  
  void _clearError() {
    _error = null;
    notifyListeners();
  }
  
  /// Get formatted balance for display
  String getFormattedBalance([int decimals = 7]) {
    return balance.toStringAsFixed(decimals);
  }
  
  /// Check if address is valid
  bool isValidAddress(String address) {
    return StellarService.isValidStellarAddress(address);
  }
  
  /// Check if amount is valid for sending
  bool isValidAmount(String amount) {
    return TransactionService.isValidAmount(amount, balance);
  }
}