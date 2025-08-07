import 'package:intl/intl.dart';

/// Warranty Model
class Warranty {
  final String id;
  final String userId;
  final String? receiptId;
  
  // Product information
  final String productName;
  final String? brand;
  final String? modelNumber;
  final String? serialNumber;
  final String? category;
  
  // Purchase details
  final DateTime purchaseDate;
  final double? purchasePrice;
  final String? currency;
  
  // Warranty information
  final int warrantyPeriodMonths;
  final DateTime warrantyStartDate;
  final DateTime warrantyEndDate;
  final WarrantyType warrantyType;
  
  // Documents
  final String? warrantyDocumentUrl;
  final String? purchaseProofUrl;
  
  // Status tracking
  final bool isActive;
  final ClaimStatus claimStatus;
  final WarrantyClaim? claimDetails;
  
  // Alerts
  final List<int> alertDaysBefore;
  final DateTime? lastAlertSent;
  
  // Audit fields
  final DateTime createdAt;
  final DateTime updatedAt;

  Warranty({
    required this.id,
    required this.userId,
    this.receiptId,
    required this.productName,
    this.brand,
    this.modelNumber,
    this.serialNumber,
    this.category,
    required this.purchaseDate,
    this.purchasePrice,
    this.currency,
    required this.warrantyPeriodMonths,
    required this.warrantyStartDate,
    required this.warrantyEndDate,
    this.warrantyType = WarrantyType.manufacturer,
    this.warrantyDocumentUrl,
    this.purchaseProofUrl,
    this.isActive = true,
    this.claimStatus = ClaimStatus.none,
    this.claimDetails,
    this.alertDaysBefore = const [30, 7, 1],
    this.lastAlertSent,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create Warranty from JSON
  factory Warranty.fromJson(Map<String, dynamic> json) {
    return Warranty(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      receiptId: json['receipt_id'] as String?,
      productName: json['product_name'] as String,
      brand: json['brand'] as String?,
      modelNumber: json['model_number'] as String?,
      serialNumber: json['serial_number'] as String?,
      category: json['category'] as String?,
      purchaseDate: DateTime.parse(json['purchase_date'] as String),
      purchasePrice: (json['purchase_price'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      warrantyPeriodMonths: json['warranty_period_months'] as int,
      warrantyStartDate: DateTime.parse(json['warranty_start_date'] as String),
      warrantyEndDate: DateTime.parse(json['warranty_end_date'] as String),
      warrantyType: WarrantyType.values.firstWhere(
        (e) => e.name == json['warranty_type'],
        orElse: () => WarrantyType.manufacturer,
      ),
      warrantyDocumentUrl: json['warranty_document_url'] as String?,
      purchaseProofUrl: json['purchase_proof_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      claimStatus: ClaimStatus.values.firstWhere(
        (e) => e.name == json['claim_status'],
        orElse: () => ClaimStatus.none,
      ),
      claimDetails: json['claim_details'] != null
          ? WarrantyClaim.fromJson(json['claim_details'] as Map<String, dynamic>)
          : null,
      alertDaysBefore: List<int>.from(json['alert_days_before'] as List? ?? [30, 7, 1]),
      lastAlertSent: json['last_alert_sent'] != null
          ? DateTime.parse(json['last_alert_sent'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert Warranty to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'receipt_id': receiptId,
      'product_name': productName,
      'brand': brand,
      'model_number': modelNumber,
      'serial_number': serialNumber,
      'category': category,
      'purchase_date': purchaseDate.toIso8601String().split('T')[0],
      'purchase_price': purchasePrice,
      'currency': currency,
      'warranty_period_months': warrantyPeriodMonths,
      'warranty_start_date': warrantyStartDate.toIso8601String().split('T')[0],
      'warranty_end_date': warrantyEndDate.toIso8601String().split('T')[0],
      'warranty_type': warrantyType.name,
      'warranty_document_url': warrantyDocumentUrl,
      'purchase_proof_url': purchaseProofUrl,
      'is_active': isActive,
      'claim_status': claimStatus.name,
      'claim_details': claimDetails?.toJson(),
      'alert_days_before': alertDaysBefore,
      'last_alert_sent': lastAlertSent?.toIso8601String(),
    };
  }

  /// Create a copy with updated values
  Warranty copyWith({
    String? receiptId,
    String? productName,
    String? brand,
    String? modelNumber,
    String? serialNumber,
    String? category,
    DateTime? purchaseDate,
    double? purchasePrice,
    String? currency,
    int? warrantyPeriodMonths,
    DateTime? warrantyStartDate,
    DateTime? warrantyEndDate,
    WarrantyType? warrantyType,
    String? warrantyDocumentUrl,
    String? purchaseProofUrl,
    bool? isActive,
    ClaimStatus? claimStatus,
    WarrantyClaim? claimDetails,
    List<int>? alertDaysBefore,
    DateTime? lastAlertSent,
  }) {
    return Warranty(
      id: id,
      userId: userId,
      receiptId: receiptId ?? this.receiptId,
      productName: productName ?? this.productName,
      brand: brand ?? this.brand,
      modelNumber: modelNumber ?? this.modelNumber,
      serialNumber: serialNumber ?? this.serialNumber,
      category: category ?? this.category,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      currency: currency ?? this.currency,
      warrantyPeriodMonths: warrantyPeriodMonths ?? this.warrantyPeriodMonths,
      warrantyStartDate: warrantyStartDate ?? this.warrantyStartDate,
      warrantyEndDate: warrantyEndDate ?? this.warrantyEndDate,
      warrantyType: warrantyType ?? this.warrantyType,
      warrantyDocumentUrl: warrantyDocumentUrl ?? this.warrantyDocumentUrl,
      purchaseProofUrl: purchaseProofUrl ?? this.purchaseProofUrl,
      isActive: isActive ?? this.isActive,
      claimStatus: claimStatus ?? this.claimStatus,
      claimDetails: claimDetails ?? this.claimDetails,
      alertDaysBefore: alertDaysBefore ?? this.alertDaysBefore,
      lastAlertSent: lastAlertSent ?? this.lastAlertSent,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Get days remaining until warranty expires
  int get daysUntilExpiry {
    return warrantyEndDate.difference(DateTime.now()).inDays;
  }

  /// Check if warranty is expired
  bool get isExpired {
    return DateTime.now().isAfter(warrantyEndDate);
  }

  /// Check if warranty is expiring soon (within next 30 days)
  bool get isExpiringSoon {
    final daysLeft = daysUntilExpiry;
    return daysLeft > 0 && daysLeft <= 30;
  }

  /// Get warranty status
  WarrantyStatus get status {
    if (isExpired) return WarrantyStatus.expired;
    if (isExpiringSoon) return WarrantyStatus.expiringSoon;
    if (!isActive) return WarrantyStatus.inactive;
    return WarrantyStatus.active;
  }

  /// Get warranty status color
  Color get statusColor {
    switch (status) {
      case WarrantyStatus.active:
        return Colors.green;
      case WarrantyStatus.expiringSoon:
        return Colors.orange;
      case WarrantyStatus.expired:
        return Colors.red;
      case WarrantyStatus.inactive:
        return Colors.grey;
    }
  }

  /// Get formatted warranty period
  String get formattedWarrantyPeriod {
    if (warrantyPeriodMonths < 12) {
      return '$warrantyPeriodMonths ${warrantyPeriodMonths == 1 ? 'month' : 'months'}';
    } else {
      final years = warrantyPeriodMonths ~/ 12;
      final remainingMonths = warrantyPeriodMonths % 12;
      
      if (remainingMonths == 0) {
        return '$years ${years == 1 ? 'year' : 'years'}';
      } else {
        return '$years ${years == 1 ? 'year' : 'years'}, $remainingMonths ${remainingMonths == 1 ? 'month' : 'months'}';
      }
    }
  }

  /// Get formatted purchase price
  String get formattedPurchasePrice {
    if (purchasePrice == null) return 'N/A';
    
    final formatter = NumberFormat.currency(
      symbol: _getCurrencySymbol(currency ?? 'USD'),
      decimalDigits: 2,
    );
    return formatter.format(purchasePrice);
  }

  /// Get formatted warranty end date
  String get formattedWarrantyEndDate {
    return DateFormat('MMM dd, yyyy').format(warrantyEndDate);
  }

  /// Get formatted days until expiry
  String get formattedDaysUntilExpiry {
    final days = daysUntilExpiry;
    
    if (days < 0) return 'Expired';
    if (days == 0) return 'Expires today';
    if (days == 1) return 'Expires tomorrow';
    
    if (days < 30) {
      return 'Expires in $days days';
    } else if (days < 365) {
      final months = (days / 30).round();
      return 'Expires in ~$months ${months == 1 ? 'month' : 'months'}';
    } else {
      final years = (days / 365).round();
      return 'Expires in ~$years ${years == 1 ? 'year' : 'years'}';
    }
  }

  /// Check if alert should be sent
  bool shouldSendAlert() {
    if (isExpired || !isActive) return false;
    
    final daysLeft = daysUntilExpiry;
    
    // Check if we should send an alert based on alert days
    final shouldAlert = alertDaysBefore.any((alertDay) => daysLeft == alertDay);
    
    // Don't send if we already sent an alert today
    if (lastAlertSent != null) {
      final lastAlertDate = DateTime(
        lastAlertSent!.year,
        lastAlertSent!.month,
        lastAlertSent!.day,
      );
      final today = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      
      if (lastAlertDate.isAtSameMomentAs(today)) {
        return false;
      }
    }
    
    return shouldAlert;
  }

  /// Get currency symbol
  String _getCurrencySymbol(String currencyCode) {
    switch (currencyCode) {
      case 'USD': return '\$';
      case 'EUR': return '€';
      case 'GBP': return '£';
      case 'INR': return '₹';
      case 'CAD': return 'C\$';
      case 'AUD': return 'A\$';
      case 'JPY': return '¥';
      default: return currencyCode;
    }
  }

  @override
  String toString() {
    return 'Warranty(id: $id, product: $productName, expires: $formattedWarrantyEndDate)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Warranty && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Warranty Type Enum
enum WarrantyType {
  manufacturer,
  extended,
  insurance,
  thirdParty;

  String get displayName {
    switch (this) {
      case WarrantyType.manufacturer:
        return 'Manufacturer Warranty';
      case WarrantyType.extended:
        return 'Extended Warranty';
      case WarrantyType.insurance:
        return 'Insurance Coverage';
      case WarrantyType.thirdParty:
        return 'Third-Party Warranty';
    }
  }
}

/// Warranty Status Enum
enum WarrantyStatus {
  active,
  expiringSoon,
  expired,
  inactive;

  String get displayName {
    switch (this) {
      case WarrantyStatus.active:
        return 'Active';
      case WarrantyStatus.expiringSoon:
        return 'Expiring Soon';
      case WarrantyStatus.expired:
        return 'Expired';
      case WarrantyStatus.inactive:
        return 'Inactive';
    }
  }
}

/// Claim Status Enum
enum ClaimStatus {
  none,
  pending,
  approved,
  rejected,
  completed;

  String get displayName {
    switch (this) {
      case ClaimStatus.none:
        return 'No Claim';
      case ClaimStatus.pending:
        return 'Claim Pending';
      case ClaimStatus.approved:
        return 'Claim Approved';
      case ClaimStatus.rejected:
        return 'Claim Rejected';
      case ClaimStatus.completed:
        return 'Claim Completed';
    }
  }

  Color get color {
    switch (this) {
      case ClaimStatus.none:
        return Colors.grey;
      case ClaimStatus.pending:
        return Colors.orange;
      case ClaimStatus.approved:
        return Colors.blue;
      case ClaimStatus.rejected:
        return Colors.red;
      case ClaimStatus.completed:
        return Colors.green;
    }
  }
}

/// Warranty Claim Model
class WarrantyClaim {
  final String claimNumber;
  final DateTime claimDate;
  final String issueDescription;
  final String? resolution;
  final List<String> documents;
  final Map<String, dynamic> contactInfo;
  final DateTime? resolvedDate;

  WarrantyClaim({
    required this.claimNumber,
    required this.claimDate,
    required this.issueDescription,
    this.resolution,
    this.documents = const [],
    this.contactInfo = const {},
    this.resolvedDate,
  });

  factory WarrantyClaim.fromJson(Map<String, dynamic> json) {
    return WarrantyClaim(
      claimNumber: json['claim_number'] as String,
      claimDate: DateTime.parse(json['claim_date'] as String),
      issueDescription: json['issue_description'] as String,
      resolution: json['resolution'] as String?,
      documents: List<String>.from(json['documents'] as List? ?? []),
      contactInfo: Map<String, dynamic>.from(json['contact_info'] as Map? ?? {}),
      resolvedDate: json['resolved_date'] != null
          ? DateTime.parse(json['resolved_date'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'claim_number': claimNumber,
      'claim_date': claimDate.toIso8601String(),
      'issue_description': issueDescription,
      'resolution': resolution,
      'documents': documents,
      'contact_info': contactInfo,
      'resolved_date': resolvedDate?.toIso8601String(),
    };
  }
}