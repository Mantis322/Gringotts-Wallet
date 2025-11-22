import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import '../models/wallet_model.dart';
import '../app/constants.dart';

/// Stellar Service
/// Handles all Stellar blockchain interactions
class StellarService {
  static StellarSDK? _sdk;
  static NetworkModel? _currentNetwork;

  /// Initialize Stellar SDK
  static void initialize({bool useTestnet = true}) {
    _currentNetwork = useTestnet ? NetworkModel.testnet() : NetworkModel.mainnet();
    _sdk = useTestnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC;
  }

  /// Get current SDK instance
  static StellarSDK get sdk {
    if (_sdk == null) {
      initialize();
    }
    return _sdk!;
  }

  /// Get current network
  static NetworkModel get currentNetwork {
    if (_currentNetwork == null) {
      initialize();
    }
    return _currentNetwork!;
  }

  /// Create a new wallet
  static Future<WalletModel> createWallet() async {
    try {
      // Generate random keypair (no mnemonic needed)
      final keyPair = KeyPair.random();
      
      final wallet = WalletModel.create(
        name: 'New Wallet',
        publicKey: keyPair.accountId,
        secretKey: keyPair.secretSeed,
        mnemonic: null, // No longer using mnemonics
        isTestnet: currentNetwork.isTestnet,
      );

      // Fund account if on testnet
      if (currentNetwork.isTestnet) {
        try {
          await _fundTestnetAccount(keyPair.accountId);
          // Wait a bit for funding to complete
          await Future.delayed(const Duration(seconds: 3));
          
          // Try to get balance with timeout
          try {
            final balance = await getBalance(keyPair.accountId).timeout(
              const Duration(seconds: 10),
            );
            return wallet.copyWith(balance: balance);
          } catch (e) {
            print('Balance check failed, but wallet created: $e');
            // Return wallet with 0 balance if balance check fails
            return wallet.copyWith(balance: 0.0);
          }
        } catch (e) {
          print('Testnet funding failed, but wallet created: $e');
          // Return wallet with 0 balance if funding fails
          return wallet.copyWith(balance: 0.0);
        }
      }

      return wallet;
    } catch (e) {
      throw Exception('Failed to create wallet: $e');
    }
  }

  /// Import wallet from secret key
  static Future<WalletModel> importWallet(String secretKey) async {
    try {
      final keyPair = KeyPair.fromSecretSeed(secretKey);
      final balance = await getBalance(keyPair.accountId);
      
      return WalletModel.create(
        name: 'Imported Wallet',
        publicKey: keyPair.accountId,
        secretKey: secretKey,
        mnemonic: null, // Import edilen cüzdan için mnemonic yok
        isTestnet: currentNetwork.isTestnet,
      ).copyWith(balance: balance);
    } catch (e) {
      throw Exception('Failed to import wallet: $e');
    }
  }

  /// Get account balance
  static Future<double> getBalance(String publicKey) async {
    try {
      final account = await sdk.accounts.account(publicKey).timeout(
        const Duration(seconds: 15),
      );
      
      for (final balance in account.balances) {
        if (balance.assetType == 'native') {
          return double.parse(balance.balance);
        }
      }
      
      return 0.0;
    } catch (e) {
      // Account might not exist yet or network timeout
      if (e.toString().contains('404') || e.toString().contains('not_found')) {
        debugPrint('Account $publicKey not found on network - new account with 0 balance');
        return 0.0;
      }
      
      debugPrint('Balance check failed for $publicKey: $e');
      return 0.0;
    }
  }

  /// Get detailed balance information
  static Future<List<BalanceModel>> getDetailedBalance(String publicKey) async {
    try {
      final account = await sdk.accounts.account(publicKey);
      final balances = <BalanceModel>[];
      
      for (final balance in account.balances) {
        if (balance.assetType == 'native') {
          balances.add(BalanceModel.xlm(double.parse(balance.balance)));
        } else {
          balances.add(BalanceModel(
            assetCode: balance.assetCode ?? '',
            assetIssuer: balance.assetIssuer ?? '',
            balance: double.parse(balance.balance),
            limit: balance.limit != null ? double.parse(balance.limit!) : null,
            isNative: false,
          ));
        }
      }
      
      return balances;
    } catch (e) {
      return [BalanceModel.xlm(0.0)];
    }
  }

