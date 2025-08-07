import 'package:flutter/foundation.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:typed_data';

/// OCR Service for receipt text extraction and processing
class OCRService {
  static OCRService? _instance;
  static OCRService get instance => _instance ??= OCRService._internal();
  
  OCRService._internal();

  late final TextRecognizer _textRecognizer;
  late final BarcodeScanner _barcodeScanner;

  /// Initialize OCR service
  Future<void> initialize() async {
    try {
      _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      _barcodeScanner = BarcodeScanner();
      
      if (kDebugMode) {
        print('🔍 OCR Service initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing OCR Service: $e');
      }
      rethrow;
    }
  }

  /// Process image and extract receipt data
  Future<ReceiptOCRResult> processReceiptImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      
      // Perform OCR text recognition
      final recognizedText = await _textRecognizer.processImage(inputImage);
      
      // Scan for barcodes (optional)
      final barcodes = await _barcodeScanner.processImage(inputImage);
      
      // Parse the extracted text
      final parsedData = _parseReceiptText(recognizedText.text);
      
      // Calculate overall confidence
      final confidence = _calculateConfidence(recognizedText);
      
      return ReceiptOCRResult(
        rawText: recognizedText.text,
        confidence: confidence,
        parsedData: parsedData,
        barcodes: barcodes.map((b) => b.rawValue ?? '').toList(),
        blocks: recognizedText.blocks.map((block) => OCRTextBlock(
          text: block.text,
          boundingBox: block.boundingBox,
          confidence: block.confidence ?? 0.0,
        )).toList(),
      );
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error processing receipt image: $e');
      }
      rethrow;
    }
  }

  /// Parse extracted text into structured receipt data
  ReceiptParsedData _parseReceiptText(String text) {
    final lines = text.split('\n').where((line) => line.trim().isNotEmpty).toList();
    
    // Initialize parsed data
    String? merchantName;
    String? receiptNumber;
    DateTime? date;
    double? totalAmount;
    double? taxAmount;
    String? currency;
    List<ReceiptLineItem> items = [];
    Map<String, dynamic> additionalData = {};

    // Parse merchant name (usually in first few lines)
    merchantName = _extractMerchantName(lines);
    
    // Parse receipt number
    receiptNumber = _extractReceiptNumber(text);
    
    // Parse date
    date = _extractDate(text);
    
    // Parse amounts
    final amounts = _extractAmounts(text);
    totalAmount = amounts['total'];
    taxAmount = amounts['tax'];
    
    // Detect currency
    currency = _detectCurrency(text);
    
    // Extract line items
    items = _extractLineItems(lines);
    
    // Extract additional data (phone, address, etc.)
    additionalData = _extractAdditionalData(text);

    return ReceiptParsedData(
      merchantName: merchantName,
      receiptNumber: receiptNumber,
      date: date,
      totalAmount: totalAmount,
      taxAmount: taxAmount,
      subtotal: totalAmount != null && taxAmount != null 
          ? totalAmount - taxAmount 
          : totalAmount,
      currency: currency ?? 'USD',
      items: items,
      additionalData: additionalData,
    );
  }

  /// Extract merchant name from receipt
  String? _extractMerchantName(List<String> lines) {
    // Look for merchant name in first 5 lines
    for (int i = 0; i < (lines.length < 5 ? lines.length : 5); i++) {
      final line = lines[i].trim();
      
      // Skip common non-merchant patterns
      if (line.length < 3 || 
          _isNumeric(line) || 
          line.toLowerCase().contains('receipt') ||
          line.toLowerCase().contains('invoice') ||
          line.toLowerCase().contains('bill')) {
        continue;
      }
      
      // If line contains letters and is substantial, likely merchant name
      if (line.length > 5 && RegExp(r'[a-zA-Z]').hasMatch(line)) {
        return line;
      }
    }
    
    return null;
  }

  /// Extract receipt number
  String? _extractReceiptNumber(String text) {
    final patterns = [
      RegExp(r'(?:receipt|bill|invoice|ref|order)(?:\s*(?:no|number|#))?[\s:]*([a-z0-9\-]+)', caseSensitive: false),
      RegExp(r'#(\w+)', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(1);
      }
    }
    
    return null;
  }

  /// Extract date from receipt
  DateTime? _extractDate(String text) {
    final patterns = [
      RegExp(r'(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})'),
      RegExp(r'(\d{2,4}[-/]\d{1,2}[-/]\d{1,2})'),
      RegExp(r'(\w+\s+\d{1,2},?\s+\d{4})'),
      RegExp(r'(\d{1,2}\s+\w+\s+\d{4})'),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        try {
          final dateStr = match.group(1)!;
          return _parseDate(dateStr);
        } catch (e) {
          continue;
        }
      }
    }
    
    return null;
  }

  /// Parse date string into DateTime
  DateTime? _parseDate(String dateStr) {
    final formats = [
      'MM/dd/yyyy', 'dd/MM/yyyy', 'yyyy/MM/dd',
      'MM-dd-yyyy', 'dd-MM-yyyy', 'yyyy-MM-dd',
      'MMM dd, yyyy', 'dd MMM yyyy',
    ];
    
    for (final format in formats) {
      try {
        // Simple parsing - would use intl package in production
        return DateTime.tryParse(dateStr.replaceAll(RegExp(r'[^\d\-/]'), ''));
      } catch (e) {
        continue;
      }
    }
    
    return null;
  }

  /// Extract amounts (total, tax, subtotal)
  Map<String, double?> _extractAmounts(String text) {
    double? total;
    double? tax;
    
    // Look for total amount
    final totalPatterns = [
      RegExp(r'(?:total|amount due|balance)[\s:]*([£$€₹¥]?\s*\d+\.?\d*)', caseSensitive: false),
      RegExp(r'([£$€₹¥]?\s*\d+\.?\d*)[\s]*(?:total)', caseSensitive: false),
    ];
    
    for (final pattern in totalPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        total = _parseAmount(match.group(1)!);
        break;
      }
    }
    
    // Look for tax amount
    final taxPatterns = [
      RegExp(r'(?:tax|vat|gst)[\s:]*([£$€₹¥]?\s*\d+\.?\d*)', caseSensitive: false),
      RegExp(r'([£$€₹¥]?\s*\d+\.?\d*)[\s]*(?:tax|vat|gst)', caseSensitive: false),
    ];
    
    for (final pattern in taxPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        tax = _parseAmount(match.group(1)!);
        break;
      }
    }
    
    return {'total': total, 'tax': tax};
  }

  /// Parse amount string to double
  double? _parseAmount(String amountStr) {
    try {
      // Remove currency symbols and spaces
      final cleaned = amountStr.replaceAll(RegExp(r'[£$€₹¥,\s]'), '');
      return double.tryParse(cleaned);
    } catch (e) {
      return null;
    }
  }

  /// Detect currency from text
  String? _detectCurrency(String text) {
    final currencyPatterns = {
      r'\$': 'USD',
      r'£': 'GBP',
      r'€': 'EUR',
      r'₹': 'INR',
      r'¥': 'JPY',
      r'USD': 'USD',
      r'GBP': 'GBP',
      r'EUR': 'EUR',
      r'INR': 'INR',
      r'JPY': 'JPY',
    };
    
    for (final entry in currencyPatterns.entries) {
      if (RegExp(entry.key, caseSensitive: false).hasMatch(text)) {
        return entry.value;
      }
    }
    
    return null;
  }

  /// Extract line items from receipt
  List<ReceiptLineItem> _extractLineItems(List<String> lines) {
    final items = <ReceiptLineItem>[];
    
    for (final line in lines) {
      // Look for lines with item name and price
      final itemMatch = RegExp(r'(.+?)[\s]+([£$€₹¥]?\s*\d+\.?\d*)$').firstMatch(line.trim());
      
      if (itemMatch != null && !_isHeaderOrFooterLine(line)) {
        final itemName = itemMatch.group(1)?.trim();
        final priceStr = itemMatch.group(2)?.trim();
        
        if (itemName != null && priceStr != null && itemName.isNotEmpty) {
          final price = _parseAmount(priceStr);
          
          if (price != null && price > 0) {
            items.add(ReceiptLineItem(
              name: itemName,
              price: price,
              quantity: 1.0, // Default quantity
            ));
          }
        }
      }
    }
    
    return items;
  }

  /// Extract additional data (phone, address, etc.)
  Map<String, dynamic> _extractAdditionalData(String text) {
    final data = <String, dynamic>{};
    
    // Extract phone number
    final phonePattern = RegExp(r'(?:tel|phone|call)[\s:]*([+]?[\d\s\-\(\)]+)', caseSensitive: false);
    final phoneMatch = phonePattern.firstMatch(text);
    if (phoneMatch != null) {
      data['phone'] = phoneMatch.group(1)?.trim();
    }
    
    // Extract email
    final emailPattern = RegExp(r'([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})');
    final emailMatch = emailPattern.firstMatch(text);
    if (emailMatch != null) {
      data['email'] = emailMatch.group(1);
    }
    
    // Extract website
    final websitePattern = RegExp(r'(?:www\.|https?://)?([a-zA-Z0-9.-]+\.[a-zA-Z]{2,})', caseSensitive: false);
    final websiteMatch = websitePattern.firstMatch(text);
    if (websiteMatch != null) {
      data['website'] = websiteMatch.group(1);
    }
    
    return data;
  }

  /// Calculate overall confidence score
  double _calculateConfidence(RecognizedText recognizedText) {
    if (recognizedText.blocks.isEmpty) return 0.0;
    
    double totalConfidence = 0.0;
    int blockCount = 0;
    
    for (final block in recognizedText.blocks) {
      if (block.confidence != null) {
        totalConfidence += block.confidence!;
        blockCount++;
      }
    }
    
    return blockCount > 0 ? totalConfidence / blockCount : 0.0;
  }

  /// Check if line is numeric
  bool _isNumeric(String str) {
    return double.tryParse(str.replaceAll(RegExp(r'[^\d.]'), '')) != null;
  }

  /// Check if line is header or footer (skip for items)
  bool _isHeaderOrFooterLine(String line) {
    final lowerLine = line.toLowerCase();
    return lowerLine.contains('receipt') ||
           lowerLine.contains('thank you') ||
           lowerLine.contains('total') ||
           lowerLine.contains('subtotal') ||
           lowerLine.contains('tax') ||
           lowerLine.contains('change') ||
           lowerLine.contains('card') ||
           lowerLine.contains('cash');
  }

  /// Dispose resources
  Future<void> dispose() async {
    try {
      await _textRecognizer.close();
      await _barcodeScanner.close();
      
      if (kDebugMode) {
        print('🗑️ OCR Service disposed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error disposing OCR Service: $e');
      }
    }
  }
}

