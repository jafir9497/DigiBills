import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../models/warranty.dart';
import '../services/warranty_service.dart';
import '../controllers/auth_controller.dart';

/// Warranty Controller using GetX
class WarrantyController extends GetxController {
  static WarrantyController get instance => Get.find();
  
  final _warrantyService = WarrantyService.instance;
  final _authController = Get.find<AuthController>();

  // Reactive variables
  final RxList<Warranty> _warranties = <Warranty>[].obs;
  final RxList<Warranty> _expiringSoonWarranties = <Warranty>[].obs;
  final RxList<Warranty> _expiredWarranties = <Warranty>[].obs;
  final RxBool _isLoading = false.obs;
  final RxString _selectedCategory = 'All'.obs;
  final RxString _selectedStatus = 'All'.obs;
  final Rx<WarrantyStatistics?> _statistics = Rx<WarrantyStatistics?>(null);
  
  // Form variables for adding/editing warranties
  final RxString _productName = ''.obs;
  final RxString _brand = ''.obs;
  final RxString _modelNumber = ''.obs;
  final RxString _serialNumber = ''.obs;
  final RxString _category = ''.obs;
  final Rx<DateTime?> _purchaseDate = Rx<DateTime?>(null);
  final RxDouble _purchasePrice = 0.0.obs;
  final RxString _currency = 'USD'.obs;
  final RxInt _warrantyPeriodMonths = 12.obs;
  final Rx<WarrantyType> _warrantyType = WarrantyType.manufacturer.obs;
  final RxList<int> _alertDaysBefore = <int>[30, 7, 1].obs;

  // Getters
  List<Warranty> get warranties => _warranties;
  List<Warranty> get expiringSoonWarranties => _expiringSoonWarranties;
  List<Warranty> get expiredWarranties => _expiredWarranties;
  bool get isLoading => _isLoading.value;
  String get selectedCategory => _selectedCategory.value;
  String get selectedStatus => _selectedStatus.value;
  WarrantyStatistics? get statistics => _statistics.value;
  
  // Form getters
  String get productName => _productName.value;
  String get brand => _brand.value;
  String get modelNumber => _modelNumber.value;
  String get serialNumber => _serialNumber.value;
  String get category => _category.value;
  DateTime? get purchaseDate => _purchaseDate.value;
  double get purchasePrice => _purchasePrice.value;
  String get currency => _currency.value;
  int get warrantyPeriodMonths => _warrantyPeriodMonths.value;
  WarrantyType get warrantyType => _warrantyType.value;
  List<int> get alertDaysBefore => _alertDaysBefore;

  @override
  void onInit() {
    super.onInit();
    _initializeWarranty();
  }

  /// Initialize warranty controller
  Future<void> _initializeWarranty() async {
    try {
      await _warrantyService.initialize();
      await loadWarranties();
      await loadStatistics();
      
      // Set up periodic check for alerts
      _setupPeriodicAlertCheck();
      
      if (kDebugMode) {
        print('🛡️ Warranty Controller initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing Warranty Controller: $e');
      }
    }
  }

  /// Load all warranties
  Future<void> loadWarranties() async {
    try {
      _isLoading.value = true;
      
      final warranties = await _warrantyService.getUserWarranties();
      _warranties.assignAll(warranties);
      
      // Load specific categories
      await loadExpiringSoonWarranties();
      await loadExpiredWarranties();
      
      if (kDebugMode) {
        print('✅ Loaded ${warranties.length} warranties');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading warranties: $e');
      }
      
      Get.snackbar(
        'Error',
        'Failed to load warranties',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      _isLoading.value = false;
    }
  }

  /// Load expiring soon warranties
  Future<void> loadExpiringSoonWarranties() async {
    try {
      final warranties = await _warrantyService.getExpiringSoonWarranties();
      _expiringSoonWarranties.assignAll(warranties);
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading expiring warranties: $e');
      }
    }
  }