  /// Send payment
  static Future<TransactionModel> sendPayment({
    required String secretKey,
    required String destinationAddress,
    required double amount,
    String memo = '',
    String assetCode = 'XLM',
  }) async {
    try {
      final sourceKeyPair = KeyPair.fromSecretSeed(secretKey);
      final sourceAccount = await sdk.accounts.account(sourceKeyPair.accountId);
      
      // Build transaction
      final transactionBuilder = TransactionBuilder(sourceAccount);
      
      // Add payment operation
      Asset asset;
      if (assetCode == 'XLM') {
        asset = AssetTypeNative();
      } else {
        throw Exception('Custom assets not supported yet');
      }
      
      final paymentOperation = PaymentOperationBuilder(
        destinationAddress,
        asset,
        amount.toStringAsFixed(7),
      ).build();
      
      transactionBuilder.addOperation(paymentOperation);
      
      // Add memo if provided
      if (memo.isNotEmpty) {
        transactionBuilder.addMemo(MemoText(memo));
      }
      
      // Build and sign transaction
      final transaction = transactionBuilder.build();
      transaction.sign(sourceKeyPair, Network(currentNetwork.passphrase));
      
      // Submit transaction
      final response = await sdk.submitTransaction(transaction);
      
      if (response.success) {
        return TransactionModel(
          id: _generateTransactionId(),
          hash: response.hash ?? '',
          sourceAccount: sourceKeyPair.accountId,
          destinationAccount: destinationAddress,
          amount: amount,
          assetCode: assetCode,
          memo: memo,
          createdAt: DateTime.now(),
          status: TransactionStatus.success,
          type: TransactionType.sent,
          fee: double.parse(transaction.fee.toString()) / 10000000, // Convert stroops to XLM
        );
      } else {
        // Get detailed error information
        final transactionResultCode = response.extras?.resultCodes?.transactionResultCode;
        final operationResultCodes = response.extras?.resultCodes?.operationsResultCodes;
        
        String errorDetails = 'Transaction failed';
        
        if (transactionResultCode != null) {
          errorDetails += ' - Transaction: $transactionResultCode';
        }
        
        if (operationResultCodes != null && operationResultCodes.isNotEmpty) {
          errorDetails += ' - Operations: ${operationResultCodes.join(', ')}';
        }
        
        // Add specific error explanations
        if (transactionResultCode == 'tx_failed') {
          if (operationResultCodes != null && operationResultCodes.contains('op_underfunded')) {
            errorDetails += ' (Insufficient balance)';
          } else if (operationResultCodes != null && operationResultCodes.contains('op_no_destination')) {
            errorDetails += ' (Destination account does not exist)';
          } else if (operationResultCodes != null && operationResultCodes.contains('op_line_full')) {
            errorDetails += ' (Destination account cannot receive more of this asset)';
          } else if (operationResultCodes != null && operationResultCodes.contains('op_no_trust')) {
            errorDetails += ' (Destination account does not trust this asset)';
          }
        }
        
        throw Exception(errorDetails);
      }
    } catch (e) {
      if (e.toString().contains('Transaction failed')) {
        rethrow; // Re-throw our detailed error
      }
      throw Exception('Failed to send payment: $e');
    }
  }

