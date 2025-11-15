import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Firebase Collection Cleanup Utility
/// Bu sınıf duplicate collection'ları temizlemek için kullanılır
class FirebaseCleanupService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Tüm split_bills koleksiyonlarını listeler
  static Future<void> listAllSplitBillCollections() async {
    try {
      // Ana split_bills koleksiyonunu kontrol et
      final mainCollection = await _firestore.collection('split_bills').get();
      debugPrint('Main split_bills collection: ${mainCollection.docs.length} documents');
      
      for (final doc in mainCollection.docs) {
        debugPrint('Document ID: ${doc.id}');
        debugPrint('Data: ${doc.data()}');
        debugPrint('---');
      }
      
      // split_requests koleksiyonunu da kontrol et
      final requestsCollection = await _firestore.collection('split_requests').get();
      debugPrint('split_requests collection: ${requestsCollection.docs.length} documents');
      
      for (final doc in requestsCollection.docs) {
        debugPrint('Request Document ID: ${doc.id}');
        debugPrint('Data: ${doc.data()}');
        debugPrint('---');
      }
      
    } catch (e) {
      debugPrint('Error listing collections: $e');
    }
  }

  /// split_requests koleksiyonundaki verileri split_bills'e taşır
  static Future<void> migrateSplitRequestsToSplitBills() async {
    try {
      final requestsSnapshot = await _firestore.collection('split_requests').get();
      debugPrint('Found ${requestsSnapshot.docs.length} documents in split_requests');

      final batch = _firestore.batch();
      
      for (final doc in requestsSnapshot.docs) {
        final data = doc.data();
        
        // Participants array'ini kontrol et ve participantWalletNames oluştur
        final participants = data['participants'] as List<dynamic>? ?? [];
        final participantWalletNames = participants
            .map((p) => p['walletName']?.toString() ?? '')
            .where((name) => name.isNotEmpty)
            .toList();
        
        // Yeni dokümana participantWalletNames ekle
        final newData = Map<String, dynamic>.from(data);
        newData['participantWalletNames'] = participantWalletNames;
        
        // split_bills koleksiyonuna ekle
        final newDocRef = _firestore.collection('split_bills').doc();
        batch.set(newDocRef, newData);
        
        debugPrint('Migrating document ${doc.id} to ${newDocRef.id}');
      }
      
      await batch.commit();
      debugPrint('Migration completed successfully');
      
    } catch (e) {
      debugPrint('Error during migration: $e');
    }
  }

  /// split_requests koleksiyonunu temizler (önce migration yapın!)
  static Future<void> cleanupSplitRequestsCollection() async {
    try {
      final requestsSnapshot = await _firestore.collection('split_requests').get();
      debugPrint('Deleting ${requestsSnapshot.docs.length} documents from split_requests');

      final batch = _firestore.batch();
      
      for (final doc in requestsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      debugPrint('split_requests collection cleaned up');
      
    } catch (e) {
      debugPrint('Error during cleanup: $e');
    }
  }

  /// Tüm split_bills dokümanlarına participantWalletNames ekler
  static Future<void> addParticipantWalletNamesToExistingDocs() async {
    try {
      final snapshot = await _firestore.collection('split_bills').get();
      debugPrint('Updating ${snapshot.docs.length} documents with participantWalletNames');

      final batch = _firestore.batch();
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        
        // Eğer participantWalletNames yoksa ekle
        if (!data.containsKey('participantWalletNames')) {
          final participants = data['participants'] as List<dynamic>? ?? [];
          final participantWalletNames = participants
              .map((p) => p['walletName']?.toString() ?? '')
              .where((name) => name.isNotEmpty)
              .toList();
          
          batch.update(doc.reference, {
            'participantWalletNames': participantWalletNames,
          });
          
          debugPrint('Adding participantWalletNames to document ${doc.id}: $participantWalletNames');
        }
      }
      
      await batch.commit();
      debugPrint('participantWalletNames added to existing documents');
      
    } catch (e) {
      debugPrint('Error adding participantWalletNames: $e');
    }
  }

  /// Eski split bill'lerde creator'ı otomatik paid yapar
  static Future<void> fixCreatorStatusInExistingBills() async {
    try {
      final snapshot = await _firestore.collection('split_bills').get();
      debugPrint('Checking ${snapshot.docs.length} documents for creator status');

      final batch = _firestore.batch();
      int updatedCount = 0;
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final creatorWalletName = data['creatorWalletName'] as String?;
        final participants = data['participants'] as List<dynamic>? ?? [];
        
        bool needsUpdate = false;
        final updatedParticipants = participants.map((p) {
          final participantData = p as Map<String, dynamic>;
          final walletName = participantData['walletName'] as String?;
          final status = participantData['status'] as String?;
          
          // Eğer bu participant creator ise ve status pending ise paid yap
          if (walletName == creatorWalletName && status == 'pending') {
            needsUpdate = true;
            final updatedParticipant = Map<String, dynamic>.from(participantData);
            updatedParticipant['status'] = 'paid';
            updatedParticipant['paidAt'] = data['createdAt']; // Creation time'ı paid time olarak kullan
            debugPrint('Updating creator $creatorWalletName to paid status in doc ${doc.id}');
            return updatedParticipant;
          }
          
          return participantData;
        }).toList();
        
        if (needsUpdate) {
          batch.update(doc.reference, {
            'participants': updatedParticipants,
          });
          updatedCount++;
        }
      }
      
      if (updatedCount > 0) {
        await batch.commit();
        debugPrint('Updated creator status in $updatedCount documents');
      } else {
        debugPrint('No documents needed creator status update');
      }
      
    } catch (e) {
      debugPrint('Error fixing creator status: $e');
    }
  }

  /// Wallet name'lerdeki @ işaretini temizler
  static Future<void> cleanWalletNamesInExistingBills() async {
    try {
      final snapshot = await _firestore.collection('split_bills').get();
      debugPrint('Cleaning wallet names in ${snapshot.docs.length} documents');

      final batch = _firestore.batch();
      int updatedCount = 0;
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final participants = data['participants'] as List<dynamic>? ?? [];
        final participantWalletNames = data['participantWalletNames'] as List<dynamic>? ?? [];
        
        bool needsUpdate = false;
        
        // Participants array'indeki wallet name'leri temizle
        final cleanedParticipants = participants.map((p) {
          final participantData = Map<String, dynamic>.from(p as Map<String, dynamic>);
          final walletName = participantData['walletName'] as String?;
          
          if (walletName != null && walletName.startsWith('@')) {
            participantData['walletName'] = walletName.substring(1);
            needsUpdate = true;
            debugPrint('Cleaning wallet name: $walletName -> ${participantData['walletName']}');
          }
          
          return participantData;
        }).toList();
        
        // participantWalletNames array'ini temizle
        final cleanedWalletNames = participantWalletNames.map((name) {
          final nameStr = name.toString();
          if (nameStr.startsWith('@')) {
            needsUpdate = true;
            return nameStr.substring(1);
          }
          return nameStr;
        }).toList();
        
        if (needsUpdate) {
          batch.update(doc.reference, {
            'participants': cleanedParticipants,
            'participantWalletNames': cleanedWalletNames,
          });
          updatedCount++;
        }
      }
      
      if (updatedCount > 0) {
        await batch.commit();
        debugPrint('Cleaned wallet names in $updatedCount documents');
      } else {
        debugPrint('No documents needed wallet name cleaning');
      }
      
    } catch (e) {
      debugPrint('Error cleaning wallet names: $e');
    }
  }

  /// Creator'ı participant listesinden çıkarır ve amounts'ları yeniden hesaplar
  static Future<void> removeCreatorFromParticipants() async {
    try {
      debugPrint('Removing creators from participants list...');
      
      final snapshot = await _firestore.collection('split_bills').get();
      final batch = _firestore.batch();
      int updatedCount = 0;
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final creatorWalletName = data['creatorWalletName']?.toString() ?? '';
        final totalAmount = (data['totalAmount'] ?? 0.0).toDouble();
        final participants = data['participants'] as List<dynamic>? ?? [];
        
        // Creator'ı participant listesinden çıkar
        final filteredParticipants = participants.where((p) {
          final walletName = p['walletName']?.toString() ?? '';
          return walletName != creatorWalletName;
        }).toList();
        
        // Eğer değişiklik varsa güncelle
        if (filteredParticipants.length != participants.length && filteredParticipants.isNotEmpty) {
          // Amount'ları yeniden hesapla
          final amountPerParticipant = totalAmount / filteredParticipants.length;
          
          final updatedParticipants = filteredParticipants.map((p) {
            final participant = Map<String, dynamic>.from(p);
            participant['amount'] = amountPerParticipant;
            return participant;
          }).toList();
          
          // participantWalletNames'i güncelle
          final participantWalletNames = updatedParticipants
              .map((p) => p['walletName']?.toString() ?? '')
              .where((name) => name.isNotEmpty)
              .toList();
          
          batch.update(doc.reference, {
            'participants': updatedParticipants,
            'participantWalletNames': participantWalletNames,
          });
          
          updatedCount++;
          debugPrint('Bill ${doc.id}: ${participants.length} -> ${filteredParticipants.length} participants, amount: ${amountPerParticipant.toStringAsFixed(7)} XLM');
        }
      }
      
      if (updatedCount > 0) {
        await batch.commit();
        debugPrint('Removed creators from $updatedCount split bills');
      } else {
        debugPrint('No split bills needed creator removal');
      }
      
    } catch (e) {
      debugPrint('Error removing creators from participants: $e');
    }
  }
}