  /// Load expired warranties
  Future<void> loadExpiredWarranties() async {
    try {
      final warranties = await _warrantyService.getExpiredWarranties();
      _expiredWarranties.assignAll(warranties);
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading expired warranties: $e');
      }
    }
  }

  /// Load warranty statistics
  Future<void> loadStatistics() async {
    try {
      final stats = await _warrantyService.getWarrantyStatistics();
      _statistics.value = stats;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading warranty statistics: $e');
      }
    }
  }

  /// Add or update warranty
  Future<bool> saveWarranty({String? warrantyId}) async {
    if (!_validateWarrantyForm()) return false;

    try {
      _isLoading.value = true;
      
      final warranty = Warranty(
        id: warrantyId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        userId: _authController.currentUser!.id,
        productName: _productName.value,
        brand: _brand.value.isEmpty ? null : _brand.value,
        modelNumber: _modelNumber.value.isEmpty ? null : _modelNumber.value,
        serialNumber: _serialNumber.value.isEmpty ? null : _serialNumber.value,
        category: _category.value.isEmpty ? null : _category.value,
        purchaseDate: _purchaseDate.value!,
        purchasePrice: _purchasePrice.value > 0 ? _purchasePrice.value : null,
        currency: _currency.value,
        warrantyPeriodMonths: _warrantyPeriodMonths.value,
        warrantyStartDate: _purchaseDate.value!,
        warrantyEndDate: _warrantyService.calculateWarrantyEndDate(
          _purchaseDate.value!,
          _warrantyPeriodMonths.value,
        ),
        warrantyType: _warrantyType.value,
        alertDaysBefore: _alertDaysBefore.toList(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await _warrantyService.saveWarranty(warranty);
      
      // Reload warranties
      await loadWarranties();
      await loadStatistics();
      
      // Clear form
      clearForm();
      
      Get.snackbar(
        'Success',
        warrantyId != null ? 'Warranty updated successfully' : 'Warranty added successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      
      return true;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving warranty: $e');
      }
      
      Get.snackbar(
        'Error',
        'Failed to save warranty',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  /// Delete warranty
  Future<void> deleteWarranty(String warrantyId) async {
    try {
      _isLoading.value = true;
      
      await _warrantyService.deleteWarranty(warrantyId);
      
      // Remove from local lists
      _warranties.removeWhere((w) => w.id == warrantyId);
      _expiringSoonWarranties.removeWhere((w) => w.id == warrantyId);
      _expiredWarranties.removeWhere((w) => w.id == warrantyId);
      
      await loadStatistics();
      
      Get.snackbar(
        'Success',
        'Warranty deleted successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting warranty: $e');
      }
      
      Get.snackbar(
        'Error',
        'Failed to delete warranty',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      _isLoading.value = false;
    }
  }

  /// Update warranty claim
  Future<void> updateWarrantyClaim({
    required String warrantyId,
    required ClaimStatus claimStatus,
    WarrantyClaim? claimDetails,
  }) async {
    try {
      _isLoading.value = true;
      
      final updatedWarranty = await _warrantyService.updateWarrantyClaim(
        warrantyId: warrantyId,
        claimStatus: claimStatus,
        claimDetails: claimDetails,
      );
      
      // Update local warranty list
      final index = _warranties.indexWhere((w) => w.id == warrantyId);
      if (index != -1) {
        _warranties[index] = updatedWarranty;
      }
      
      Get.snackbar(
        'Success',
        'Warranty claim updated successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating warranty claim: $e');
      }
      
      Get.snackbar(
        'Error',
        'Failed to update warranty claim',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      _isLoading.value = false;
    }
  }

  /// Get filtered warranties
  List<Warranty> getFilteredWarranties() {
    var filteredWarranties = _warranties.where((warranty) {
      // Category filter
      if (_selectedCategory.value != 'All' && 
          warranty.category != _selectedCategory.value) {
        return false;
      }
      
      // Status filter
      if (_selectedStatus.value != 'All') {
        switch (_selectedStatus.value) {
          case 'Active':
            return warranty.status == WarrantyStatus.active;
          case 'Expiring Soon':
            return warranty.status == WarrantyStatus.expiringSoon;
          case 'Expired':
            return warranty.status == WarrantyStatus.expired;
          case 'Inactive':
            return warranty.status == WarrantyStatus.inactive;
        }
      }
      
      return true;
    }).toList();
    
    // Sort by warranty end date
    filteredWarranties.sort((a, b) => a.warrantyEndDate.compareTo(b.warrantyEndDate));
    
    return filteredWarranties;
  }

  /// Set form values for editing
  void setWarrantyForEditing(Warranty warranty) {
    _productName.value = warranty.productName;
    _brand.value = warranty.brand ?? '';
    _modelNumber.value = warranty.modelNumber ?? '';
    _serialNumber.value = warranty.serialNumber ?? '';
    _category.value = warranty.category ?? '';
    _purchaseDate.value = warranty.purchaseDate;
    _purchasePrice.value = warranty.purchasePrice ?? 0.0;
    _currency.value = warranty.currency ?? 'USD';
    _warrantyPeriodMonths.value = warranty.warrantyPeriodMonths;
    _warrantyType.value = warranty.warrantyType;
    _alertDaysBefore.assignAll(warranty.alertDaysBefore);
  }

  /// Clear form
  void clearForm() {
    _productName.value = '';
    _brand.value = '';
    _modelNumber.value = '';
    _serialNumber.value = '';
    _category.value = '';
    _purchaseDate.value = null;
    _purchasePrice.value = 0.0;
    _currency.value = 'USD';
    _warrantyPeriodMonths.value = 12;
    _warrantyType.value = WarrantyType.manufacturer;
    _alertDaysBefore.assignAll([30, 7, 1]);
  }

  /// Form setters
  void setProductName(String value) => _productName.value = value;
  void setBrand(String value) => _brand.value = value;
  void setModelNumber(String value) => _modelNumber.value = value;
  void setSerialNumber(String value) => _serialNumber.value = value;
  void setCategory(String value) => _category.value = value;
  void setPurchaseDate(DateTime value) => _purchaseDate.value = value;
  void setPurchasePrice(double value) => _purchasePrice.value = value;
  void setCurrency(String value) => _currency.value = value;
  void setWarrantyPeriodMonths(int value) => _warrantyPeriodMonths.value = value;
  void setWarrantyType(WarrantyType value) => _warrantyType.value = value;
  void setAlertDaysBefore(List<int> value) => _alertDaysBefore.assignAll(value);

  /// Filter setters
  void setSelectedCategory(String category) {
    _selectedCategory.value = category;
  }

  void setSelectedStatus(String status) {
    _selectedStatus.value = status;
  }

  /// Validate warranty form
  bool _validateWarrantyForm() {
    if (_productName.value.isEmpty) {
      Get.snackbar(
        'Validation Error',
        'Product name is required',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    if (_purchaseDate.value == null) {
      Get.snackbar(
        'Validation Error',
        'Purchase date is required',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    if (_warrantyPeriodMonths.value <= 0) {
      Get.snackbar(
        'Validation Error',
        'Warranty period must be greater than 0',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    return true;
  }

  /// Setup periodic alert checking
  void _setupPeriodicAlertCheck() {
    // Check for alerts every hour
    Timer.periodic(const Duration(hours: 1), (timer) {
      _warrantyService.checkAndSendDueAlerts();
    });
  }

  /// Get popular categories
  List<String> getPopularCategories() {
    return _warrantyService.getPopularCategories();
  }

  /// Get warranty types
  List<WarrantyType> getWarrantyTypes() {
    return WarrantyType.values;
  }

  /// Get warranty status options
  List<String> getStatusOptions() {
    return ['All', 'Active', 'Expiring Soon', 'Expired', 'Inactive'];
  }

  /// Get category options for filter
  List<String> getCategoryOptions() {
    final categories = ['All'];
    final uniqueCategories = _warranties
        .map((w) => w.category)
        .where((category) => category != null && category.isNotEmpty)
        .toSet()
        .toList();
    
    categories.addAll(uniqueCategories);
    return categories;
  }

  /// Refresh warranties
  Future<void> refreshWarranties() async {
    await loadWarranties();
    await loadStatistics();
  }

  /// Get warranty by ID
  Future<Warranty?> getWarrantyById(String warrantyId) async {
    return await _warrantyService.getWarrantyById(warrantyId);
  }
}