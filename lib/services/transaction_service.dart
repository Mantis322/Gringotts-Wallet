import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import '../models/wallet_model.dart';
import '../services/stellar_service.dart';
import '../app/constants.dart';

/// Transaction Service
/// Handles transaction operations and validation
class TransactionService {
  /// Validate transaction inputs
  static TransactionValidationResult validateTransaction({
    required String destinationAddress,
    required String amount,
    required double currentBalance,
    String memo = '',
  }) {
    // Validate destination address
    if (destinationAddress.isEmpty) {
      return TransactionValidationResult(
        isValid: false,
        error: 'Destination address is required',
      );
    }

    if (!StellarService.isValidStellarAddress(destinationAddress)) {
      return TransactionValidationResult(
        isValid: false,
        error: AppConstants.errorInvalidAddress,
      );
    }

    // Validate amount
    if (amount.isEmpty) {
      return TransactionValidationResult(
        isValid: false,
        error: 'Amount is required',
      );
    }

    double parsedAmount;
    try {
      parsedAmount = double.parse(amount);
    } catch (e) {
      return TransactionValidationResult(
        isValid: false,
        error: AppConstants.errorInvalidAmount,
      );
    }

    if (parsedAmount <= 0) {
      return TransactionValidationResult(
        isValid: false,
        error: 'Amount must be greater than 0',
      );
    }

    if (parsedAmount < AppConstants.minTransactionAmount) {
      return TransactionValidationResult(
        isValid: false,
        error: 'Amount is too small (minimum: ${AppConstants.minTransactionAmount} XLM)',
      );
    }

    if (parsedAmount > AppConstants.maxTransactionAmount) {
      return TransactionValidationResult(
        isValid: false,
        error: 'Amount is too large',
      );
    }

    // Check balance (include fee estimation)
    const estimatedFee = 0.0001; // 100 stroops standard fee
    const minimumBalance = 1.0; // Minimum 1 XLM required to keep account active
    final totalRequired = parsedAmount + estimatedFee;
    final remainingBalance = currentBalance - totalRequired;
    
    if (totalRequired > currentBalance) {
      return TransactionValidationResult(
        isValid: false,
        error: AppConstants.errorInsufficientBalance,
      );
    }
    
    // Check if sending this amount would leave account below minimum balance
    if (remainingBalance < minimumBalance) {
      return TransactionValidationResult(
        isValid: false,
        error: 'Cannot send this amount. You must keep at least $minimumBalance XLM in your account to keep it active.',
      );
    }

    // Validate memo
    if (memo.length > AppConstants.maxMemoLength) {
      return TransactionValidationResult(
        isValid: false,
        error: 'Memo is too long (maximum: ${AppConstants.maxMemoLength} characters)',
      );
    }

    return TransactionValidationResult(
      isValid: true,
      estimatedFee: estimatedFee,
      totalAmount: totalRequired,
    );
  }

  /// Prepare transaction for signing
  static Future<TransactionPreparation> prepareTransaction({
    required String secretKey,
    required String destinationAddress,
    required double amount,
    String memo = '',
    String assetCode = 'XLM',
  }) async {
    try {
      // Verify destination account exists (for mainnet)
      if (!StellarService.currentNetwork.isTestnet) {
        final accountExists = await StellarService.accountExists(destinationAddress);
        if (!accountExists) {
          throw Exception('Destination account does not exist on mainnet');
        }
      }

      // Get current account balance to verify sufficient funds
      final sourceKeyPair = KeyPair.fromSecretSeed(secretKey);
      final currentBalance = await StellarService.getBalance(sourceKeyPair.accountId);
      
      // Validate transaction
      final validation = validateTransaction(
        destinationAddress: destinationAddress,
        amount: amount.toString(),
        currentBalance: currentBalance,
        memo: memo,
      );

      if (!validation.isValid) {
        throw Exception(validation.error);
      }

      return TransactionPreparation(
        sourceAddress: sourceKeyPair.accountId,
        destinationAddress: destinationAddress,
        amount: amount,
        assetCode: assetCode,
        memo: memo,
        estimatedFee: validation.estimatedFee!,
        totalAmount: validation.totalAmount!,
        isValid: true,
      );
    } catch (e) {
      return TransactionPreparation(
        sourceAddress: '',
        destinationAddress: destinationAddress,
        amount: amount,
        assetCode: assetCode,
        memo: memo,
        estimatedFee: 0.0001,
        totalAmount: amount + 0.0001,
        isValid: false,
        error: e.toString(),
      );
    }
  }

  /// Send transaction
  static Future<TransactionResult> sendTransaction({
    required String secretKey,
    required String destinationAddress,
    required double amount,
    String memo = '',
    String assetCode = 'XLM',
  }) async {
    try {
      // Prepare transaction
      final preparation = await prepareTransaction(
        secretKey: secretKey,
        destinationAddress: destinationAddress,
        amount: amount,
        memo: memo,
        assetCode: assetCode,
      );

      if (!preparation.isValid) {
        return TransactionResult(
          success: false,
          error: preparation.error ?? 'Transaction preparation failed',
        );
      }

      // Send payment via Stellar service
      final transaction = await StellarService.sendPayment(
        secretKey: secretKey,
        destinationAddress: destinationAddress,
        amount: amount,
        memo: memo,
        assetCode: assetCode,
      );

      return TransactionResult(
        success: true,
        transaction: transaction,
        message: AppConstants.successTransactionSent,
      );
    } catch (e) {
      return TransactionResult(
        success: false,
        error: 'Transaction failed: ${e.toString()}',
      );
    }
  }

  /// Format amount with proper XLM precision
  static String formatAmount(double amount) {
    return amount.toStringAsFixed(AppConstants.xlmDecimalPlaces);
  }

  /// Parse amount string to double
  static double parseAmount(String amount) {
    try {
      return double.parse(amount);
    } catch (e) {
      return 0.0;
    }
  }

  /// Calculate fee for transaction
  static double calculateFee({int operationCount = 1}) {
    // Stellar base fee is 100 stroops (0.00001 XLM) per operation
    const baseFee = 0.00001;
    return baseFee * operationCount * 10; // Use 10x base fee for reliable processing
  }

  /// Check if amount is valid for sending
  static bool isValidAmount(String amount, double currentBalance) {
    try {
      final parsedAmount = double.parse(amount);
      final totalRequired = parsedAmount + calculateFee();
      return parsedAmount > 0 && totalRequired <= currentBalance;
    } catch (e) {
      return false;
    }
  }
}

/// Transaction Validation Result
class TransactionValidationResult {
  final bool isValid;
  final String? error;
  final double? estimatedFee;
  final double? totalAmount;

  TransactionValidationResult({
    required this.isValid,
    this.error,
    this.estimatedFee,
    this.totalAmount,
  });
}

/// Transaction Preparation
class TransactionPreparation {
  final String sourceAddress;
  final String destinationAddress;
  final double amount;
  final String assetCode;
  final String memo;
  final double estimatedFee;
  final double totalAmount;
  final bool isValid;
  final String? error;

  TransactionPreparation({
    required this.sourceAddress,
    required this.destinationAddress,
    required this.amount,
    required this.assetCode,
    required this.memo,
    required this.estimatedFee,
    required this.totalAmount,
    required this.isValid,
    this.error,
  });
}

/// Transaction Result
class TransactionResult {
  final bool success;
  final TransactionModel? transaction;
  final String? error;
  final String? message;

  TransactionResult({
    required this.success,
    this.transaction,
    this.error,
    this.message,
  });
}