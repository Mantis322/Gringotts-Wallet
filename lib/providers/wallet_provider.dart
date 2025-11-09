import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/wallet_model.dart';
import '../services/stellar_service.dart';
import '../services/storage_service.dart';
import '../services/transaction_service.dart';
import '../services/wallet_registry_service.dart';
import '../app/constants.dart';

/// Multi-Wallet Provider
/// Manages multiple wallets state and operations using Provider pattern
class WalletProvider with ChangeNotifier {
  // Private state variables
  MultiWalletModel _multiWallet = MultiWalletModel.empty();
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  List<TransactionModel> _transactions = [];
  bool _isLoadingTransactions = false;
  String _selectedNetwork = AppConstants.defaultNetwork;
  
  // Getters for multi-wallet
  MultiWalletModel get multiWallet => _multiWallet;
  List<WalletModel> get wallets => _multiWallet.wallets;
  WalletModel? get activeWallet => _multiWallet.activeWallet;
  bool get hasWallets => _multiWallet.hasWallets;
  bool get hasActiveWallet => _multiWallet.hasActiveWallet;
  int get walletCount => _multiWallet.walletCount;
  
  // Getters for current active wallet (backward compatibility)
  WalletModel? get wallet => activeWallet;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  List<TransactionModel> get transactions => _transactions;
  bool get isLoadingTransactions => _isLoadingTransactions;
  String get selectedNetwork => _selectedNetwork;
  
  bool get hasWallet => hasActiveWallet;
  bool get isTestnet => _selectedNetwork == AppConstants.networkTestnet;
  double get balance => activeWallet?.balance ?? 0.0;
  String get publicKey => activeWallet?.publicKey ?? '';
  String get displayBalance => activeWallet?.displayBalance ?? '0.0000000';
  
  /// Initialize wallet provider
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _setLoading(true);
    _setError(null);
    
