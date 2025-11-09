import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pin_code_model.dart';

/// PIN Code Service
/// Firebase-based service for managing temporary PIN codes for receiving payments
class PinCodeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _pinCodesCollection = 'pin_codes';
  static const int _pinCodeLength = 6;
  static const int _expirationMinutes = 5;

  /// Generate a unique 6-digit PIN code
  static String _generatePinCode() {
    final random = Random();
    final pinCode = List.generate(_pinCodeLength, (index) => random.nextInt(10)).join();
    return pinCode;
  }

  /// Generate a unique ID for the PIN code
  static String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() + 
           Random().nextInt(9999).toString().padLeft(4, '0');
  }

  /// Create a new PIN code for receiving payment
  /// @param walletPublicKey The wallet's public key to receive payment
  /// @param amount The amount to receive in XLM
  /// @param walletName Optional wallet display name
  /// @param memo Optional memo for the payment
  /// @return PinCodeModel if successful
  static Future<PinCodeModel> createPinCode({
    required String walletPublicKey,
    required double amount,
    String? walletName,
    String? memo,
  }) async {
    try {
      final now = DateTime.now();
      final pinCode = _generatePinCode();
      final id = _generateId();
      
      // Ensure PIN code is unique
      bool isUnique = false;
      String uniquePinCode = pinCode;
      int attempts = 0;
      
      while (!isUnique && attempts < 10) {
        final existingQuery = await _firestore
            .collection(_pinCodesCollection)
            .where('pinCode', isEqualTo: uniquePinCode)
            .where('isUsed', isEqualTo: false)
            .where('expiresAt', isGreaterThan: now)
            .limit(1)
            .get();
            
        if (existingQuery.docs.isEmpty) {
          isUnique = true;
        } else {
          uniquePinCode = _generatePinCode();
          attempts++;
        }
      }
      
      if (!isUnique) {
        throw PinCodeException('Failed to generate unique PIN code after multiple attempts');
      }

      final pinCodeModel = PinCodeModel(
        id: id,
        pinCode: uniquePinCode,
        walletPublicKey: walletPublicKey,
        amount: amount,
        createdAt: now,
        expiresAt: now.add(Duration(minutes: _expirationMinutes)),
        isUsed: false,
        walletName: walletName,
        memo: memo,
      );

      // Save to Firestore
      await _firestore
          .collection(_pinCodesCollection)
          .doc(id)
          .set(pinCodeModel.toFirestore());

      return pinCodeModel;
    } catch (e) {
      if (e is PinCodeException) rethrow;
      throw PinCodeException('Failed to create PIN code: $e');
    }
  }

  /// Validate and retrieve PIN code information
  /// @param pinCode The 6-digit PIN code to validate
  /// @return PinCodeModel if valid and unused
  static Future<PinCodeModel?> validatePinCode(String pinCode) async {
    try {
      // Clean the PIN code (remove spaces)
      final cleanPinCode = pinCode.replaceAll(' ', '');
      
      if (cleanPinCode.length != _pinCodeLength) {
        return null;
      }

      final now = DateTime.now();
      
      // Query for active PIN codes
      final query = await _firestore
          .collection(_pinCodesCollection)
          .where('pinCode', isEqualTo: cleanPinCode)
          .where('isUsed', isEqualTo: false)
          .where('expiresAt', isGreaterThan: now)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return null;
      }

      final doc = query.docs.first;
      final pinCodeModel = PinCodeModel.fromFirestore(doc.data());

      // Double-check validity
      if (!pinCodeModel.isValid) {
        return null;
      }

      return pinCodeModel;
    } catch (e) {
      throw PinCodeException('Failed to validate PIN code: $e');
    }
  }

  /// Use a PIN code (mark as used)
  /// @param pinCodeOrId Either the 6-digit PIN code or the document ID
  /// @return true if successfully marked as used
  static Future<bool> usePinCode(String pinCodeOrId) async {
    try {
      // If it's a 6-digit code, find the document first
      if (pinCodeOrId.length == _pinCodeLength && RegExp(r'^\d+$').hasMatch(pinCodeOrId)) {
        final now = DateTime.now();
        final query = await _firestore
            .collection(_pinCodesCollection)
            .where('pinCode', isEqualTo: pinCodeOrId)
            .where('isUsed', isEqualTo: false)
            .where('expiresAt', isGreaterThan: now)
            .limit(1)
            .get();

        if (query.docs.isEmpty) {
          throw PinCodeException('PIN code not found or already used');
        }

        final docId = query.docs.first.id;
        await _firestore
            .collection(_pinCodesCollection)
            .doc(docId)
            .update({
          'isUsed': true,
          'usedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Assume it's a document ID
        await _firestore
            .collection(_pinCodesCollection)
            .doc(pinCodeOrId)
            .update({
          'isUsed': true,
          'usedAt': FieldValue.serverTimestamp(),
        });
      }

      return true;
    } catch (e) {
      throw PinCodeException('Failed to mark PIN code as used: $e');
    }
  }

  /// Get PIN code by ID
  /// @param pinCodeId The ID of the PIN code
  /// @return PinCodeModel if found
  static Future<PinCodeModel?> getPinCodeById(String pinCodeId) async {
    try {
      final doc = await _firestore
          .collection(_pinCodesCollection)
          .doc(pinCodeId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return PinCodeModel.fromFirestore(doc.data()!);
    } catch (e) {
      throw PinCodeException('Failed to get PIN code: $e');
    }
  }

  /// Get active PIN codes for a wallet
  /// @param walletPublicKey The wallet's public key
  /// @return List of active PIN codes
  static Future<List<PinCodeModel>> getActivePinCodes(String walletPublicKey) async {
    try {
      final now = DateTime.now();
      
      final query = await _firestore
          .collection(_pinCodesCollection)
          .where('walletPublicKey', isEqualTo: walletPublicKey)
          .where('isUsed', isEqualTo: false)
          .where('expiresAt', isGreaterThan: now)
          .orderBy('expiresAt', descending: false)
          .get();

      return query.docs
          .map((doc) => PinCodeModel.fromFirestore(doc.data()))
          .where((pinCode) => pinCode.isValid)
          .toList();
    } catch (e) {
      throw PinCodeException('Failed to get active PIN codes: $e');
    }
  }

  /// Clean up expired PIN codes (for maintenance)
  /// This method removes PIN codes that have been expired for more than 1 hour
  static Future<void> cleanupExpiredPinCodes() async {
    try {
      final cutoffTime = DateTime.now().subtract(Duration(hours: 1));
      
      final query = await _firestore
          .collection(_pinCodesCollection)
          .where('expiresAt', isLessThan: cutoffTime)
          .get();

      final batch = _firestore.batch();
      for (final doc in query.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      throw PinCodeException('Failed to cleanup expired PIN codes: $e');
    }
  }

  /// Cancel a PIN code (mark as used without actual usage)
  /// @param pinCodeId The ID of the PIN code to cancel
  /// @return true if successfully cancelled
  static Future<bool> cancelPinCode(String pinCodeId) async {
    try {
      await _firestore
          .collection(_pinCodesCollection)
          .doc(pinCodeId)
          .update({
        'isUsed': true,
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      throw PinCodeException('Failed to cancel PIN code: $e');
    }
  }

  /// Get PIN code statistics for a wallet
  /// @param walletPublicKey The wallet's public key
  /// @return Map with statistics
  static Future<Map<String, int>> getPinCodeStats(String walletPublicKey) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // Active PIN codes
      final activeQuery = await _firestore
          .collection(_pinCodesCollection)
          .where('walletPublicKey', isEqualTo: walletPublicKey)
          .where('isUsed', isEqualTo: false)
          .where('expiresAt', isGreaterThan: now)
          .get();
      
      // Used PIN codes today
      final usedTodayQuery = await _firestore
          .collection(_pinCodesCollection)
          .where('walletPublicKey', isEqualTo: walletPublicKey)
          .where('isUsed', isEqualTo: true)
          .where('createdAt', isGreaterThanOrEqualTo: today)
          .get();

      return {
        'active': activeQuery.docs.length,
        'usedToday': usedTodayQuery.docs.length,
      };
    } catch (e) {
      return {'active': 0, 'usedToday': 0};
    }
  }
}

/// Custom Exception for PIN Code operations
class PinCodeException implements Exception {
  final String message;
  
  const PinCodeException(this.message);
  
  @override
  String toString() => 'PinCodeException: $message';
}