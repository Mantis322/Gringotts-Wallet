import 'package:equatable/equatable.dart';

/// WhisperPay session model for BLE beacon data
class WhisperPaySession extends Equatable {
  final String sessionId;
  final String deviceId;
  final String? walletName;
  final String? walletAddress;
  final double? amount;
  final String? memo;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isActive;

  const WhisperPaySession({
    required this.sessionId,
    required this.deviceId,
    this.walletName,
    this.walletAddress,
    this.amount,
    this.memo,
    required this.createdAt,
    required this.expiresAt,
    this.isActive = true,
  });

  factory WhisperPaySession.fromMap(Map<String, dynamic> map) {
    return WhisperPaySession(
      sessionId: map['session_id'] ?? '',
      deviceId: map['device_id'] ?? '',
      walletName: map['wallet_name'],
      walletAddress: map['wallet_address'],
      amount: map['amount']?.toDouble(),
      memo: map['memo'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] ?? 0),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(map['expires_at'] ?? 0),
      isActive: map['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'session_id': sessionId,
      'device_id': deviceId,
      'wallet_name': walletName,
      'wallet_address': walletAddress,
      'amount': amount,
      'memo': memo,
      'created_at': createdAt.millisecondsSinceEpoch,
      'expires_at': expiresAt.millisecondsSinceEpoch,
      'is_active': isActive,
    };
  }

  WhisperPaySession copyWith({
    String? sessionId,
    String? deviceId,
    String? walletName,
    String? walletAddress,
    double? amount,
    String? memo,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? isActive,
  }) {
    return WhisperPaySession(
      sessionId: sessionId ?? this.sessionId,
      deviceId: deviceId ?? this.deviceId,
      walletName: walletName ?? this.walletName,
      walletAddress: walletAddress ?? this.walletAddress,
      amount: amount ?? this.amount,
      memo: memo ?? this.memo,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isActive: isActive ?? this.isActive,
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  @override
  List<Object?> get props => [
        sessionId,
        deviceId,
        walletName,
        walletAddress,
        amount,
        memo,
        createdAt,
        expiresAt,
        isActive,
      ];
}

/// BLE beacon data structure for WhisperPay
class WhisperPayBeacon extends Equatable {
  final String sessionId;
  final String deviceId;
  final DateTime timestamp;
  final String hmac;
  final int rssi;
  final double? amount;
  final String? walletAddress;

  const WhisperPayBeacon({
    required this.sessionId,
    required this.deviceId,
    required this.timestamp,
    required this.hmac,
    required this.rssi,
    this.amount,
    this.walletAddress,
  });

  factory WhisperPayBeacon.fromBytes(List<int> bytes, int rssi) {
    // Parse beacon data from BLE advertisement
    if (bytes.length < 20) {
      throw ArgumentError('Invalid beacon data length');
    }

    final sessionId = String.fromCharCodes(bytes.sublist(0, 8));
    final deviceId = String.fromCharCodes(bytes.sublist(8, 16));
    final timestamp = DateTime.fromMillisecondsSinceEpoch(
      bytes[16] << 24 | bytes[17] << 16 | bytes[18] << 8 | bytes[19],
    );
    final hmac = bytes.length > 20 ? String.fromCharCodes(bytes.sublist(20)) : '';

    return WhisperPayBeacon(
      sessionId: sessionId,
      deviceId: deviceId,
      timestamp: timestamp,
      hmac: hmac,
      rssi: rssi,
    );
  }

  List<int> toBytes() {
    final sessionBytes = sessionId.codeUnits.take(8).toList();
    final deviceBytes = deviceId.codeUnits.take(8).toList();
    final timestampMs = timestamp.millisecondsSinceEpoch;
    final timestampBytes = [
      (timestampMs >> 24) & 0xFF,
      (timestampMs >> 16) & 0xFF,
      (timestampMs >> 8) & 0xFF,
      timestampMs & 0xFF,
    ];
    final hmacBytes = hmac.codeUnits;

    return [...sessionBytes, ...deviceBytes, ...timestampBytes, ...hmacBytes];
  }

  double get estimatedDistance {
    // Rough distance estimation based on RSSI
    // This is approximate and can vary significantly
    if (rssi >= -60) return 0.2; // Very close (20cm)
    if (rssi >= -65) return 0.3; // Close (30cm)
    if (rssi >= -70) return 0.5; // Near (50cm)
    if (rssi >= -75) return 1.0; // Medium (1m)
    if (rssi >= -80) return 2.0; // Far (2m)
    return 3.0; // Very far (3m+)
  }

  bool get isInRange => rssi >= -72; // Approx 20-50cm range

  @override
  List<Object?> get props => [sessionId, deviceId, timestamp, hmac, rssi, amount, walletAddress];
}

/// WhisperPay handshake response from server
class WhisperPayHandshake extends Equatable {
  final bool success;
  final String? walletAddress;
  final String? walletName;
  final double? amount;
  final String? memo;
  final String? errorMessage;

  const WhisperPayHandshake({
    required this.success,
    this.walletAddress,
    this.walletName,
    this.amount,
    this.memo,
    this.errorMessage,
  });

  factory WhisperPayHandshake.fromMap(Map<String, dynamic> map) {
    return WhisperPayHandshake(
      success: map['success'] ?? false,
      walletAddress: map['wallet_address'],
      walletName: map['wallet_name'],
      amount: map['amount']?.toDouble(),
      memo: map['memo'],
      errorMessage: map['error_message'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'wallet_address': walletAddress,
      'wallet_name': walletName,
      'amount': amount,
      'memo': memo,
      'error_message': errorMessage,
    };
  }

  @override
  List<Object?> get props => [
        success,
        walletAddress,
        walletName,
        amount,
        memo,
        errorMessage,
      ];
}

/// WhisperPay operation states
enum WhisperPayState {
  idle,
  receiveModeActive,
  scanningForDevices,
  handshakeInProgress,
  paymentConfirmation,
  processing,
  completed,
  error,
}

/// WhisperPay operation modes
enum WhisperPayMode {
  receive,
  send,
}