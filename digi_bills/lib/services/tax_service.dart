import 'package:flutter/foundation.dart';

/// Tax Service for handling multi-country tax calculations
class TaxService {
  static TaxService? _instance;
  static TaxService get instance => _instance ??= TaxService._internal();
  
  TaxService._internal();

  /// Calculate tax for Indian GST system
  TaxCalculationResult calculateIndianGST({
    required double amount,
    required String hsnCode,
    required String? gstin,
    String? stateCode,
  }) {
    final gstRate = _getGSTRateByHSN(hsnCode);
    final taxAmount = amount * (gstRate / 100);
    
    // For interstate transactions (different state codes in GSTIN)
    final isInterstate = gstin != null && stateCode != null && 
                        !gstin.startsWith(stateCode);
    
    Map<String, double> breakup = {};
    
    if (isInterstate) {
      // IGST (Integrated GST)
      breakup['IGST'] = taxAmount;
    } else {
      // CGST + SGST (Central GST + State GST)
      breakup['CGST'] = taxAmount / 2;
      breakup['SGST'] = taxAmount / 2;
    }
    
    return TaxCalculationResult(
      originalAmount: amount,
      taxRate: gstRate,
      taxAmount: taxAmount,
      totalAmount: amount + taxAmount,
      taxType: 'GST',
      taxBreakup: breakup,
      hsnCode: hsnCode,
      gstin: gstin,
      metadata: {
        'isInterstate': isInterstate,
        'stateCode': stateCode,
      },
    );
  }

  /// Calculate tax for US Sales Tax
  TaxCalculationResult calculateUSSalesTax({
    required double amount,
    required String stateCode,
    String? cityCode,
  }) {
    final taxRate = _getUSSalesTaxRate(stateCode, cityCode);
    final taxAmount = amount * (taxRate / 100);
    
    Map<String, double> breakup = {
      'Sales Tax': taxAmount,
    };
    
    return TaxCalculationResult(
      originalAmount: amount,
      taxRate: taxRate,
      taxAmount: taxAmount,
      totalAmount: amount + taxAmount,
      taxType: 'Sales Tax',
      taxBreakup: breakup,
      metadata: {
        'stateCode': stateCode,
        'cityCode': cityCode,
      },
    );
  }

  /// Calculate VAT for European countries
  TaxCalculationResult calculateVAT({
    required double amount,
    required String countryCode,
    String? productCategory,
  }) {
    final vatRate = _getVATRate(countryCode, productCategory);
    final taxAmount = amount * (vatRate / 100);
    
    Map<String, double> breakup = {
      'VAT': taxAmount,
    };
    
    return TaxCalculationResult(
      originalAmount: amount,
      taxRate: vatRate,
      taxAmount: taxAmount,
      totalAmount: amount + taxAmount,
      taxType: 'VAT',
      taxBreakup: breakup,
      metadata: {
        'countryCode': countryCode,
        'productCategory': productCategory,
      },
    );
  }

  /// Validate Indian GSTIN number
  bool validateGSTIN(String gstin) {
    if (gstin.length != 15) return false;
    
    // GSTIN format: 22AAAAA0000A1Z5
    final gstinPattern = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$');
    
    if (!gstinPattern.hasMatch(gstin)) return false;
    
    // Validate check digit (simplified)
    return _validateGSTINCheckDigit(gstin);
  }

  /// Validate Indian PAN number
  bool validatePAN(String pan) {
    if (pan.length != 10) return false;
    
    final panPattern = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
    return panPattern.hasMatch(pan);
  }

