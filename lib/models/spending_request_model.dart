import 'package:cloud_firestore/cloud_firestore.dart';

class SpendingRequest {
  final String id;
  final String groupWalletId;
  final String requesterWalletName;
  final String recipientAddress;
  final double amount;
  final String description;
  final DateTime createdAt;
  final List<String> approvedBy;
  final List<String> rejectedBy;
  final String status;
  final int requiredSignatures;
  final String? transactionHash;
  final DateTime? completedAt;
  final String? errorMessage;

  SpendingRequest({
    required this.id,
    required this.groupWalletId,
    required this.requesterWalletName,
    required this.recipientAddress,
    required this.amount,
    required this.description,
    required this.createdAt,
    required this.approvedBy,
    required this.rejectedBy,
    required this.status,
    required this.requiredSignatures,
    this.transactionHash,
    this.completedAt,
    this.errorMessage,
  });

  factory SpendingRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SpendingRequest(
      id: doc.id,
      groupWalletId: data['groupWalletId'] ?? '',
      requesterWalletName: data['fromWalletName'] ?? '',
      recipientAddress: data['toWalletName'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      description: data['description'] ?? '',
      // Accept either 'createdAt' or older 'timestamp' field
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() 
          ?? (data['timestamp'] as Timestamp?)?.toDate() 
          ?? DateTime.now(),
      approvedBy: List<String>.from(data['approvedBy'] ?? []),
      rejectedBy: List<String>.from(data['rejectedBy'] ?? []),
      status: data['status'] ?? 'pending',
      requiredSignatures: data['requiredSignatures'] ?? 1,
      transactionHash: data['transactionHash'],
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      errorMessage: data['errorMessage'],
    );
  }

  static SpendingRequest fromMap(Map<String, dynamic> map) {
    return SpendingRequest(
      id: map['id'] ?? '',
      groupWalletId: map['groupWalletId'] ?? '',
      requesterWalletName: map['fromWalletName'] ?? '',
      recipientAddress: map['toWalletName'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      description: map['description'] ?? '',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : map['timestamp'] is Timestamp
              ? (map['timestamp'] as Timestamp).toDate()
              : DateTime.now(),
      approvedBy: List<String>.from(map['approvedBy'] ?? []),
      rejectedBy: List<String>.from(map['rejectedBy'] ?? []),
      status: map['status'] ?? 'pending',
      requiredSignatures: map['requiredSignatures'] ?? 1,
      transactionHash: map['transactionHash'],
      completedAt: map['completedAt'] is Timestamp
          ? (map['completedAt'] as Timestamp).toDate()
          : null,
      errorMessage: map['errorMessage'],
    );
  }

  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get needsMoreApprovals => approvedBy.length < requiredSignatures;
  
  bool hasUserApproved(String walletName) => approvedBy.contains(walletName);
  bool hasUserRejected(String walletName) => rejectedBy.contains(walletName);
  bool canUserVote(String walletName) => !hasUserApproved(walletName) && !hasUserRejected(walletName);
}