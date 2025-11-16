import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/spending_request_model.dart';
import '../services/stellar_service.dart';

class SpendingRequestService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _groupTransactionsCollection = 
      _firestore.collection('group_transactions');

  /// Get pending spending requests for a group wallet
  static Future<List<SpendingRequest>> getPendingSpendingRequests(String groupWalletId) async {
    try {
      final querySnapshot = await _groupTransactionsCollection
          .where('groupWalletId', isEqualTo: groupWalletId)
          .where('type', isEqualTo: 'spending')
          .where('status', isEqualTo: 'pending')
          // order by createdAt because documents use createdAt timestamp field
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        return SpendingRequest.fromFirestore(doc);
      }).toList();
    } catch (e) {
      print('Error getting pending spending requests: $e');
      return [];
    }
  }

  /// Get completed spending requests for a group wallet
  static Future<List<SpendingRequest>> getCompletedSpendingRequests(String groupWalletId) async {
    try {
      final querySnapshot = await _groupTransactionsCollection
          .where('groupWalletId', isEqualTo: groupWalletId)
          .where('type', isEqualTo: 'spending')
          .where('status', whereIn: ['completed', 'failed'])
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        return SpendingRequest.fromFirestore(doc);
      }).toList();
    } catch (e) {
      print('Error getting completed spending requests: $e');
      return [];
    }
  }

  /// Approve or reject a spending request
  static Future<bool> approveSpendingRequest(
    String requestId, 
    String userWalletName, 
    bool approve
  ) async {
    try {

      final doc = await _groupTransactionsCollection.doc(requestId).get();
      
      if (!doc.exists) {
        return false;
      }

      final data = doc.data() as Map<String, dynamic>;
      List<String> approvedBy = List<String>.from(data['approvedBy'] ?? []);
      List<String> rejectedBy = List<String>.from(data['rejectedBy'] ?? []);
      
      if (approve) {
        if (!approvedBy.contains(userWalletName)) {
          approvedBy.add(userWalletName);
        }
        rejectedBy.remove(userWalletName);
      } else {
        if (!rejectedBy.contains(userWalletName)) {
          rejectedBy.add(userWalletName);
        }
        approvedBy.remove(userWalletName);
      }

      await _groupTransactionsCollection.doc(requestId).update({
        'approvedBy': approvedBy,
        'rejectedBy': rejectedBy,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Check if we have enough approvals to change status
      final groupWalletId = data['groupWalletId'];
      
      final groupWalletDoc = await _firestore
          .collection('group_wallets')
          .doc(groupWalletId)
          .get();
      
      if (groupWalletDoc.exists) {
        final groupWalletData = groupWalletDoc.data() as Map<String, dynamic>;
        final settings = groupWalletData['settings'] as Map<String, dynamic>;
        final requiredSignatures = settings['requiredSignatures'] ?? 1;
        
        // Request creator automatically approves their own request
        final requestCreator = data['fromWalletName'];
        
        // Count effective approvals (including creator's implicit approval)
        Set<String> effectiveApprovals = Set.from(approvedBy);
        if (requestCreator != null) {
          effectiveApprovals.add(requestCreator);
        }
        
        String newStatus = 'pending';
        if (rejectedBy.isNotEmpty) {
          newStatus = 'rejected';
        } else if (effectiveApprovals.length >= requiredSignatures) {
          newStatus = 'approved';
        }

        if (newStatus == 'approved') {
          
          // Execute the actual Stellar transfer
          try {
            String recipientPublicKey;
            final toWalletName = data['toWalletName'];
            
            // Check if toWalletName is already a public key (starts with G and 56 chars)
            if (toWalletName.startsWith('G') && toWalletName.length == 56) {
              recipientPublicKey = toWalletName;
            } else {
              recipientPublicKey = await _getPublicKeyFromWalletName(toWalletName);
            }
            
            final transactionHash = await _executeTransfer(
              groupWalletId: groupWalletId,
              recipientAddress: recipientPublicKey,
              amount: (data['amount'] ?? 0.0).toDouble(),
              memo: data['description'] ?? '',
            );
            
            // Update status to completed with transaction hash
            await _groupTransactionsCollection.doc(requestId).update({
              'status': 'completed',
              'transactionHash': transactionHash,
              'completedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          } catch (transferError) {
            // Update status to failed
            await _groupTransactionsCollection.doc(requestId).update({
              'status': 'failed',
              'errorMessage': transferError.toString(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        } else if (newStatus == 'rejected') {
          await _groupTransactionsCollection.doc(requestId).update({
            'status': newStatus,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      return true;
    } catch (e) {
      print('Error approving spending request: $e');
      return false;
    }
  }

  /// Execute actual Stellar transfer from group wallet
  static Future<String> _executeTransfer({
    required String groupWalletId,
    required String recipientAddress,
    required double amount,
    required String memo,
  }) async {
    try {
      // Get group wallet info to get the secret key (this would need proper multi-sig implementation)
      final groupWalletDoc = await _firestore.collection('group_wallets').doc(groupWalletId).get();
      
      if (!groupWalletDoc.exists) {
        throw Exception('Group wallet not found');
      }

      final groupWalletData = groupWalletDoc.data() as Map<String, dynamic>;
      
      // TODO: In a real multi-signature implementation, this would require
      // collecting signatures from multiple members. For now, we'll use a 
      // simplified approach assuming the group wallet has a stored secret key.
      
      // This is a placeholder - in production, you'd need proper multi-signature handling
      final sourceSecretKey = groupWalletData['secretKey'] ?? '';
      
      if (sourceSecretKey.isEmpty) {
        throw Exception('Group wallet secret key not available - multi-signature not fully implemented');
      }
      
      // Execute the transfer using StellarService
      final transactionResult = await StellarService.sendPayment(
        secretKey: sourceSecretKey,
        destinationAddress: recipientAddress,
        amount: amount,
        memo: memo,
      );

      return transactionResult.hash;
    } catch (e) {
      throw Exception('Transfer failed: $e');
    }
  }

  /// Helper method to get public key from wallet name
  static Future<String> _getPublicKeyFromWalletName(String walletName) async {
    try {
      final walletDoc = await _firestore
          .collection('wallets')
          .where('name', isEqualTo: walletName)
          .limit(1)
          .get();
      
      if (walletDoc.docs.isEmpty) {
        throw Exception('Wallet not found: $walletName');
      }

      final walletData = walletDoc.docs.first.data();
      final publicKey = walletData['publicKey'] ?? '';
      
      if (publicKey.isEmpty) {
        throw Exception('Public key not found for wallet: $walletName');
      }

      return publicKey;
    } catch (e) {
      throw Exception('Failed to get recipient address: $e');
    }
  }
}