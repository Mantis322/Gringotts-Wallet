import 'dart:math';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'package:bip39/bip39.dart' as bip39;
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
      // Generate mnemonic
      final mnemonic = bip39.generateMnemonic();
      
      // Generate random keypair
      final keyPair = KeyPair.random();
      
      final wallet = WalletModel(
        publicKey: keyPair.accountId,
        secretKey: keyPair.secretSeed,
        mnemonic: mnemonic,
        balance: 0.0,
        isTestnet: currentNetwork.isTestnet,
        createdAt: DateTime.now(),
        lastUpdated: DateTime.now(),
      );

      // Fund account if on testnet
      if (currentNetwork.isTestnet) {
        await _fundTestnetAccount(keyPair.accountId);
        await Future.delayed(const Duration(seconds: 2)); // Wait for funding
        final balance = await getBalance(keyPair.accountId);
        return wallet.copyWith(balance: balance);
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
      
      return WalletModel(
        publicKey: keyPair.accountId,
        secretKey: secretKey,
        mnemonic: null, // Import edilen cüzdan için mnemonic yok
        balance: balance,
        isTestnet: currentNetwork.isTestnet,
        createdAt: DateTime.now(),
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Failed to import wallet: $e');
    }
  }

  /// Get account balance
  static Future<double> getBalance(String publicKey) async {
    try {
      final account = await sdk.accounts.account(publicKey);
      
      for (final balance in account.balances) {
        if (balance.assetType == 'native') {
          return double.parse(balance.balance);
        }
      }
      
      return 0.0;
    } catch (e) {
      // Account might not exist yet
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
        throw Exception('Transaction failed: ${response.extras?.resultCodes?.transactionResultCode}');
      }
    } catch (e) {
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

  /// Get transaction history (simplified for demo)
  static Future<List<TransactionModel>> getTransactionHistory(String publicKey) async {
    try {
      final payments = await sdk.payments.forAccount(publicKey).limit(20).execute();
      final transactions = <TransactionModel>[];
      
      for (final payment in payments.records) {
        if (payment is PaymentOperationResponse) {
          final isIncoming = payment.to == publicKey;
          
          transactions.add(TransactionModel(
            id: payment.id,
            hash: payment.transactionHash,
            sourceAccount: payment.from,
            destinationAccount: payment.to,
            amount: double.parse(payment.amount),
            assetCode: payment.assetType == 'native' ? 'XLM' : (payment.assetCode ?? ''),
            memo: '', // Memo would need to be fetched from transaction details
            createdAt: DateTime.parse(payment.createdAt),
            status: TransactionStatus.success,
            type: isIncoming ? TransactionType.received : TransactionType.sent,
            fee: 0.0001, // Standard fee
          ));
        }
      }
      
      return transactions;
    } catch (e) {
      return [];
    }
  }

  /// Switch network
  static void switchNetwork(bool useTestnet) {
    initialize(useTestnet: useTestnet);
  }
}