    try {
      // Load saved network preference
      _selectedNetwork = await StorageService.getSelectedNetwork();
      StellarService.initialize(useTestnet: isTestnet);
      
      // Load multi-wallet data
      _multiWallet = await StorageService.getMultiWalletData();
      
      // If we have wallets, load active wallet data
      if (hasActiveWallet) {
        await _loadActiveWalletData();
      }
      
      _isInitialized = true;
      debugPrint('WalletProvider: Initialized with $walletCount wallets');
      
    } catch (e) {
      _setError('Failed to initialize wallet: ${e.toString()}');
      debugPrint('WalletProvider initialization error: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  /// Load active wallet data (balance and transactions)
  Future<void> _loadActiveWalletData() async {
    if (!hasActiveWallet) return;
    
    try {
      // Load balance
      await refreshBalance();
      
      // Load transactions
      await loadTransactions();
      
    } catch (e) {
      debugPrint('Error loading active wallet data: $e');
    }
  }
  
  /// Create a new wallet
  Future<bool> createWallet({
    String name = 'New Wallet',
    bool setAsActive = true,
  }) async {
    _setLoading(true);
    _setError(null);
    
    try {
      // Generate new wallet using existing StellarService
      final walletModel = await StellarService.createWallet();
      
      // Create wallet model with custom name and ID
      final newWallet = WalletModel.create(
        name: name,
        publicKey: walletModel.publicKey,
        secretKey: walletModel.secretKey,
        mnemonic: walletModel.mnemonic,
        isTestnet: isTestnet,
        isActive: setAsActive,
      ).copyWith(balance: walletModel.balance);
      
      // Add to multi-wallet
      _multiWallet = _multiWallet.addWallet(newWallet);
      
      // Save to storage
      await StorageService.saveMultiWalletData(_multiWallet);
      
      // Set as active if requested
      if (setAsActive) {
        // Just set as active without reloading data since we already have fresh data
        _multiWallet = _multiWallet.setActiveWallet(newWallet.id);
        await StorageService.saveMultiWalletData(_multiWallet);
        notifyListeners();
      }
      
      debugPrint('WalletProvider: Created new wallet: ${newWallet.displayName}');
      return true;
      
    } catch (e) {
      _setError('Failed to create wallet: ${e.toString()}');
      debugPrint('Create wallet error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Import wallet from secret key
  Future<bool> importWalletFromSecretKey({
    required String secretKey,
    String name = 'Imported Wallet',
    bool setAsActive = true,
  }) async {
    _setLoading(true);
    _setError(null);
    
    try {
      // Import from secret key using existing StellarService
      final walletModel = await StellarService.importWallet(secretKey);
      
      // Check if wallet already exists
      if (_multiWallet.containsPublicKey(walletModel.publicKey)) {
        _setError('Wallet already exists');
        return false;
      }
      
      // Create wallet model with custom name and ID
      final importedWallet = WalletModel.create(
        name: name,
        publicKey: walletModel.publicKey,
        secretKey: secretKey,
        mnemonic: null, // No mnemonic when importing from secret key
        isTestnet: isTestnet,
        isActive: setAsActive,
      ).copyWith(balance: walletModel.balance);
      
      // Add to multi-wallet
      _multiWallet = _multiWallet.addWallet(importedWallet);
      
      // Save to storage
      await StorageService.saveMultiWalletData(_multiWallet);
      
      // Set as active if requested
      if (setAsActive) {
        // Just set as active without reloading data since we already have fresh data
        _multiWallet = _multiWallet.setActiveWallet(importedWallet.id);
        await StorageService.saveMultiWalletData(_multiWallet);
        notifyListeners();
      }
      
      debugPrint('WalletProvider: Imported wallet from secret key: ${importedWallet.displayName}');
      return true;
      
    } catch (e) {
      _setError('Failed to import wallet: ${e.toString()}');
      debugPrint('Import from secret key error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Set active wallet
  Future<void> setActiveWallet(String walletId) async {
    try {
      if (!_multiWallet.containsWallet(walletId)) {
        throw Exception('Wallet not found');
      }
      
      // Update multi-wallet with new active wallet
      _multiWallet = _multiWallet.setActiveWallet(walletId);
      
      // Save to storage
      await StorageService.saveMultiWalletData(_multiWallet);
      
      // Load new active wallet data
      await _loadActiveWalletData();
      
      debugPrint('WalletProvider: Set active wallet: $walletId');
      notifyListeners();
      
    } catch (e) {
      _setError('Failed to set active wallet: ${e.toString()}');
      debugPrint('Set active wallet error: $e');
    }
  }
  
  /// Remove wallet
  Future<bool> removeWallet(String walletId) async {
    if (walletCount <= 1) {
      _setError('Cannot remove the last wallet');
      return false;
    }
    
    try {
      // Remove from multi-wallet
      _multiWallet = _multiWallet.removeWallet(walletId);
      
      // Save to storage
      await StorageService.saveMultiWalletData(_multiWallet);
      
      // If active wallet was removed, load new active wallet data
      if (hasActiveWallet) {
        await _loadActiveWalletData();
      }
      
      debugPrint('WalletProvider: Removed wallet: $walletId');
      notifyListeners();
      return true;
      
    } catch (e) {
      _setError('Failed to remove wallet: ${e.toString()}');
      debugPrint('Remove wallet error: $e');
      return false;
    }
  }
  
  /// Update wallet name
  Future<bool> updateWalletName(String walletId, String newName) async {
    try {
      final wallet = _multiWallet.getWalletById(walletId);
      if (wallet == null) {
        throw Exception('Wallet not found');
      }
      
      final updatedWallet = wallet.copyWith(
        name: newName,
        lastUpdated: DateTime.now(),
      );
      
      _multiWallet = _multiWallet.updateWallet(updatedWallet);
      
      // Save to storage
      await StorageService.saveMultiWalletData(_multiWallet);
      
      debugPrint('WalletProvider: Updated wallet name: $walletId -> $newName');
      notifyListeners();
      return true;
      
    } catch (e) {
      _setError('Failed to update wallet name: ${e.toString()}');
      debugPrint('Update wallet name error: $e');
      return false;
    }
  }
  
  /// Refresh balance for active wallet
  Future<void> refreshBalance() async {
    if (!hasActiveWallet) return;
    
    try {
      final balance = await StellarService.getBalance(activeWallet!.publicKey);
      
      // Update wallet with new balance
      final updatedWallet = activeWallet!.copyWith(
        balance: balance,
        lastUpdated: DateTime.now(),
      );
      
      _multiWallet = _multiWallet.updateWallet(updatedWallet);
      
      // Save to storage
      await StorageService.saveMultiWalletData(_multiWallet);
      
      // Also refresh transactions to show the latest ones
      await loadTransactions();
      
      notifyListeners();
      
    } catch (e) {
      debugPrint('Error refreshing balance: $e');
    }
  }
  
  /// Refresh balance for all wallets
  Future<void> refreshAllWalletBalances() async {
    if (!hasWallets) return;
    
    try {
      for (final wallet in wallets) {
        try {
          final balance = await StellarService.getBalance(wallet.publicKey);
          
          final updatedWallet = wallet.copyWith(
            balance: balance,
            lastUpdated: DateTime.now(),
          );
          
          _multiWallet = _multiWallet.updateWallet(updatedWallet);
        } catch (e) {
          debugPrint('Error refreshing balance for wallet ${wallet.id}: $e');
        }
      }
      
      // Save to storage
      await StorageService.saveMultiWalletData(_multiWallet);
      notifyListeners();
      
    } catch (e) {
      debugPrint('Error refreshing all wallet balances: $e');
    }
  }
  
  /// Load transactions for active wallet
  Future<void> loadTransactions() async {
    if (!hasActiveWallet) return;
    
    _isLoadingTransactions = true;
    notifyListeners();
    
    try {
      _transactions = await StellarService.getTransactionHistory(activeWallet!.publicKey);
    } catch (e) {
      debugPrint('Error loading transactions: $e');
      _transactions = [];
    } finally {
      _isLoadingTransactions = false;
      notifyListeners();
    }
  }
  
  /// Send transaction
  Future<bool> sendTransaction({
    required String destinationAddress,
    required double amount,
    String memo = '',
  }) async {
    if (!hasActiveWallet || !activeWallet!.hasSecretKey) {
      _setError('No active wallet or secret key');
      return false;
    }
    
    _setLoading(true);
    _setError(null);
    
    try {
      final result = await TransactionService.sendTransaction(
        secretKey: activeWallet!.secretKey!,
        destinationAddress: destinationAddress,
        amount: amount,
        memo: memo,
      );
      
      if (result.success) {
        // Refresh balance and transactions
        await refreshBalance();
        await loadTransactions();
        return true;
      } else {
        _setError(result.error ?? 'Transaction failed');
        return false;
      }
      
    } catch (e) {
      _setError('Transaction error: ${e.toString()}');
      debugPrint('Send transaction error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Switch network
  Future<void> switchNetwork(String network) async {
    if (_selectedNetwork == network) return;
    
    _setLoading(true);
    
    try {
      _selectedNetwork = network;
      
      // Save network preference
      await StorageService.saveSelectedNetwork(network);
      
      // Reinitialize Stellar service with new network
      StellarService.initialize(useTestnet: isTestnet);
      
      // Clear current wallet data and reload
      _transactions = [];
      
      if (hasActiveWallet) {
        await _loadActiveWalletData();
      }
      
      debugPrint('WalletProvider: Switched to network: $network');
      
    } catch (e) {
      _setError('Failed to switch network: ${e.toString()}');
      debugPrint('Switch network error: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  /// Clear all wallet data
  Future<void> clearAllWallets() async {
    try {
      await StorageService.clearWalletData();
      _multiWallet = MultiWalletModel.empty();
      _transactions = [];
      _isInitialized = false;
      notifyListeners();
      
      debugPrint('WalletProvider: Cleared all wallet data');
      
    } catch (e) {
      _setError('Failed to clear wallet data: ${e.toString()}');
      debugPrint('Clear wallet data error: $e');
    }
  }
  
  /// Clear error
  void clearError() {
    _setError(null);
  }
  
  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }
  
  /// Refresh wallet display names from Firebase registry
  /// This method triggers UI update after wallet names are registered
  Future<void> refreshWalletDisplayNames() async {
    try {
      // Update each wallet's display name from Firebase
      final updatedWallets = <WalletModel>[];
      
      for (final wallet in _multiWallet.wallets) {
        try {
          final registryEntry = await WalletRegistryService.getWalletInfoByPublicKey(
            wallet.publicKey,
          );
          
          final updatedWallet = wallet.copyWith(
            name: registryEntry?.displayName ?? wallet.name,
          );
          updatedWallets.add(updatedWallet);
        } catch (e) {
          // If Firebase fails, keep original wallet
          updatedWallets.add(wallet);
          debugPrint('Error fetching wallet name for ${wallet.publicKey}: $e');
        }
      }
      
      // Update the multi-wallet model with new wallets
      _multiWallet = MultiWalletModel(
        wallets: updatedWallets,
        activeWalletId: _multiWallet.activeWalletId,
      );
      
      // Save updated wallets to storage
      await StorageService.saveMultiWalletData(_multiWallet);
      
      notifyListeners();
      
      debugPrint('WalletProvider: Refreshed wallet display names');
      
    } catch (e) {
      debugPrint('Error refreshing wallet display names: $e');
    }
  }
  
}