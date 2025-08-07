import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../services/tax_service.dart';
import '../controllers/auth_controller.dart';

/// Tax Controller using GetX
class TaxController extends GetxController {
  static TaxController get instance => Get.find();
  
  final _taxService = TaxService.instance;
  final _authController = Get.find<AuthController>();

  // Reactive variables
  final RxString _selectedCountry = 'US'.obs;
  final RxString _selectedState = ''.obs;
  final RxString _gstinNumber = ''.obs;
  final RxString _panNumber = ''.obs;
  final RxString _hsnCode = ''.obs;
  final RxDouble _taxableAmount = 0.0.obs;
  final Rx<TaxCalculationResult?> _lastCalculation = Rx<TaxCalculationResult?>(null);
  final RxBool _isLoading = false.obs;
  final RxList<HSNCodeInfo> _commonHSNCodes = <HSNCodeInfo>[].obs;

  // Getters
  String get selectedCountry => _selectedCountry.value;
  String get selectedState => _selectedState.value;
  String get gstinNumber => _gstinNumber.value;
  String get panNumber => _panNumber.value;
  String get hsnCode => _hsnCode.value;
  double get taxableAmount => _taxableAmount.value;
  TaxCalculationResult? get lastCalculation => _lastCalculation.value;
  bool get isLoading => _isLoading.value;
  List<HSNCodeInfo> get commonHSNCodes => _commonHSNCodes;

  @override
  void onInit() {
    super.onInit();
    _initializeTax();
  }

  /// Initialize tax settings
  Future<void> _initializeTax() async {
    try {
      // Load user's country and tax settings
      final userProfile = _authController.userProfile;
      if (userProfile != null) {
        _selectedCountry.value = userProfile.defaultCountry;
        _gstinNumber.value = userProfile.gstinNumber ?? '';
        _panNumber.value = userProfile.panNumber ?? '';
      }
      
      // Load common HSN codes
      _commonHSNCodes.assignAll(_taxService.getCommonHSNCodes());
      
      if (kDebugMode) {
        print('📊 Tax Controller initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing Tax Controller: $e');
      }
    }
  }

