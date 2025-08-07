import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../services/currency_service.dart';
import '../controllers/auth_controller.dart';

/// Currency Controller using GetX
class CurrencyController extends GetxController {
  static CurrencyController get instance => Get.find();
  
  final _currencyService = CurrencyService.instance;
  final _authController = Get.find<AuthController>();

  // Reactive variables
  final RxString _selectedCurrency = 'USD'.obs;
  final RxMap<String, double> _exchangeRates = <String, double>{}.obs;
  final RxBool _isLoading = false.obs;
  final RxList<CurrencyConversion> _conversionHistory = <CurrencyConversion>[].obs;
  final RxDouble _conversionAmount = 0.0.obs;
  final RxString _fromCurrency = 'USD'.obs;
  final RxString _toCurrency = 'EUR'.obs;
  final RxDouble _convertedAmount = 0.0.obs;

  // Getters
  String get selectedCurrency => _selectedCurrency.value;
  Map<String, double> get exchangeRates => _exchangeRates;
  bool get isLoading => _isLoading.value;
  List<CurrencyConversion> get conversionHistory => _conversionHistory;
  double get conversionAmount => _conversionAmount.value;
  String get fromCurrency => _fromCurrency.value;
  String get toCurrency => _toCurrency.value;
  double get convertedAmount => _convertedAmount.value;

  @override
  void onInit() {
    super.onInit();
    _initializeCurrency();
  }

  /// Initialize currency settings
  Future<void> _initializeCurrency() async {
    try {
      await _currencyService.initialize();
      
      // Load user's preferred currency
      final userProfile = _authController.userProfile;
      if (userProfile != null) {
        _selectedCurrency.value = userProfile.defaultCurrency;
        _fromCurrency.value = userProfile.defaultCurrency;
      }
      
      // Load exchange rates for selected currency
      await loadExchangeRates();
      
      // Load conversion history
      await loadConversionHistory();
      
      if (kDebugMode) {
        print('💰 Currency Controller initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing Currency Controller: $e');
      }
    }
  }

  /// Load exchange rates for current currency
  Future<void> loadExchangeRates() async {
    try {
      _isLoading.value = true;
      
      final rates = await _currencyService.getExchangeRates(_selectedCurrency.value);
      _exchangeRates.assignAll(rates);
      
      if (kDebugMode) {
        print('✅ Loaded ${rates.length} exchange rates for ${_selectedCurrency.value}');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading exchange rates: $e');
      }
      
      Get.snackbar(
        'Currency Error',
        'Failed to load exchange rates. Using cached data.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      _isLoading.value = false;
    }
  }

  /// Change selected currency
  Future<void> changeSelectedCurrency(String currencyCode) async {
    if (_selectedCurrency.value == currencyCode) return;
    
    try {
      _selectedCurrency.value = currencyCode;
      _fromCurrency.value = currencyCode;
      
      // Update user profile
      final userProfile = _authController.userProfile;
      if (userProfile != null) {
        final updatedProfile = userProfile.copyWith(defaultCurrency: currencyCode);
        await _authController.updateProfile(updatedProfile);
      }
      
      // Reload exchange rates
      await loadExchangeRates();
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error changing currency: $e');
      }
    }
  }