  /// Check if account exists on the network
  static Future<bool> accountExists(String publicKey) async {
    try {
      await sdk.accounts.account(publicKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Validate Stellar address
  static bool isValidStellarAddress(String address) {
    final regex = RegExp(AppConstants.stellarAddressPattern);
    return regex.hasMatch(address);
  }

  /// Validate Stellar secret key
  static bool isValidSecretKey(String secretKey) {
    try {
      KeyPair.fromSecretSeed(secretKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Fund testnet account (for testing)
  static Future<void> _fundTestnetAccount(String publicKey) async {
    try {
      await FriendBot.fundTestAccount(publicKey);
    } catch (e) {
      // Funding might fail if account already exists
      // We'll ignore this error
    }
  }

  /// Generate unique transaction ID
  static String _generateTransactionId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = random.nextInt(999999);
    return '${timestamp}_$randomPart';
  }

  /// Get comprehensive transaction history from Stellar network
  static Future<List<TransactionModel>> getTransactionHistory(String publicKey) async {
    try {
      // Get all operations for this account (payments, account creation, etc.)
      final operationsResponse = await sdk.operations.forAccount(publicKey).limit(100).execute();
      final List<TransactionModel> allTransactions = [];
      final Map<String, String> transactionMemos = {}; // Cache memos by transaction hash

      for (final operation in operationsResponse.records) {
        try {
          TransactionModel? transaction;
          
          // Get memo for this transaction (cache to avoid repeated calls)
          String memo = '';
          if (!transactionMemos.containsKey(operation.transactionHash)) {
            try {
              final txDetails = await sdk.transactions.transaction(operation.transactionHash);
              String memoText = '';
              
              // Extract memo from transaction details
              if (txDetails.memo != null) {
                final memoObj = txDetails.memo;
                if (memoObj is MemoText) {
                  memoText = memoObj.text ?? '';
                } else if (memoObj is MemoHash) {
                  memoText = 'Hash: ${memoObj.hexValue}';
                } else if (memoObj is MemoId) {
                  memoText = 'ID: ${memoObj.toString()}';
                } else {
                  memoText = memoObj.toString();
                }
              }
              
              transactionMemos[operation.transactionHash] = memoText;
            } catch (e) {
              transactionMemos[operation.transactionHash] = '';
            }
          }
          memo = transactionMemos[operation.transactionHash] ?? '';
          
          if (operation is PaymentOperationResponse) {
            // Handle payment operations
            final isIncoming = operation.to == publicKey;
            transaction = TransactionModel(
              id: operation.id,
              hash: operation.transactionHash,
              sourceAccount: operation.from,
              destinationAccount: operation.to,
              amount: double.parse(operation.amount),
              assetCode: operation.assetType == 'native' ? 'XLM' : (operation.assetCode ?? ''),
              memo: memo,
              createdAt: DateTime.parse(operation.createdAt),
              status: TransactionStatus.success,
              type: isIncoming ? TransactionType.received : TransactionType.sent,
              fee: 0.0001, // Standard fee approximation
            );
          } else if (operation is CreateAccountOperationResponse) {
            // Handle account creation operations
            final isIncoming = operation.account == publicKey;
            if (isIncoming) {
              transaction = TransactionModel(
                id: operation.id,
                hash: operation.transactionHash,
                sourceAccount: operation.funder,
                destinationAccount: operation.account,
                amount: double.parse(operation.startingBalance),
                assetCode: 'XLM',
                memo: memo.isEmpty ? 'Account creation' : memo,
                createdAt: DateTime.parse(operation.createdAt),
                status: TransactionStatus.success,
                type: TransactionType.received,
                fee: 0.0001,
              );
            }
          } else if (operation is PathPaymentStrictReceiveOperationResponse) {
            // Handle path payment operations
            final isIncoming = operation.to == publicKey;
            final isOutgoing = operation.from == publicKey;
            
            if (isIncoming || isOutgoing) {
              transaction = TransactionModel(
                id: operation.id,
                hash: operation.transactionHash,
                sourceAccount: operation.from,
                destinationAccount: operation.to,
                amount: double.parse(isIncoming ? operation.amount : (operation.sourceAmount ?? '0')),
                assetCode: isIncoming 
                  ? (operation.assetType == 'native' ? 'XLM' : (operation.assetCode ?? ''))
                  : (operation.sourceAssetType == 'native' ? 'XLM' : (operation.sourceAssetCode ?? '')),
                memo: memo.isEmpty ? 'Path payment' : memo,
                createdAt: DateTime.parse(operation.createdAt),
                status: TransactionStatus.success,
                type: isIncoming ? TransactionType.received : TransactionType.sent,
                fee: 0.0001,
              );
            }
          } else if (operation is PathPaymentStrictSendOperationResponse) {
            // Handle strict send path payment operations
            final isIncoming = operation.to == publicKey;
            final isOutgoing = operation.from == publicKey;
            
            if (isIncoming || isOutgoing) {
              transaction = TransactionModel(
                id: operation.id,
                hash: operation.transactionHash,
                sourceAccount: operation.from,
                destinationAccount: operation.to,
                amount: double.parse(isOutgoing ? operation.sourceAmount : operation.amount),
                assetCode: isOutgoing 
                  ? (operation.sourceAssetType == 'native' ? 'XLM' : (operation.sourceAssetCode ?? ''))
                  : (operation.assetType == 'native' ? 'XLM' : (operation.assetCode ?? '')),
                memo: memo.isEmpty ? 'Path payment' : memo,
                createdAt: DateTime.parse(operation.createdAt),
                status: TransactionStatus.success,
                type: isIncoming ? TransactionType.received : TransactionType.sent,
                fee: 0.0001,
              );
            }
          }
          
          if (transaction != null) {
            allTransactions.add(transaction);
          }
        } catch (e) {
          debugPrint('Error processing operation ${operation.id}: $e');
          // Continue with next operation
          continue;
        }
      }
      
      // Remove duplicates (same transaction hash might appear multiple times)
      final uniqueTransactions = <String, TransactionModel>{};
      for (final tx in allTransactions) {
        final key = '${tx.hash}_${tx.type}_${tx.amount}';
        if (!uniqueTransactions.containsKey(key)) {
          uniqueTransactions[key] = tx;
        }
      }
      
      // Sort by date (newest first)
      final finalTransactions = uniqueTransactions.values.toList();
      finalTransactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return finalTransactions;
    } catch (e) {
      debugPrint('Error fetching comprehensive transaction history: $e');
      return [];
    }
  }

  /// Switch network
  static void switchNetwork(bool useTestnet) {
    initialize(useTestnet: useTestnet);
  }

  /// Get account information from Stellar network
  static Future<AccountResponse> getAccountInfo(String publicKey) async {
    try {
      return await sdk.accounts.account(publicKey);
    } catch (e) {
      throw Exception('Account not found or network error: $e');
    }
  }

  /// Create a new account on Stellar network
  static Future<TransactionModel> createAccount({
    required String sourceSecretKey,
    required String destinationAddress,
    required double startingBalance,
    String memo = '',
  }) async {
    try {
      final sourceKeyPair = KeyPair.fromSecretSeed(sourceSecretKey);
      final sourceAccount = await sdk.accounts.account(sourceKeyPair.accountId);
      
      final transaction = TransactionBuilder(sourceAccount)
          .addOperation(CreateAccountOperationBuilder(
            destinationAddress,
            startingBalance.toString(),
          ).build());

      if (memo.isNotEmpty) {
        transaction.addMemo(Memo.text(memo));
      }

      final built = transaction.build();
      built.sign(sourceKeyPair, currentNetwork.isTestnet ? Network.TESTNET : Network.PUBLIC);

      final response = await sdk.submitTransaction(built);
      
      if (response.success) {
        return TransactionModel(
          id: _generateTransactionId(),
          hash: response.hash!,
          sourceAccount: sourceKeyPair.accountId,
          destinationAccount: destinationAddress,
          amount: startingBalance,
          assetCode: 'XLM',
          memo: memo,
          createdAt: DateTime.now(),
          status: TransactionStatus.success,
          type: TransactionType.sent,
          fee: 0.0001,
        );
      } else {
        throw Exception('Transaction failed: ${response.resultXdr}');
      }
    } catch (e) {
      throw Exception('Failed to create account: $e');
    }
  }
}