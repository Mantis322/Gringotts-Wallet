/// PIN Code Model for Receive Payments
/// Represents a temporary PIN code for receiving payments
class PinCodeModel {
  final String id;
  final String pinCode;
  final String walletPublicKey;
  final double amount;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isUsed;
  final String? walletName;
  final String? memo;

  const PinCodeModel({
    required this.id,
    required this.pinCode,
    required this.walletPublicKey,
    required this.amount,
    required this.createdAt,
    required this.expiresAt,
    this.isUsed = false,
    this.walletName,
    this.memo,
  });

  // Factory constructor from JSON
  factory PinCodeModel.fromJson(Map<String, dynamic> json) {
    return PinCodeModel(
      id: json['id'] as String,
      pinCode: json['pinCode'] as String,
      walletPublicKey: json['walletPublicKey'] as String,
      amount: (json['amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      isUsed: json['isUsed'] as bool? ?? false,
      walletName: json['walletName'] as String?,
      memo: json['memo'] as String?,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pinCode': pinCode,
      'walletPublicKey': walletPublicKey,
      'amount': amount,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'isUsed': isUsed,
      'walletName': walletName,
      'memo': memo,
    };
  }

  // Factory constructor from Firestore
  factory PinCodeModel.fromFirestore(Map<String, dynamic> data) {
    return PinCodeModel(
      id: data['id'] as String,
      pinCode: data['pinCode'] as String,
      walletPublicKey: data['walletPublicKey'] as String,
      amount: (data['amount'] as num).toDouble(),
      createdAt: (data['createdAt'] as dynamic).toDate(),
      expiresAt: (data['expiresAt'] as dynamic).toDate(),
      isUsed: data['isUsed'] as bool? ?? false,
      walletName: data['walletName'] as String?,
      memo: data['memo'] as String?,
    );
  }

  // Convert to Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'pinCode': pinCode,
      'walletPublicKey': walletPublicKey,
      'amount': amount,
      'createdAt': createdAt,
      'expiresAt': expiresAt,
      'isUsed': isUsed,
      'walletName': walletName,
      'memo': memo,
    };
  }

  // Helper getters
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isValid => !isUsed && !isExpired;
  String get displayAmount => '${amount.toStringAsFixed(7)} XLM';
  String get formattedPinCode => pinCode.replaceAllMapped(
    RegExp(r'(\d{3})(\d{3})'),
    (match) => '${match[1]} ${match[2]}',
  );
  
  Duration get timeRemaining => isExpired 
    ? Duration.zero 
    : expiresAt.difference(DateTime.now());
    
  String get timeRemainingText {
    final remaining = timeRemaining;
    if (remaining.inMinutes <= 0) return 'Expired';
    return '${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  // Copy with method
  PinCodeModel copyWith({
    String? id,
    String? pinCode,
    String? walletPublicKey,
    double? amount,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? isUsed,
    String? walletName,
    String? memo,
  }) {
    return PinCodeModel(
      id: id ?? this.id,
      pinCode: pinCode ?? this.pinCode,
      walletPublicKey: walletPublicKey ?? this.walletPublicKey,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isUsed: isUsed ?? this.isUsed,
      walletName: walletName ?? this.walletName,
      memo: memo ?? this.memo,
    );
  }
}