  /// Convert currency
  Future<void> convertCurrency() async {
    if (_conversionAmount.value <= 0) {
      Get.snackbar(
        'Invalid Amount',
        'Please enter a valid amount to convert',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      _isLoading.value = true;
      
      final converted = await _currencyService.convertCurrency(
        amount: _conversionAmount.value,
        fromCurrency: _fromCurrency.value,
        toCurrency: _toCurrency.value,
      );
      
      _convertedAmount.value = converted;
      
      // Calculate exchange rate
      final exchangeRate = converted / _conversionAmount.value;
      
      // Save to history
      final conversion = CurrencyConversion(
        amount: _conversionAmount.value,
        fromCurrency: _fromCurrency.value,
        toCurrency: _toCurrency.value,
        convertedAmount: converted,
        exchangeRate: exchangeRate,
        timestamp: DateTime.now(),
      );
      
      await _currencyService.saveConversionToHistory(conversion);
      await loadConversionHistory();
      
      if (kDebugMode) {
        print('✅ Converted ${_conversionAmount.value} ${_fromCurrency.value} to $converted ${_toCurrency.value}');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error converting currency: $e');
      }
      
      Get.snackbar(
        'Conversion Error',
        'Failed to convert currency. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      _isLoading.value = false;
    }
  }

  /// Load conversion history
  Future<void> loadConversionHistory() async {
    try {
      final history = await _currencyService.getConversionHistory();
      _conversionHistory.assignAll(history);
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading conversion history: $e');
      }
    }
  }

  /// Set conversion amount
  void setConversionAmount(double amount) {
    _conversionAmount.value = amount;
    if (amount > 0) {
      _performQuickConversion();
    } else {
      _convertedAmount.value = 0.0;
    }
  }

  /// Set from currency
  void setFromCurrency(String currency) {
    _fromCurrency.value = currency;
    if (_conversionAmount.value > 0) {
      _performQuickConversion();
    }
  }

  /// Set to currency
  void setToCurrency(String currency) {
    _toCurrency.value = currency;
    if (_conversionAmount.value > 0) {
      _performQuickConversion();
    }
  }

  /// Swap from and to currencies
  void swapCurrencies() {
    final temp = _fromCurrency.value;
    _fromCurrency.value = _toCurrency.value;
    _toCurrency.value = temp;
    
    if (_conversionAmount.value > 0) {
      _performQuickConversion();
    }
  }

  /// Perform quick conversion for real-time updates
  Future<void> _performQuickConversion() async {
    try {
      final converted = await _currencyService.convertCurrency(
        amount: _conversionAmount.value,
        fromCurrency: _fromCurrency.value,
        toCurrency: _toCurrency.value,
      );
      
      _convertedAmount.value = converted;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in quick conversion: $e');
      }
    }
  }

  /// Get supported currencies
  List<String> getSupportedCurrencies() {
    return _currencyService.getSupportedCurrencies();
  }

  /// Get currency symbol
  String getCurrencySymbol(String currencyCode) {
    return _currencyService.getCurrencySymbol(currencyCode);
  }

  /// Get currency name
  String getCurrencyName(String currencyCode) {
    return _currencyService.getCurrencyName(currencyCode);
  }

  /// Format amount with currency
  String formatAmount(double amount, String currencyCode) {
    return _currencyService.formatCurrency(amount, currencyCode);
  }

  /// Get exchange rate between currencies
  double? getExchangeRate(String fromCurrency, String toCurrency) {
    if (fromCurrency == toCurrency) return 1.0;
    
    // If we have rates for the from currency
    if (_selectedCurrency.value == fromCurrency) {
      return _exchangeRates[toCurrency];
    }
    
    // If we have rates for the to currency, calculate inverse
    if (_selectedCurrency.value == toCurrency) {
      final rate = _exchangeRates[fromCurrency];
      return rate != null ? 1.0 / rate : null;
    }
    
    return null;
  }

  /// Clear conversion history
  Future<void> clearConversionHistory() async {
    try {
      await _currencyService.clearCache();
      _conversionHistory.clear();
      
      Get.snackbar(
        'History Cleared',
        'Conversion history has been cleared',
        snackPosition: SnackPosition.BOTTOM,
      );
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error clearing history: $e');
      }
    }
  }

  /// Refresh exchange rates
  Future<void> refreshExchangeRates() async {
    await _currencyService.clearCache();
    await loadExchangeRates();
    
    Get.snackbar(
      'Rates Updated',
      'Exchange rates have been refreshed',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );
  }

  /// Get popular currency pairs
  List<Map<String, String>> getPopularCurrencyPairs() {
    return [
      {'from': 'USD', 'to': 'EUR'},
      {'from': 'USD', 'to': 'GBP'},
      {'from': 'USD', 'to': 'INR'},
      {'from': 'USD', 'to': 'JPY'},
      {'from': 'EUR', 'to': 'GBP'},
      {'from': 'EUR', 'to': 'USD'},
      {'from': 'GBP', 'to': 'USD'},
      {'from': 'INR', 'to': 'USD'},
    ];
  }

  /// Convert receipt amount to user's preferred currency
  Future<double> convertReceiptAmount(double amount, String fromCurrency) async {
    if (fromCurrency == _selectedCurrency.value) return amount;
    
    try {
      return await _currencyService.convertCurrency(
        amount: amount,
        fromCurrency: fromCurrency,
        toCurrency: _selectedCurrency.value,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error converting receipt amount: $e');
      }
      return amount; // Return original amount if conversion fails
    }
  }

  @override
  void onClose() {
    _currencyService.dispose();
    super.onClose();
  }
}