  /// Get GST rate by HSN code
  double _getGSTRateByHSN(String hsnCode) {
    // Common HSN codes and their GST rates
    final hsnRates = <String, double>{
      // Food items
      '0401': 0.0,   // Milk
      '0402': 5.0,   // Milk powder
      '0403': 5.0,   // Yogurt
      '1006': 0.0,   // Rice
      '1005': 0.0,   // Maize
      
      // Processed food
      '1905': 12.0,  // Bread, biscuits
      '2106': 18.0,  // Food preparations
      '2202': 12.0,  // Soft drinks
      '2203': 28.0,  // Beer
      '2208': 28.0,  // Spirits
      
      // Textiles
      '5208': 5.0,   // Cotton fabrics
      '6110': 12.0,  // Sweaters
      '6203': 12.0,  // Men's suits
      
      // Electronics
      '8517': 18.0,  // Mobile phones
      '8528': 18.0,  // TV sets
      '8471': 18.0,  // Computers
      '8504': 18.0,  // Electrical transformers
      
      // Vehicles
      '8703': 28.0,  // Motor cars
      '8711': 28.0,  // Motorcycles
      '8712': 12.0,  // Bicycles
      
      // Medicines
      '3003': 12.0,  // Medicaments
      '3004': 12.0,  // Pharmaceutical products
      
      // Services
      '9983': 18.0,  // General services
      '9984': 12.0,  // Restaurant services (AC)
      '9985': 5.0,   // Restaurant services (non-AC)
    };
    
    // Try exact match first
    if (hsnRates.containsKey(hsnCode)) {
      return hsnRates[hsnCode]!;
    }
    
    // Try partial match (first 4 digits)
    if (hsnCode.length >= 4) {
      final shortCode = hsnCode.substring(0, 4);
      if (hsnRates.containsKey(shortCode)) {
        return hsnRates[shortCode]!;
      }
    }
    
    // Try chapter level (first 2 digits)
    if (hsnCode.length >= 2) {
      final chapterCode = hsnCode.substring(0, 2);
      final chapterRates = <String, double>{
        '01': 0.0,   // Live animals
        '02': 0.0,   // Meat
        '03': 0.0,   // Fish
        '04': 0.0,   // Dairy products
        '07': 0.0,   // Vegetables
        '08': 0.0,   // Fruits
        '10': 0.0,   // Cereals
        '15': 5.0,   // Animal/vegetable fats
        '19': 12.0,  // Cereal preparations
        '22': 18.0,  // Beverages
        '25': 5.0,   // Salt, cement
        '27': 5.0,   // Mineral fuels
        '30': 12.0,  // Pharmaceutical products
        '52': 5.0,   // Cotton
        '61': 12.0,  // Knitted apparel
        '84': 18.0,  // Machinery
        '85': 18.0,  // Electrical machinery
        '87': 28.0,  // Vehicles
        '94': 18.0,  // Furniture
      };
      
      if (chapterRates.containsKey(chapterCode)) {
        return chapterRates[chapterCode]!;
      }
    }
    
    // Default GST rate
    return 18.0;
  }

  /// Get US Sales Tax rate by state
  double _getUSSalesTaxRate(String stateCode, String? cityCode) {
    final stateTaxRates = <String, double>{
      'AL': 4.0,  // Alabama
      'AK': 0.0,  // Alaska
      'AZ': 5.6,  // Arizona
      'AR': 6.5,  // Arkansas
      'CA': 7.25, // California
      'CO': 2.9,  // Colorado
      'CT': 6.35, // Connecticut
      'DE': 0.0,  // Delaware
      'FL': 6.0,  // Florida
      'GA': 4.0,  // Georgia
      'HI': 4.0,  // Hawaii
      'ID': 6.0,  // Idaho
      'IL': 6.25, // Illinois
      'IN': 7.0,  // Indiana
      'IA': 6.0,  // Iowa
      'KS': 6.5,  // Kansas
      'KY': 6.0,  // Kentucky
      'LA': 4.45, // Louisiana
      'ME': 5.5,  // Maine
      'MD': 6.0,  // Maryland
      'MA': 6.25, // Massachusetts
      'MI': 6.0,  // Michigan
      'MN': 6.875, // Minnesota
      'MS': 7.0,  // Mississippi
      'MO': 4.225, // Missouri
      'MT': 0.0,  // Montana
      'NE': 5.5,  // Nebraska
      'NV': 6.85, // Nevada
      'NH': 0.0,  // New Hampshire
      'NJ': 6.625, // New Jersey
      'NM': 5.125, // New Mexico
      'NY': 8.0,  // New York
      'NC': 4.75, // North Carolina
      'ND': 5.0,  // North Dakota
      'OH': 5.75, // Ohio
      'OK': 4.5,  // Oklahoma
      'OR': 0.0,  // Oregon
      'PA': 6.0,  // Pennsylvania
      'RI': 7.0,  // Rhode Island
      'SC': 6.0,  // South Carolina
      'SD': 4.5,  // South Dakota
      'TN': 7.0,  // Tennessee
      'TX': 6.25, // Texas
      'UT': 5.95, // Utah
      'VT': 6.0,  // Vermont
      'VA': 5.3,  // Virginia
      'WA': 6.5,  // Washington
      'WV': 6.0,  // West Virginia
      'WI': 5.0,  // Wisconsin
      'WY': 4.0,  // Wyoming
    };
    
    return stateTaxRates[stateCode] ?? 0.0;
  }

