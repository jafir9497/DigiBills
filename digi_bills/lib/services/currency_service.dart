import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Currency Service for exchange rates and multi-currency support
class CurrencyService {
  static CurrencyService? _instance;
  static CurrencyService get instance => _instance ??= CurrencyService._internal();
  
  CurrencyService._internal();

  final Dio _dio = Dio();
  late SharedPreferences _prefs;
  
  // Cache for exchange rates
  Map<String, Map<String, double>> _exchangeRatesCache = {};
  DateTime? _lastUpdateTime;
  
  // Supported currencies with their symbols and info
  static const Map<String, CurrencyInfo> supportedCurrencies = {
    'USD': CurrencyInfo('US Dollar', '\$', 'United States', 2),
    'EUR': CurrencyInfo('Euro', '€', 'European Union', 2),
    'GBP': CurrencyInfo('British Pound', '£', 'United Kingdom', 2),
    'INR': CurrencyInfo('Indian Rupee', '₹', 'India', 2),
    'CAD': CurrencyInfo('Canadian Dollar', 'C\$', 'Canada', 2),
    'AUD': CurrencyInfo('Australian Dollar', 'A\$', 'Australia', 2),
    'JPY': CurrencyInfo('Japanese Yen', '¥', 'Japan', 0),
    'CHF': CurrencyInfo('Swiss Franc', 'CHF', 'Switzerland', 2),
    'CNY': CurrencyInfo('Chinese Yuan', '¥', 'China', 2),
    'SGD': CurrencyInfo('Singapore Dollar', 'S\$', 'Singapore', 2),
  };

  /// Initialize currency service
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadCachedRates();
      
