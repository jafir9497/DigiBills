import 'package:intl/intl.dart';

/// Receipt Model
class Receipt {
  final String id;
  final String userId;
  final String? merchantId;
  
  // Receipt identification
  final String? receiptNumber;
  final DateTime receiptDate;
  
  // Financial details
  final double subtotal;
  final double taxAmount;
  final double totalAmount;
  final String currency;
  
  // Tax information
  final TaxDetails? taxDetails;
  
  // OCR extracted data
  final String? ocrText;
  final double? ocrConfidence;
  final Map<String, dynamic>? ocrExtractedData;
  
  // File storage
  final String? imageUrl;
  final String? pdfUrl;
  final String? imageHash;
  
  // Classification
  final String? category;
  final String? subcategory;
  final List<String> tags;
  final String? notes;
  
  // AI analysis
  final Map<String, dynamic>? aiAnalysis;
  
  // Line items
  final List<ReceiptItem>? items;
  
  // Audit fields
  final DateTime createdAt;
  final DateTime updatedAt;

  Receipt({
    required this.id,
    required this.userId,
    this.merchantId,
    this.receiptNumber,
    required this.receiptDate,
    required this.subtotal,
    this.taxAmount = 0.0,
    required this.totalAmount,
    required this.currency,
    this.taxDetails,
    this.ocrText,
    this.ocrConfidence,
    this.ocrExtractedData,
    this.imageUrl,
    this.pdfUrl,
    this.imageHash,
    this.category,
    this.subcategory,
    this.tags = const [],
    this.notes,
    this.aiAnalysis,
    this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create Receipt from JSON
  factory Receipt.fromJson(Map<String, dynamic> json) {
    return Receipt(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      merchantId: json['merchant_id'] as String?,
      receiptNumber: json['receipt_number'] as String?,
      receiptDate: DateTime.parse(json['receipt_date'] as String),
      subtotal: (json['subtotal'] as num).toDouble(),
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num).toDouble(),
      currency: json['currency'] as String,
      taxDetails: json['tax_details'] != null
          ? TaxDetails.fromJson(json['tax_details'] as Map<String, dynamic>)
          : null,
      ocrText: json['ocr_text'] as String?,
      ocrConfidence: (json['ocr_confidence'] as num?)?.toDouble(),
      ocrExtractedData: json['ocr_extracted_data'] as Map<String, dynamic>?,
      imageUrl: json['image_url'] as String?,
      pdfUrl: json['pdf_url'] as String?,
      imageHash: json['image_hash'] as String?,
      category: json['category'] as String?,
      subcategory: json['subcategory'] as String?,
      tags: List<String>.from(json['tags'] as List? ?? []),
      notes: json['notes'] as String?,
      aiAnalysis: json['ai_analysis'] as Map<String, dynamic>?,
      items: json['items'] != null
          ? List<ReceiptItem>.from(
              (json['items'] as List).map((x) => ReceiptItem.fromJson(x))
            )
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert Receipt to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'merchant_id': merchantId,
      'receipt_number': receiptNumber,
      'receipt_date': receiptDate.toIso8601String().split('T')[0],
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
      'currency': currency,
      'tax_details': taxDetails?.toJson(),
      'ocr_text': ocrText,
      'ocr_confidence': ocrConfidence,
      'ocr_extracted_data': ocrExtractedData,
      'image_url': imageUrl,
      'pdf_url': pdfUrl,
      'image_hash': imageHash,
      'category': category,
      'subcategory': subcategory,
      'tags': tags,
      'notes': notes,
      'ai_analysis': aiAnalysis,
    };
  }

  /// Create a copy with updated values
  Receipt copyWith({
    String? merchantId,
    String? receiptNumber,
    DateTime? receiptDate,
    double? subtotal,
    double? taxAmount,
    double? totalAmount,
    String? currency,
    TaxDetails? taxDetails,
    String? ocrText,
    double? ocrConfidence,
    Map<String, dynamic>? ocrExtractedData,
    String? imageUrl,
    String? pdfUrl,
    String? imageHash,
    String? category,
    String? subcategory,
    List<String>? tags,
    String? notes,
    Map<String, dynamic>? aiAnalysis,
    List<ReceiptItem>? items,
  }) {
    return Receipt(
      id: id,
      userId: userId,
      merchantId: merchantId ?? this.merchantId,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      receiptDate: receiptDate ?? this.receiptDate,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      currency: currency ?? this.currency,
      taxDetails: taxDetails ?? this.taxDetails,
      ocrText: ocrText ?? this.ocrText,
      ocrConfidence: ocrConfidence ?? this.ocrConfidence,
      ocrExtractedData: ocrExtractedData ?? this.ocrExtractedData,
      imageUrl: imageUrl ?? this.imageUrl,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      imageHash: imageHash ?? this.imageHash,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
      aiAnalysis: aiAnalysis ?? this.aiAnalysis,
      items: items ?? this.items,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Format total amount with currency
  String get formattedTotal {
    final formatter = NumberFormat.currency(
      symbol: _getCurrencySymbol(currency),
      decimalDigits: 2,
    );
    return formatter.format(totalAmount);
  }

  /// Format receipt date
  String get formattedDate {
    return DateFormat('MMM dd, yyyy').format(receiptDate);
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

  /// Check if receipt has high OCR confidence
  bool get hasHighConfidence => ocrConfidence != null && ocrConfidence! >= 0.8;

  /// Get receipt age in days
  int get ageInDays => DateTime.now().difference(receiptDate).inDays;

  @override
  String toString() {
    return 'Receipt(id: $id, total: $formattedTotal, date: $formattedDate)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Receipt && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Tax Details Model
class TaxDetails {
  final double rate;
  final String type;
  final String? hsnCode;
  final String? gstin;

  TaxDetails({
    required this.rate,
    required this.type,
    this.hsnCode,
    this.gstin,
  });

  factory TaxDetails.fromJson(Map<String, dynamic> json) {
    return TaxDetails(
      rate: (json['rate'] as num).toDouble(),
      type: json['type'] as String,
      hsnCode: json['hsn_code'] as String?,
      gstin: json['gstin'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rate': rate,
      'type': type,
      'hsn_code': hsnCode,
      'gstin': gstin,
    };
  }
}

/// Receipt Item Model
class ReceiptItem {
  final String id;
  final String receiptId;
  final String itemName;
  final double quantity;
  final double unitPrice;
  final double totalPrice;
  final double? taxRate;
  final double? taxAmount;
  final String? hsnCode;
  final String? category;
  final DateTime createdAt;

  ReceiptItem({
    required this.id,
    required this.receiptId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.taxRate,
    this.taxAmount,
    this.hsnCode,
    this.category,
    required this.createdAt,
  });

  factory ReceiptItem.fromJson(Map<String, dynamic> json) {
    return ReceiptItem(
      id: json['id'] as String,
      receiptId: json['receipt_id'] as String,
      itemName: json['item_name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      totalPrice: (json['total_price'] as num).toDouble(),
      taxRate: (json['tax_rate'] as num?)?.toDouble(),
      taxAmount: (json['tax_amount'] as num?)?.toDouble(),
      hsnCode: json['hsn_code'] as String?,
      category: json['category'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'receipt_id': receiptId,
      'item_name': itemName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'tax_rate': taxRate,
      'tax_amount': taxAmount,
      'hsn_code': hsnCode,
      'category': category,
    };
  }

  /// Format unit price with currency
  String formattedUnitPrice(String currency) {
    final formatter = NumberFormat.currency(
      symbol: _getCurrencySymbol(currency),
      decimalDigits: 2,
    );
    return formatter.format(unitPrice);
  }

  /// Format total price with currency
  String formattedTotalPrice(String currency) {
    final formatter = NumberFormat.currency(
      symbol: _getCurrencySymbol(currency),
      decimalDigits: 2,
    );
    return formatter.format(totalPrice);
  }

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
}