  /// Get VAT rate by country
  double _getVATRate(String countryCode, String? productCategory) {
    final standardVATRates = <String, double>{
      'AT': 20.0, // Austria
      'BE': 21.0, // Belgium
      'BG': 20.0, // Bulgaria
      'HR': 25.0, // Croatia
      'CY': 19.0, // Cyprus
      'CZ': 21.0, // Czech Republic
      'DK': 25.0, // Denmark
      'EE': 20.0, // Estonia
      'FI': 24.0, // Finland
      'FR': 20.0, // France
      'DE': 19.0, // Germany
      'GR': 24.0, // Greece
      'HU': 27.0, // Hungary
      'IE': 23.0, // Ireland
      'IT': 22.0, // Italy
      'LV': 21.0, // Latvia
      'LT': 21.0, // Lithuania
      'LU': 17.0, // Luxembourg
      'MT': 18.0, // Malta
      'NL': 21.0, // Netherlands
      'PL': 23.0, // Poland
      'PT': 23.0, // Portugal
      'RO': 19.0, // Romania
      'SK': 20.0, // Slovakia
      'SI': 22.0, // Slovenia
      'ES': 21.0, // Spain
      'SE': 25.0, // Sweden
      'GB': 20.0, // United Kingdom
      'NO': 25.0, // Norway
      'CH': 7.7,  // Switzerland
    };
    
    // Apply reduced rates for certain categories
    if (productCategory != null) {
      final reducedCategories = ['food', 'medicine', 'books', 'children'];
      if (reducedCategories.any((cat) => productCategory.toLowerCase().contains(cat))) {
        final rate = standardVATRates[countryCode] ?? 0.0;
        return rate * 0.5; // Typically reduced rate is around half
      }
    }
    
    return standardVATRates[countryCode] ?? 0.0;
  }

  /// Validate GSTIN check digit (simplified implementation)
  bool _validateGSTINCheckDigit(String gstin) {
    // This is a simplified validation - full implementation would include
    // the complete check digit algorithm
    return gstin.length == 15 && gstin[14].isNotEmpty;
  }

  /// Get tax type by country
  String getTaxTypeByCountry(String countryCode) {
    if (countryCode == 'IN') return 'GST';
    if (countryCode == 'US') return 'Sales Tax';
    
    // European countries generally use VAT
    final vatCountries = [
      'AT', 'BE', 'BG', 'HR', 'CY', 'CZ', 'DK', 'EE', 'FI', 'FR',
      'DE', 'GR', 'HU', 'IE', 'IT', 'LV', 'LT', 'LU', 'MT', 'NL',
      'PL', 'PT', 'RO', 'SK', 'SI', 'ES', 'SE', 'GB', 'NO', 'CH'
    ];
    
    if (vatCountries.contains(countryCode)) return 'VAT';
    
    return 'Tax';
  }

  /// Get common HSN codes for suggestions
  List<HSNCodeInfo> getCommonHSNCodes() {
    return [
      HSNCodeInfo('0401', 'Milk and cream', 0.0),
      HSNCodeInfo('1905', 'Bread, biscuits, cakes', 12.0),
      HSNCodeInfo('2106', 'Food preparations', 18.0),
      HSNCodeInfo('3003', 'Medicaments', 12.0),
      HSNCodeInfo('5208', 'Cotton fabrics', 5.0),
      HSNCodeInfo('6110', 'Sweaters, pullovers', 12.0),
      HSNCodeInfo('8517', 'Telephone sets, mobile phones', 18.0),
      HSNCodeInfo('8528', 'Television receivers', 18.0),
      HSNCodeInfo('8703', 'Motor cars', 28.0),
      HSNCodeInfo('9983', 'Services by way of general insurance', 18.0),
    ];
  }
}

/// Tax Calculation Result
class TaxCalculationResult {
  final double originalAmount;
  final double taxRate;
  final double taxAmount;
  final double totalAmount;
  final String taxType;
  final Map<String, double> taxBreakup;
  final String? hsnCode;
  final String? gstin;
  final Map<String, dynamic> metadata;

  TaxCalculationResult({
    required this.originalAmount,
    required this.taxRate,
    required this.taxAmount,
    required this.totalAmount,
    required this.taxType,
    required this.taxBreakup,
    this.hsnCode,
    this.gstin,
    this.metadata = const {},
  });

  /// Get formatted tax summary
  String getFormattedSummary() {
    final buffer = StringBuffer();
    buffer.writeln('Original Amount: ${originalAmount.toStringAsFixed(2)}');
    buffer.writeln('Tax Rate: ${taxRate.toStringAsFixed(2)}%');
    
    for (final entry in taxBreakup.entries) {
      buffer.writeln('${entry.key}: ${entry.value.toStringAsFixed(2)}');
    }
    
    buffer.writeln('Total Amount: ${totalAmount.toStringAsFixed(2)}');
    return buffer.toString();
  }
}

/// HSN Code Information
class HSNCodeInfo {
  final String code;
  final String description;
  final double gstRate;

  HSNCodeInfo(this.code, this.description, this.gstRate);
}