      if (kDebugMode) {
        print('💰 Currency Service initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing Currency Service: $e');
      }
      rethrow;
    }
  }

  /// Get current exchange rates for a base currency
  Future<Map<String, double>> getExchangeRates(String baseCurrency) async {
    try {
      // Check if we have recent cached rates
      if (_hasRecentRates(baseCurrency)) {
        return _exchangeRatesCache[baseCurrency] ?? {};
      }

      // Fetch fresh rates from API
      final rates = await _fetchExchangeRates(baseCurrency);
      
      // Cache the rates
      _exchangeRatesCache[baseCurrency] = rates;
      _lastUpdateTime = DateTime.now();
      await _saveCachedRates();
      
      return rates;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting exchange rates: $e');
      }
      
      // Return cached rates as fallback
      return _exchangeRatesCache[baseCurrency] ?? {};
    }
  }

  /// Convert amount from one currency to another
  Future<double> convertCurrency({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
  }) async {
    if (fromCurrency == toCurrency) return amount;

    try {
      final rates = await getExchangeRates(fromCurrency);
      final rate = rates[toCurrency];
      
      if (rate == null) {
        throw Exception('Exchange rate not available for $fromCurrency to $toCurrency');
      }
      
      return amount * rate;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error converting currency: $e');
      }
      rethrow;
    }
  }

  /// Get formatted currency string
  String formatCurrency(double amount, String currencyCode) {
    final currencyInfo = supportedCurrencies[currencyCode];
    if (currencyInfo == null) return '$currencyCode $amount';

    final formatter = NumberFormat.currency(
      symbol: currencyInfo.symbol,
      decimalDigits: currencyInfo.decimalPlaces,
      locale: _getLocaleForCurrency(currencyCode),
    );
    
    return formatter.format(amount);
  }

  /// Get currency symbol
  String getCurrencySymbol(String currencyCode) {
    return supportedCurrencies[currencyCode]?.symbol ?? currencyCode;
  }

  /// Get currency name
  String getCurrencyName(String currencyCode) {
    return supportedCurrencies[currencyCode]?.name ?? currencyCode;
  }

  /// Check if currency is supported
  bool isCurrencySupported(String currencyCode) {
    return supportedCurrencies.containsKey(currencyCode);
  }

  /// Get list of supported currency codes
  List<String> getSupportedCurrencies() {
    return supportedCurrencies.keys.toList();
  }

  /// Detect currency from text/symbol
  String? detectCurrencyFromText(String text) {
    // Check for currency symbols first
    for (final entry in supportedCurrencies.entries) {
      if (text.contains(entry.value.symbol) || text.toUpperCase().contains(entry.key)) {
        return entry.key;
      }
    }
    
    // Check for currency names
    for (final entry in supportedCurrencies.entries) {
      if (text.toLowerCase().contains(entry.value.name.toLowerCase())) {
        return entry.key;
      }
    }
    
    return null;
  }

  /// Fetch exchange rates from API
  Future<Map<String, double>> _fetchExchangeRates(String baseCurrency) async {
    try {
      // Using a free exchange rate API (replace with your preferred service)
      const apiUrl = 'https://api.exchangerate-api.com/v4/latest';
      
      final response = await _dio.get('$apiUrl/$baseCurrency');
      
      if (response.statusCode == 200) {
        final data = response.data;
        final rates = Map<String, double>.from(data['rates'] ?? {});
        
        if (kDebugMode) {
          print('✅ Fetched exchange rates for $baseCurrency');
        }
        
        return rates;
      }
      
      throw Exception('Failed to fetch exchange rates: ${response.statusCode}');
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching exchange rates from API: $e');
      }
      
      // Return fallback rates for common currencies
      return _getFallbackRates(baseCurrency);
    }
  }

  /// Get fallback exchange rates
  Map<String, double> _getFallbackRates(String baseCurrency) {
    // Basic fallback rates (you should update these periodically)
    const fallbackRates = {
      'USD': {
        'EUR': 0.85,
        'GBP': 0.73,
        'INR': 83.0,
        'JPY': 110.0,
        'CAD': 1.25,
        'AUD': 1.35,
        'CHF': 0.92,
        'CNY': 6.45,
        'SGD': 1.35,
      },
      'EUR': {
        'USD': 1.18,
        'GBP': 0.86,
        'INR': 97.6,
        'JPY': 129.4,
        'CAD': 1.47,
        'AUD': 1.59,
        'CHF': 1.08,
        'CNY': 7.6,
        'SGD': 1.59,
      },
      'INR': {
        'USD': 0.012,
        'EUR': 0.010,
        'GBP': 0.0088,
        'JPY': 1.33,
        'CAD': 0.015,
        'AUD': 0.016,
        'CHF': 0.011,
        'CNY': 0.078,
        'SGD': 0.016,
      },
    };
    
    return Map<String, double>.from(fallbackRates[baseCurrency] ?? {});
  }

  /// Check if we have recent cached rates
  bool _hasRecentRates(String baseCurrency) {
    if (_lastUpdateTime == null || !_exchangeRatesCache.containsKey(baseCurrency)) {
      return false;
    }
    
    final hoursSinceUpdate = DateTime.now().difference(_lastUpdateTime!).inHours;
    return hoursSinceUpdate < 6; // Cache for 6 hours
  }

  /// Load cached rates from storage
  Future<void> _loadCachedRates() async {
    try {
      final cachedData = _prefs.getString('exchange_rates_cache');
      final lastUpdateString = _prefs.getString('exchange_rates_last_update');
      
      if (cachedData != null && lastUpdateString != null) {
        final data = json.decode(cachedData) as Map<String, dynamic>;
        _exchangeRatesCache = data.map(
          (key, value) => MapEntry(key, Map<String, double>.from(value)),
        );
        _lastUpdateTime = DateTime.parse(lastUpdateString);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading cached rates: $e');
      }
    }
  }

  /// Save cached rates to storage
  Future<void> _saveCachedRates() async {
    try {
      final dataToCache = _exchangeRatesCache.map(
        (key, value) => MapEntry(key, value),
      );
      
      await _prefs.setString('exchange_rates_cache', json.encode(dataToCache));
      
      if (_lastUpdateTime != null) {
        await _prefs.setString('exchange_rates_last_update', _lastUpdateTime!.toIso8601String());
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving cached rates: $e');
      }
    }
  }

  /// Get appropriate locale for currency formatting
  String _getLocaleForCurrency(String currencyCode) {
    switch (currencyCode) {
      case 'USD': return 'en_US';
      case 'EUR': return 'en_EU';
      case 'GBP': return 'en_GB';
      case 'INR': return 'en_IN';
      case 'JPY': return 'ja_JP';
      case 'CAD': return 'en_CA';
      case 'AUD': return 'en_AU';
      case 'CHF': return 'de_CH';
      case 'CNY': return 'zh_CN';
      case 'SGD': return 'en_SG';
      default: return 'en_US';
    }
  }

  /// Get currency conversion history
  Future<List<CurrencyConversion>> getConversionHistory() async {
    try {
      final historyJson = _prefs.getString('currency_conversion_history');
      if (historyJson == null) return [];
      
      final historyList = json.decode(historyJson) as List;
      return historyList.map((item) => CurrencyConversion.fromJson(item)).toList();
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading conversion history: $e');
      }
      return [];
    }
  }

  /// Save currency conversion to history
  Future<void> saveConversionToHistory(CurrencyConversion conversion) async {
    try {
      final history = await getConversionHistory();
      history.insert(0, conversion);
      
      // Keep only last 100 conversions
      if (history.length > 100) {
        history.removeRange(100, history.length);
      }
      
      final historyJson = json.encode(history.map((c) => c.toJson()).toList());
      await _prefs.setString('currency_conversion_history', historyJson);
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving conversion to history: $e');
      }
    }
  }

  /// Clear currency cache
  Future<void> clearCache() async {
    try {
      _exchangeRatesCache.clear();
      _lastUpdateTime = null;
      
      await _prefs.remove('exchange_rates_cache');
      await _prefs.remove('exchange_rates_last_update');
      
      if (kDebugMode) {
        print('✅ Currency cache cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error clearing currency cache: $e');
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _dio.close();
  }
}

/// Currency Information Model
class CurrencyInfo {
  final String name;
  final String symbol;
  final String country;
  final int decimalPlaces;

  const CurrencyInfo(this.name, this.symbol, this.country, this.decimalPlaces);
}

/// Currency Conversion Model
class CurrencyConversion {
  final double amount;
  final String fromCurrency;
  final String toCurrency;
  final double convertedAmount;
  final double exchangeRate;
  final DateTime timestamp;

  CurrencyConversion({
    required this.amount,
    required this.fromCurrency,
    required this.toCurrency,
    required this.convertedAmount,
    required this.exchangeRate,
    required this.timestamp,
  });

  factory CurrencyConversion.fromJson(Map<String, dynamic> json) {
    return CurrencyConversion(
      amount: (json['amount'] as num).toDouble(),
      fromCurrency: json['fromCurrency'] as String,
      toCurrency: json['toCurrency'] as String,
      convertedAmount: (json['convertedAmount'] as num).toDouble(),
      exchangeRate: (json['exchangeRate'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'fromCurrency': fromCurrency,
      'toCurrency': toCurrency,
      'convertedAmount': convertedAmount,
      'exchangeRate': exchangeRate,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}