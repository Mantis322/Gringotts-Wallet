import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/split_bill_model.dart';
import 'wallet_registry_service.dart';

/// Simplified Split Bill Service
/// Manages split bill operations with a single collection
class SplitBillService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _splitBillsCollection = 'split_bills';

  /// Create a new split bill
  static Future<String> createSplitBill({
    required String creatorWalletName,
    required double totalAmount,
    required String description,
    required List<String> participantWalletNames,
    Duration? expiryDuration,
  }) async {
    try {
      // Validate creator wallet name
      final creatorAvailable = await WalletRegistryService.isWalletNameAvailable(creatorWalletName);
      if (creatorAvailable) {
        throw Exception('Creator wallet name not found');
      }

      // Validate participant wallet names
      for (final participantName in participantWalletNames) {
        final available = await WalletRegistryService.isWalletNameAvailable(participantName);
        if (available) {
          throw Exception('Participant wallet name not found: $participantName');
        }
      }

      // Calculate each person's share including the creator
      final totalPeople = participantWalletNames.length + 1; // creator + participants
      final amountPerParticipant = totalPeople > 0 ? totalAmount / totalPeople : totalAmount;
      
      final now = DateTime.now();
      final expiresAt = now.add(expiryDuration ?? const Duration(days: 7));

      // Create participants (creator is NOT included)
      final participants = participantWalletNames.map((name) => SplitParticipant(
        walletName: name,
        amount: amountPerParticipant,
        status: SplitParticipantStatus.pending,
      )).toList();

      // Create split bill
      final splitBill = SplitBillModel(
        id: '', // Will be set by Firestore
        creatorWalletName: creatorWalletName,
        totalAmount: totalAmount,
        description: description,
        participants: participants,
        createdAt: now,
        expiresAt: expiresAt,
        status: SplitBillStatus.active,
      );

      // Save to Firestore
      final docRef = await _firestore
          .collection(_splitBillsCollection)
          .add(splitBill.toFirestore());

      debugPrint('SplitBillService: Created split bill with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating split bill: $e');
      rethrow;
    }
  }

  /// Mark participant as paid
  static Future<bool> markParticipantAsPaid({
    required String splitBillId,
    required String participantWalletName,
    String? transactionHash,
  }) async {
    try {
      final docRef = _firestore.collection(_splitBillsCollection).doc(splitBillId);
      final doc = await docRef.get();
      
      if (!doc.exists) {
        debugPrint('Split bill not found: $splitBillId');
        return false;
      }

      final splitBill = SplitBillModel.fromFirestore(doc);
      final totalPeople = splitBill.totalPeople;
      final normalizedShare = totalPeople > 0
          ? splitBill.totalAmount / totalPeople
          : splitBill.totalAmount;
      
      // Find and update participant while normalizing share
      final updatedParticipants = splitBill.participants.map((participant) {
        final syncedParticipant = participant.copyWith(amount: normalizedShare);
        if (participant.walletName == participantWalletName) {
          return syncedParticipant.copyWith(
            status: SplitParticipantStatus.paid,
            paidAt: DateTime.now(),
            transactionHash: transactionHash,
          );
        }
        return syncedParticipant;
      }).toList();

      // Update split bill status if all participants paid
      final allPaid = updatedParticipants.every((p) => p.isPaid);
      final newStatus = allPaid ? SplitBillStatus.completed : SplitBillStatus.active;

      // Update in Firestore
      await docRef.update({
        'participants': updatedParticipants.map((p) => p.toMap()).toList(),
        'status': newStatus.name,
      });

      debugPrint('Split bill $splitBillId: Marked $participantWalletName as paid');
      return true;
    } catch (e) {
      debugPrint('Error marking participant as paid: $e');
      return false;
    }
  }

  /// Cancel a split bill
  static Future<bool> cancelSplitBill(String splitBillId) async {
    try {
      await _firestore
          .collection(_splitBillsCollection)
          .doc(splitBillId)
          .update({'status': SplitBillStatus.cancelled.name});
      
      return true;
    } catch (e) {
      debugPrint('Error cancelling split bill: $e');
      return false;
    }
  }

  /// Get split bills created by a specific wallet
  static Stream<QuerySnapshot> getCreatedSplitBills(String creatorWalletName) {
    return _firestore
        .collection(_splitBillsCollection)
        .where('creatorWalletName', isEqualTo: creatorWalletName)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Get split bills where user is invited as participant
  static Stream<QuerySnapshot> getInvitedSplitBills(String participantWalletName) {
    // Query split bills where the participantWalletNames array contains the user.
    // We store a top-level 'participantWalletNames' array in the document for this.
    debugPrint('SplitBillService.getInvitedSplitBills: Querying for participant: $participantWalletName');
    
    return _firestore
        .collection(_splitBillsCollection)
        .where('participantWalletNames', arrayContains: participantWalletName)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Get count of unread split bill invitations
  static Future<int> getUnreadInvitationsCount(String participantWalletName) async {
    try {
    final snapshot = await _firestore
      .collection(_splitBillsCollection)
      .where('participantWalletNames', arrayContains: participantWalletName)
      .where('status', isEqualTo: SplitBillStatus.active.name)
      .get();

      // Count bills where current user hasn't paid yet
      int unreadCount = 0;
      for (final doc in snapshot.docs) {
        final splitBill = SplitBillModel.fromFirestore(doc);

        // Only count if user is a participant (not creator) and hasn't paid
        SplitParticipant? myParticipant;
        for (final p in splitBill.participants) {
          if (p.walletName == participantWalletName) {
            myParticipant = p;
            break;
          }
        }

        if (myParticipant != null &&
            splitBill.creatorWalletName != participantWalletName &&
            !myParticipant.isPaid) {
          unreadCount++;
        }
      }
      
      return unreadCount;
    } catch (e) {
      debugPrint('Error getting unread invitations count: $e');
      return 0;
    }
  }

  /// Clean up expired split bills
  static Future<void> cleanupExpiredSplitBills() async {
    try {
      final now = DateTime.now();
      
      final expiredBills = await _firestore
          .collection(_splitBillsCollection)
          .where('expiresAt', isLessThan: Timestamp.fromDate(now))
          .where('status', isEqualTo: SplitBillStatus.active.name)
          .get();

      final batch = _firestore.batch();
      
      for (final doc in expiredBills.docs) {
        batch.update(doc.reference, {
          'status': SplitBillStatus.expired.name,
        });
      }

      await batch.commit();
      debugPrint('SplitBillService: Cleaned up ${expiredBills.docs.length} expired bills');
    } catch (e) {
      debugPrint('Error cleaning up expired split bills: $e');
    }
  }

  /// Process payment for a split bill participant
  static Future<void> processPayment({
    required String splitBillId,
    required String participantWalletName,
    required String transactionHash,
  }) async {
    try {
      final docRef = _firestore.collection(_splitBillsCollection).doc(splitBillId);
      
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists) {
          throw Exception('Split bill not found');
        }

        final splitBill = SplitBillModel.fromFirestore(doc);
        final totalPeople = splitBill.totalPeople;
        final normalizedShare = totalPeople > 0
            ? splitBill.totalAmount / totalPeople
            : splitBill.totalAmount;
        
        // Ensure participant amounts are normalized and update payer status
        final updatedParticipants = splitBill.participants.map((participant) {
          final syncedParticipant = participant.copyWith(amount: normalizedShare);
          if (participant.walletName == participantWalletName) {
            return syncedParticipant.copyWith(
              status: SplitParticipantStatus.paid,
              paidAt: DateTime.now(),
              transactionHash: transactionHash,
            );
          }
          return syncedParticipant;
        }).toList();

        // Check if all participants have paid
        final allPaid = updatedParticipants.every((p) => p.status == SplitParticipantStatus.paid);
        final newStatus = allPaid ? SplitBillStatus.completed : SplitBillStatus.active;

        // Update the split bill
        transaction.update(docRef, {
          'participants': updatedParticipants.map((p) => p.toMap()).toList(),
          'status': newStatus.name,
        });
      });

      debugPrint('SplitBillService: Payment processed for $participantWalletName in bill $splitBillId');
    } catch (e) {
      debugPrint('Error processing payment: $e');
      throw Exception('Failed to process payment: $e');
    }
  }
}
