import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Wallet Registry Service
/// Firebase-based wallet name registry for @walletname functionality
class WalletRegistryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _walletsCollection = 'wallet_registry';

  /// Initialize Firebase
  static Future<void> initialize() async {
    await Firebase.initializeApp();
  }

  /// Check if a wallet name is available
  /// @param walletName The desired wallet name (without @)
  /// @return true if available, false if taken  
  static Future<bool> isWalletNameAvailable(String walletName) async {
    try {
      final normalizedName = _normalizeWalletName(walletName);
      
      final doc = await _firestore
          .collection(_walletsCollection)
          .doc(normalizedName)
          .get();
          
      return !doc.exists;
    } catch (e) {
      throw WalletRegistryException('Failed to check name availability: $e');
    }
  }

  /// Register a wallet name with its public key
  /// @param walletName The wallet name (without @) - this is the actual wallet name from wallet model
  /// @param publicKey The wallet's public key
  /// @param displayName Optional display name for the wallet (defaults to walletName)
  /// @return true if successfully registered
  static Future<bool> registerWalletName({
    required String walletName,
    required String publicKey,
    String? displayName,
  }) async {
    try {
      final normalizedName = _normalizeWalletName(walletName);
      
      // Check if name is available
      final isAvailable = await isWalletNameAvailable(normalizedName);
      if (!isAvailable) {
        throw WalletRegistryException('Wallet name "$walletName" is already taken');
      }

      // Check if public key is already registered
      final existingDoc = await _firestore
          .collection(_walletsCollection)
          .where('publicKey', isEqualTo: publicKey)
          .limit(1)
          .get();

      if (existingDoc.docs.isNotEmpty) {
        throw WalletRegistryException('This wallet is already registered with another name');
      }

      // Register the wallet name
      await _firestore
          .collection(_walletsCollection)
          .doc(normalizedName)
          .set({
        'walletName': normalizedName,
        'publicKey': publicKey,
        'displayName': displayName ?? walletName,
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      return true;
    } catch (e) {
      if (e is WalletRegistryException) rethrow;
      throw WalletRegistryException('Failed to register wallet name: $e');
    }
  }

  /// Update wallet name registration (rename)
  /// @param oldWalletName Current wallet name
  /// @param newWalletName New desired wallet name
  /// @param publicKey Wallet's public key for verification
  /// @return true if successfully updated
  static Future<bool> updateWalletName({
    required String oldWalletName,
    required String newWalletName,
    required String publicKey,
    String? displayName,
  }) async {
    try {
      final oldNormalizedName = _normalizeWalletName(oldWalletName);
      final newNormalizedName = _normalizeWalletName(newWalletName);

      if (oldNormalizedName == newNormalizedName) {
        // Just update display name if wallet name is the same
        await _firestore
            .collection(_walletsCollection)
            .doc(oldNormalizedName)
            .update({
          'displayName': displayName ?? newWalletName,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        return true;
      }

      // Check if new name is available
      final isAvailable = await isWalletNameAvailable(newNormalizedName);
      if (!isAvailable) {
        throw WalletRegistryException('Wallet name "$newWalletName" is already taken');
      }

      // Verify ownership of old wallet name
      final oldDoc = await _firestore
          .collection(_walletsCollection)
          .doc(oldNormalizedName)
          .get();

      if (!oldDoc.exists) {
        throw WalletRegistryException('Original wallet name not found');
      }

      final oldData = oldDoc.data()!;
      if (oldData['publicKey'] != publicKey) {
        throw WalletRegistryException('You do not own this wallet name');
      }

      // Perform atomic update: create new and delete old
      final batch = _firestore.batch();

      // Create new document
      batch.set(
        _firestore.collection(_walletsCollection).doc(newNormalizedName),
        {
          'walletName': newNormalizedName,
          'publicKey': publicKey,
          'displayName': displayName ?? newWalletName,
          'createdAt': oldData['createdAt'],
          'lastUpdated': FieldValue.serverTimestamp(),
          'isActive': true,
        },
      );

      // Delete old document
      batch.delete(_firestore.collection(_walletsCollection).doc(oldNormalizedName));

      await batch.commit();
      return true;
    } catch (e) {
      if (e is WalletRegistryException) rethrow;
      throw WalletRegistryException('Failed to update wallet name: $e');
    }
  }

  /// Unregister a wallet name
  /// @param walletName The wallet name to unregister
  /// @param publicKey Wallet's public key for verification
  /// @return true if successfully unregistered
  static Future<bool> unregisterWalletName({
    required String walletName,
    required String publicKey,
  }) async {
    try {
      final normalizedName = _normalizeWalletName(walletName);

      // Verify ownership
      final doc = await _firestore
          .collection(_walletsCollection)
          .doc(normalizedName)
          .get();

      if (!doc.exists) {
        throw WalletRegistryException('Wallet name not found');
      }

      final data = doc.data()!;
      if (data['publicKey'] != publicKey) {
        throw WalletRegistryException('You do not own this wallet name');
      }

      // Delete the document
      await _firestore
          .collection(_walletsCollection)
          .doc(normalizedName)
          .delete();

      return true;
    } catch (e) {
      if (e is WalletRegistryException) rethrow;
      throw WalletRegistryException('Failed to unregister wallet name: $e');
    }
  }

  /// Resolve a wallet name to public key
  /// @param walletName The wallet name to resolve (with or without @)
  /// @return The public key associated with the wallet name
  static Future<String?> resolveWalletName(String walletName) async {
    try {
      final normalizedName = _normalizeWalletName(walletName);
      
      final doc = await _firestore
          .collection(_walletsCollection)
          .doc(normalizedName)
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      return data['publicKey'] as String?;
    } catch (e) {
      throw WalletRegistryException('Failed to resolve wallet name: $e');
    }
  }

  /// Get wallet info by name
  /// @param walletName The wallet name to lookup
  /// @return WalletRegistryEntry or null if not found
  static Future<WalletRegistryEntry?> getWalletInfo(String walletName) async {
    try {
      final normalizedName = _normalizeWalletName(walletName);
      
      final doc = await _firestore
          .collection(_walletsCollection)
          .doc(normalizedName)
          .get();

      if (!doc.exists) return null;

      return WalletRegistryEntry.fromFirestore(doc);
    } catch (e) {
      throw WalletRegistryException('Failed to get wallet info: $e');
    }
  }

  /// Get wallet info by public key
  /// @param publicKey The public key to lookup
  /// @return WalletRegistryEntry or null if not found
  static Future<WalletRegistryEntry?> getWalletInfoByPublicKey(String publicKey) async {
    try {
      final query = await _firestore
          .collection(_walletsCollection)
          .where('publicKey', isEqualTo: publicKey)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;

      return WalletRegistryEntry.fromFirestore(query.docs.first);
    } catch (e) {
      throw WalletRegistryException('Failed to get wallet info by public key: $e');
    }
  }

  /// Check if a wallet needs Firebase registration
  /// Returns true if wallet exists but not registered in Firebase
  /// @param publicKey The wallet's public key to check
  /// @return true if needs registration, false if already registered
  static Future<bool> doesWalletNeedRegistration(String publicKey) async {
    try {
      final registryEntry = await getWalletInfoByPublicKey(publicKey);
      return registryEntry == null; // Needs registration if not found in Firebase
    } catch (e) {
      // If there's an error checking, assume it needs registration to be safe
      return true;
    }
  }

  /// Search for wallet names (for autocomplete)
  /// @param query Search query
  /// @param limit Maximum number of results
  /// @return List of matching wallet names
  static Future<List<String>> searchWalletNames({
    required String query,
    int limit = 10,
  }) async {
    try {
      final normalizedQuery = _normalizeWalletName(query);
      
      // Firebase doesn't support contains queries, so we use range queries
      final snapshot = await _firestore
          .collection(_walletsCollection)
          .where('walletName', isGreaterThanOrEqualTo: normalizedQuery)
          .where('walletName', isLessThan: '${normalizedQuery}z')
          .where('isActive', isEqualTo: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => doc.data()['walletName'] as String)
          .toList();
    } catch (e) {
      throw WalletRegistryException('Failed to search wallet names: $e');
    }
  }

  /// Validate wallet name format
  /// @param walletName The wallet name to validate
  /// @return ValidationResult with details
  static ValidationResult validateWalletName(String walletName) {
    final normalized = _normalizeWalletName(walletName);
    
    // Check length
    if (normalized.length < 3) {
      return ValidationResult(
        isValid: false,
        error: 'Wallet name must be at least 3 characters long',
      );
    }
    
    if (normalized.length > 20) {
      return ValidationResult(
        isValid: false,
        error: 'Wallet name must be no more than 20 characters long',
      );
    }
    
    // Check format (alphanumeric and underscore only)
    final regex = RegExp(r'^[a-z0-9_]+$');
    if (!regex.hasMatch(normalized)) {
      return ValidationResult(
        isValid: false,
        error: 'Wallet name can only contain letters, numbers, and underscores',
      );
    }
    
    // Check if starts with number
    if (RegExp(r'^[0-9]').hasMatch(normalized)) {
      return ValidationResult(
        isValid: false,
        error: 'Wallet name cannot start with a number',
      );
    }
    
    // Check for reserved words
    const reservedWords = [
      'admin', 'root', 'system', 'stellar', 'xlm', 'gringotts',
      'wallet', 'test', 'demo', 'api', 'support', 'help'
    ];
    
    if (reservedWords.contains(normalized)) {
      return ValidationResult(
        isValid: false,
        error: 'This wallet name is reserved',
      );
    }
    
    return ValidationResult(isValid: true);
  }

  /// Normalize wallet name (remove @, convert to lowercase, trim)
  static String _normalizeWalletName(String walletName) {
    return walletName
        .replaceAll('@', '')
        .toLowerCase()
        .trim();
  }
}

/// Wallet Registry Entry Model
class WalletRegistryEntry {
  final String walletName;
  final String publicKey;
  final String displayName;
  final DateTime createdAt;
  final DateTime lastUpdated;
  final bool isActive;

  const WalletRegistryEntry({
    required this.walletName,
    required this.publicKey,
    required this.displayName,
    required this.createdAt,
    required this.lastUpdated,
    required this.isActive,
  });

  factory WalletRegistryEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return WalletRegistryEntry(
      walletName: data['walletName'] as String,
      publicKey: data['publicKey'] as String,
      displayName: data['displayName'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  String get formattedWalletName => '@$walletName';
  String get shortPublicKey => '${publicKey.substring(0, 6)}...${publicKey.substring(publicKey.length - 6)}';
}

/// Validation Result Model
class ValidationResult {
  final bool isValid;
  final String? error;

  const ValidationResult({
    required this.isValid,
    this.error,
  });
}

/// Custom Exception for Wallet Registry operations
class WalletRegistryException implements Exception {
  final String message;
  
  const WalletRegistryException(this.message);
  
  @override
  String toString() => 'WalletRegistryException: $message';
}