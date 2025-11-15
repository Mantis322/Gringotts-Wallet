import 'package:cloud_firestore/cloud_firestore.dart';

/// Split Bill Model
/// Represents a bill that needs to be split among multiple participants
class SplitBillModel {
  final String id;
  final String creatorWalletName; // @creator
  final double totalAmount;
  final String description;
  final List<SplitParticipant> participants;
  final List<String>? participantWalletNames; // For efficient querying
  final DateTime createdAt;
  final DateTime expiresAt;
  final SplitBillStatus status;
  final Map<String, dynamic> metadata;

  SplitBillModel({
    required this.id,
    required this.creatorWalletName,
    required this.totalAmount,
    required this.description,
    required this.participants,
    this.participantWalletNames,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
    this.metadata = const {},
  });

  /// Amount per participant (already calculated correctly during creation)
  double get amountPerParticipant => participants.isNotEmpty ? participants.first.amount : 0.0;

  /// Number of paid participants
  int get paidCount => participants.where((p) => p.status == SplitParticipantStatus.paid).length;

  /// Number of pending participants
  int get pendingCount => participants.where((p) => p.status == SplitParticipantStatus.pending).length;

  /// Total amount collected so far
  double get collectedAmount => participants
      .where((p) => p.status == SplitParticipantStatus.paid)
      .fold(0.0, (sum, p) => sum + p.amount);

  /// Remaining amount to be collected
  double get remainingAmount => totalAmount - collectedAmount;

  /// Check if all participants have paid
  bool get isCompleted => participants.every((p) => p.status == SplitParticipantStatus.paid);

  /// Check if expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Create from Firestore document
  factory SplitBillModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return SplitBillModel(
      id: doc.id,
      creatorWalletName: data['creatorWalletName'] ?? '',
      totalAmount: (data['totalAmount'] ?? 0.0).toDouble(),
      description: data['description'] ?? '',
      participants: (data['participants'] as List<dynamic>? ?? [])
          .map((p) => SplitParticipant.fromMap(p as Map<String, dynamic>))
          .toList(),
      participantWalletNames: (data['participantWalletNames'] as List<dynamic>?)
          ?.map((name) => name.toString()).toList(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      status: SplitBillStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => SplitBillStatus.active,
      ),
      metadata: data['metadata'] ?? {},
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'creatorWalletName': creatorWalletName,
      'totalAmount': totalAmount,
      'description': description,
      'participants': participants.map((p) => p.toMap()).toList(),
      // Helpful top-level array for efficient querying of invited users
      'participantWalletNames': participants.map((p) => p.walletName).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'status': status.name,
      'metadata': metadata,
    };
  }

  /// Create a copy with updated fields
  SplitBillModel copyWith({
    String? id,
    String? creatorWalletName,
    double? totalAmount,
    String? description,
    List<SplitParticipant>? participants,
    List<String>? participantWalletNames,
    DateTime? createdAt,
    DateTime? expiresAt,
    SplitBillStatus? status,
    Map<String, dynamic>? metadata,
  }) {
    return SplitBillModel(
      id: id ?? this.id,
      creatorWalletName: creatorWalletName ?? this.creatorWalletName,
      totalAmount: totalAmount ?? this.totalAmount,
      description: description ?? this.description,
      participants: participants ?? this.participants,
      participantWalletNames: participantWalletNames ?? this.participantWalletNames,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Split Bill Participant
class SplitParticipant {
  final String walletName; // @walletname
  final double amount;
  final SplitParticipantStatus status;
  final DateTime? paidAt;
  final String? transactionHash;
  final String? pinCode; // Optional PIN code for payment

  SplitParticipant({
    required this.walletName,
    required this.amount,
    required this.status,
    this.paidAt,
    this.transactionHash,
    this.pinCode,
  });

  factory SplitParticipant.fromMap(Map<String, dynamic> map) {
    return SplitParticipant(
      walletName: map['walletName'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      status: SplitParticipantStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => SplitParticipantStatus.pending,
      ),
      paidAt: map['paidAt'] != null ? (map['paidAt'] as Timestamp).toDate() : null,
      transactionHash: map['transactionHash'],
      pinCode: map['pinCode'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'walletName': walletName,
      'amount': amount,
      'status': status.name,
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'transactionHash': transactionHash,
      'pinCode': pinCode,
    };
  }

  SplitParticipant copyWith({
    String? walletName,
    double? amount,
    SplitParticipantStatus? status,
    DateTime? paidAt,
    String? transactionHash,
    String? pinCode,
  }) {
    return SplitParticipant(
      walletName: walletName ?? this.walletName,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      paidAt: paidAt ?? this.paidAt,
      transactionHash: transactionHash ?? this.transactionHash,
      pinCode: pinCode ?? this.pinCode,
    );
  }

  /// Returns true if the participant has paid their share
  bool get isPaid => status == SplitParticipantStatus.paid;
}

/// Split Bill Status
enum SplitBillStatus {
  active,      // Active, accepting payments
  completed,   // All participants paid
  cancelled,   // Cancelled by creator
  expired,     // Expired
}

/// Split Participant Status
enum SplitParticipantStatus {
  pending,     // Waiting for payment
  paid,        // Payment completed
  declined,    // Declined to pay
}

/// Split Request Model (for individual participant view)
class SplitRequestModel {
  final String id;
  final String splitBillId;
  final String creatorWalletName;
  final String participantWalletName;
  final double amount;
  final String description;
  final DateTime createdAt;
  final DateTime expiresAt;
  final SplitParticipantStatus status;
  final DateTime? paidAt;
  final String? transactionHash;

  SplitRequestModel({
    required this.id,
    required this.splitBillId,
    required this.creatorWalletName,
    required this.participantWalletName,
    required this.amount,
    required this.description,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
    this.paidAt,
    this.transactionHash,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isPending => status == SplitParticipantStatus.pending;
  bool get isPaid => status == SplitParticipantStatus.paid;

  factory SplitRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return SplitRequestModel(
      id: doc.id,
      splitBillId: data['splitBillId'] ?? '',
      creatorWalletName: data['creatorWalletName'] ?? '',
      participantWalletName: data['participantWalletName'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      description: data['description'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      status: SplitParticipantStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => SplitParticipantStatus.pending,
      ),
      paidAt: data['paidAt'] != null ? (data['paidAt'] as Timestamp).toDate() : null,
      transactionHash: data['transactionHash'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'splitBillId': splitBillId,
      'creatorWalletName': creatorWalletName,
      'participantWalletName': participantWalletName,
      'amount': amount,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'status': status.name,
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'transactionHash': transactionHash,
    };
  }
}