/// OCR Result containing all extracted data
class ReceiptOCRResult {
  final String rawText;
  final double confidence;
  final ReceiptParsedData parsedData;
  final List<String> barcodes;
  final List<OCRTextBlock> blocks;

  ReceiptOCRResult({
    required this.rawText,
    required this.confidence,
    required this.parsedData,
    required this.barcodes,
    required this.blocks,
  });
}

/// Parsed receipt data structure
class ReceiptParsedData {
  final String? merchantName;
  final String? receiptNumber;
  final DateTime? date;
  final double? totalAmount;
  final double? taxAmount;
  final double? subtotal;
  final String currency;
  final List<ReceiptLineItem> items;
  final Map<String, dynamic> additionalData;

  ReceiptParsedData({
    this.merchantName,
    this.receiptNumber,
    this.date,
    this.totalAmount,
    this.taxAmount,
    this.subtotal,
    required this.currency,
    required this.items,
    required this.additionalData,
  });
}

/// Receipt line item
class ReceiptLineItem {
  final String name;
  final double price;
  final double quantity;

  ReceiptLineItem({
    required this.name,
    required this.price,
    required this.quantity,
  });
}

/// OCR Text Block
class OCRTextBlock {
  final String text;
  final Rect boundingBox;
  final double confidence;

  OCRTextBlock({
    required this.text,
    required this.boundingBox,
    required this.confidence,
  });
}