  /// Calculate tax based on country and settings
  Future<void> calculateTax() async {
    if (_taxableAmount.value <= 0) {
      Get.snackbar(
        'Invalid Amount',
        'Please enter a valid taxable amount',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      _isLoading.value = true;
      
      TaxCalculationResult result;
      
      switch (_selectedCountry.value) {
        case 'IN':
          result = _taxService.calculateIndianGST(
            amount: _taxableAmount.value,
            hsnCode: _hsnCode.value.isEmpty ? '9999' : _hsnCode.value,
            gstin: _gstinNumber.value.isEmpty ? null : _gstinNumber.value,
            stateCode: _selectedState.value.isEmpty ? null : _selectedState.value,
          );
          break;
          
        case 'US':
          result = _taxService.calculateUSSalesTax(
            amount: _taxableAmount.value,
            stateCode: _selectedState.value.isEmpty ? 'CA' : _selectedState.value,
          );
          break;
          
        default:
          // Default to VAT for other countries
          result = _taxService.calculateVAT(
            amount: _taxableAmount.value,
            countryCode: _selectedCountry.value,
          );
          break;
      }
      
      _lastCalculation.value = result;
      
      if (kDebugMode) {
        print('✅ Tax calculated: ${result.taxAmount} (${result.taxRate}%)');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error calculating tax: $e');
      }
      
      Get.snackbar(
        'Tax Calculation Error',
        'Failed to calculate tax. Please check your inputs.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      _isLoading.value = false;
    }
  }

  /// Set taxable amount
  void setTaxableAmount(double amount) {
    _taxableAmount.value = amount;
    if (amount > 0 && _shouldAutoCalculate()) {
      _performQuickCalculation();
    }
  }

  /// Set selected country
  void setSelectedCountry(String countryCode) {
    if (_selectedCountry.value != countryCode) {
      _selectedCountry.value = countryCode;
      _selectedState.value = ''; // Reset state when country changes
      
      if (_taxableAmount.value > 0 && _shouldAutoCalculate()) {
        _performQuickCalculation();
      }
    }
  }

  /// Set selected state
  void setSelectedState(String stateCode) {
    _selectedState.value = stateCode;
    
    if (_taxableAmount.value > 0 && _shouldAutoCalculate()) {
      _performQuickCalculation();
    }
  }

  /// Set GSTIN number
  void setGSTINNumber(String gstin) {
    _gstinNumber.value = gstin.toUpperCase();
    
    // Extract state code from GSTIN
    if (gstin.length >= 2) {
      final stateCode = gstin.substring(0, 2);
      _selectedState.value = stateCode;
    }
    
    if (_taxableAmount.value > 0 && _shouldAutoCalculate()) {
      _performQuickCalculation();
    }
  }

  /// Set PAN number
  void setPANNumber(String pan) {
    _panNumber.value = pan.toUpperCase();
  }

  /// Set HSN code
  void setHSNCode(String hsn) {
    _hsnCode.value = hsn;
    
    if (_taxableAmount.value > 0 && _shouldAutoCalculate()) {
      _performQuickCalculation();
    }
  }

  /// Validate GSTIN number
  bool validateGSTIN() {
    if (_gstinNumber.value.isEmpty) return true;
    
    final isValid = _taxService.validateGSTIN(_gstinNumber.value);
    
    if (!isValid) {
      Get.snackbar(
        'Invalid GSTIN',
        'Please enter a valid GSTIN number',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
    
    return isValid;
  }

  /// Validate PAN number
  bool validatePAN() {
    if (_panNumber.value.isEmpty) return true;
    
    final isValid = _taxService.validatePAN(_panNumber.value);
    
    if (!isValid) {
      Get.snackbar(
        'Invalid PAN',
        'Please enter a valid PAN number',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
    
    return isValid;
  }

  /// Get tax type for current country
  String getTaxType() {
    return _taxService.getTaxTypeByCountry(_selectedCountry.value);
  }

  /// Get supported countries
  List<Map<String, String>> getSupportedCountries() {
    return [
      {'code': 'IN', 'name': 'India'},
      {'code': 'US', 'name': 'United States'},
      {'code': 'GB', 'name': 'United Kingdom'},
      {'code': 'DE', 'name': 'Germany'},
      {'code': 'FR', 'name': 'France'},
      {'code': 'CA', 'name': 'Canada'},
      {'code': 'AU', 'name': 'Australia'},
      {'code': 'JP', 'name': 'Japan'},
    ];
  }

  /// Get US states
  List<Map<String, String>> getUSStates() {
    return [
      {'code': 'AL', 'name': 'Alabama'},
      {'code': 'AK', 'name': 'Alaska'},
      {'code': 'AZ', 'name': 'Arizona'},
      {'code': 'AR', 'name': 'Arkansas'},
      {'code': 'CA', 'name': 'California'},
      {'code': 'CO', 'name': 'Colorado'},
      {'code': 'CT', 'name': 'Connecticut'},
      {'code': 'DE', 'name': 'Delaware'},
      {'code': 'FL', 'name': 'Florida'},
      {'code': 'GA', 'name': 'Georgia'},
      {'code': 'HI', 'name': 'Hawaii'},
      {'code': 'ID', 'name': 'Idaho'},
      {'code': 'IL', 'name': 'Illinois'},
      {'code': 'IN', 'name': 'Indiana'},
      {'code': 'IA', 'name': 'Iowa'},
      {'code': 'KS', 'name': 'Kansas'},
      {'code': 'KY', 'name': 'Kentucky'},
      {'code': 'LA', 'name': 'Louisiana'},
      {'code': 'ME', 'name': 'Maine'},
      {'code': 'MD', 'name': 'Maryland'},
      {'code': 'MA', 'name': 'Massachusetts'},
      {'code': 'MI', 'name': 'Michigan'},
      {'code': 'MN', 'name': 'Minnesota'},
      {'code': 'MS', 'name': 'Mississippi'},
      {'code': 'MO', 'name': 'Missouri'},
      {'code': 'MT', 'name': 'Montana'},
      {'code': 'NE', 'name': 'Nebraska'},
      {'code': 'NV', 'name': 'Nevada'},
      {'code': 'NH', 'name': 'New Hampshire'},
      {'code': 'NJ', 'name': 'New Jersey'},
      {'code': 'NM', 'name': 'New Mexico'},
      {'code': 'NY', 'name': 'New York'},
      {'code': 'NC', 'name': 'North Carolina'},
      {'code': 'ND', 'name': 'North Dakota'},
      {'code': 'OH', 'name': 'Ohio'},
      {'code': 'OK', 'name': 'Oklahoma'},
      {'code': 'OR', 'name': 'Oregon'},
      {'code': 'PA', 'name': 'Pennsylvania'},
      {'code': 'RI', 'name': 'Rhode Island'},
      {'code': 'SC', 'name': 'South Carolina'},
      {'code': 'SD', 'name': 'South Dakota'},
      {'code': 'TN', 'name': 'Tennessee'},
      {'code': 'TX', 'name': 'Texas'},
      {'code': 'UT', 'name': 'Utah'},
      {'code': 'VT', 'name': 'Vermont'},
      {'code': 'VA', 'name': 'Virginia'},
      {'code': 'WA', 'name': 'Washington'},
      {'code': 'WV', 'name': 'West Virginia'},
      {'code': 'WI', 'name': 'Wisconsin'},
      {'code': 'WY', 'name': 'Wyoming'},
    ];
  }

  /// Get Indian states
  List<Map<String, String>> getIndianStates() {
    return [
      {'code': '01', 'name': 'Jammu and Kashmir'},
      {'code': '02', 'name': 'Himachal Pradesh'},
      {'code': '03', 'name': 'Punjab'},
      {'code': '04', 'name': 'Chandigarh'},
      {'code': '05', 'name': 'Uttarakhand'},
      {'code': '06', 'name': 'Haryana'},
      {'code': '07', 'name': 'Delhi'},
      {'code': '08', 'name': 'Rajasthan'},
      {'code': '09', 'name': 'Uttar Pradesh'},
      {'code': '10', 'name': 'Bihar'},
      {'code': '11', 'name': 'Sikkim'},
      {'code': '12', 'name': 'Arunachal Pradesh'},
      {'code': '13', 'name': 'Nagaland'},
      {'code': '14', 'name': 'Manipur'},
      {'code': '15', 'name': 'Mizoram'},
      {'code': '16', 'name': 'Tripura'},
      {'code': '17', 'name': 'Meghalaya'},
      {'code': '18', 'name': 'Assam'},
      {'code': '19', 'name': 'West Bengal'},
      {'code': '20', 'name': 'Jharkhand'},
      {'code': '21', 'name': 'Odisha'},
      {'code': '22', 'name': 'Chhattisgarh'},
      {'code': '23', 'name': 'Madhya Pradesh'},
      {'code': '24', 'name': 'Gujarat'},
      {'code': '25', 'name': 'Daman and Diu'},
      {'code': '26', 'name': 'Dadra and Nagar Haveli'},
      {'code': '27', 'name': 'Maharashtra'},
      {'code': '28', 'name': 'Andhra Pradesh'},
      {'code': '29', 'name': 'Karnataka'},
      {'code': '30', 'name': 'Goa'},
      {'code': '31', 'name': 'Lakshadweep'},
      {'code': '32', 'name': 'Kerala'},
      {'code': '33', 'name': 'Tamil Nadu'},
      {'code': '34', 'name': 'Puducherry'},
      {'code': '35', 'name': 'Andaman and Nicobar Islands'},
      {'code': '36', 'name': 'Telangana'},
      {'code': '37', 'name': 'Andhra Pradesh (New)'},
    ];
  }

  /// Update user profile with tax information
  Future<void> updateUserTaxProfile() async {
    try {
      final userProfile = _authController.userProfile;
      if (userProfile != null) {
        final updatedProfile = userProfile.copyWith(
          defaultCountry: _selectedCountry.value,
          gstinNumber: _gstinNumber.value.isEmpty ? null : _gstinNumber.value,
          panNumber: _panNumber.value.isEmpty ? null : _panNumber.value,
        );
        
        await _authController.updateProfile(updatedProfile);
        
        Get.snackbar(
          'Profile Updated',
          'Tax profile information has been saved',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating tax profile: $e');
      }
    }
  }

  /// Perform quick tax calculation
  Future<void> _performQuickCalculation() async {
    try {
      await calculateTax();
    } catch (e) {
      // Silently fail for quick calculations
      if (kDebugMode) {
        print('❌ Error in quick tax calculation: $e');
      }
    }
  }

  /// Check if auto calculation should be performed
  bool _shouldAutoCalculate() {
    // Auto calculate if we have minimum required information
    switch (_selectedCountry.value) {
      case 'IN':
        return _hsnCode.value.isNotEmpty || _gstinNumber.value.isNotEmpty;
      case 'US':
        return _selectedState.value.isNotEmpty;
      default:
        return true;
    }
  }

  /// Clear tax calculation
  void clearCalculation() {
    _lastCalculation.value = null;
    _taxableAmount.value = 0.0;
  }

  /// Get formatted tax summary
  String getFormattedTaxSummary() {
    final calculation = _lastCalculation.value;
    if (calculation == null) return '';
    
    return calculation.getFormattedSummary();
  }
}