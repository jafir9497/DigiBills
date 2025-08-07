import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../config/app_config.dart';
import '../services/ai_service.dart';
import '../controllers/auth_controller.dart';

/// AI Controller using GetX for managing AI operations
class AIController extends GetxController {
  static AIController get instance => Get.find();
  
  final _aiService = AIService.instance;
  final _authController = Get.find<AuthController>();

  // Reactive variables
  final RxBool _isLoading = false.obs;
  final RxBool _isInitialized = false.obs;
  final Rx<MerchantInfo?> _currentMerchantInfo = Rx<MerchantInfo?>(null);
  final Rx<WarrantyClaimInfo?> _currentWarrantyInfo = Rx<WarrantyClaimInfo?>(null);
  final Rx<ReceiptInsights?> _currentInsights = Rx<ReceiptInsights?>(null);
  final RxList<ContactMethod> _contactMethods = <ContactMethod>[].obs;
  final RxString _searchQuery = ''.obs;
  final RxString _websiteUrl = ''.obs;

  // Getters
  bool get isLoading => _isLoading.value;
  bool get isInitialized => _isInitialized.value;
  MerchantInfo? get currentMerchantInfo => _currentMerchantInfo.value;
  WarrantyClaimInfo? get currentWarrantyInfo => _currentWarrantyInfo.value;
  ReceiptInsights? get currentInsights => _currentInsights.value;
  List<ContactMethod> get contactMethods => _contactMethods;
  String get searchQuery => _searchQuery.value;
  String get websiteUrl => _websiteUrl.value;

  @override
  void onInit() {
    super.onInit();
    _initializeAI();
  }

  /// Initialize AI controller
  Future<void> _initializeAI() async {
    try {
      await _aiService.initialize();
      _isInitialized.value = true;
      
      if (kDebugMode) {
        print('🤖 AI Controller initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing AI Controller: $e');
      }
    }
  }

  /// Search for merchant information
  Future<void> searchMerchantInfo(String merchantName, {String? websiteUrl, String? brand}) async {
    if (merchantName.isEmpty) {
      Get.snackbar(
        'Invalid Input',
        'Please enter a merchant name',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      _isLoading.value = true;
      _searchQuery.value = merchantName;
      _websiteUrl.value = websiteUrl ?? '';
      
      // Search for contact information
      final contactMethods = await _aiService.findMerchantContactInfo(
        merchantName: merchantName,
        websiteUrl: websiteUrl,
        brand: brand,
      );
      
      _contactMethods.assignAll(contactMethods);
      
      // If we have a website, extract full merchant info
      if (websiteUrl != null && websiteUrl.isNotEmpty) {
        final merchantInfo = await _aiService.extractMerchantInfo(websiteUrl);
        _currentMerchantInfo.value = merchantInfo;
      }
      
      if (contactMethods.isEmpty) {
        Get.snackbar(
          'No Results',
          'Could not find contact information for $merchantName',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Success',
          'Found ${contactMethods.length} contact method(s) for $merchantName',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
      
      if (kDebugMode) {
        print('✅ Found ${contactMethods.length} contact methods for $merchantName');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error searching merchant info: $e');
      }
      
      Get.snackbar(
        'Search Error',
        'Failed to search for merchant information',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      _isLoading.value = false;
    }
  }

  /// Find warranty claim process
  Future<void> findWarrantyClaimProcess({
    required String merchantName,
    required String productName,
    String? websiteUrl,
  }) async {
    try {
      _isLoading.value = true;
      
      final warrantyInfo = await _aiService.findWarrantyClaimProcess(
        merchantName: merchantName,
        productName: productName,
        websiteUrl: websiteUrl,
      );
      
      _currentWarrantyInfo.value = warrantyInfo;
      
      if (warrantyInfo != null) {
        Get.snackbar(
          'Warranty Info Found',
          'Found warranty claim process for $productName',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'No Warranty Info',
          'Could not find warranty claim process',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error finding warranty claim process: $e');
      }
      
      Get.snackbar(
        'Error',
        'Failed to find warranty claim process',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      _isLoading.value = false;
    }
  }

  /// Get AI insights for receipt
  Future<void> getReceiptInsights(Map<String, dynamic> receiptData) async {
    try {
      _isLoading.value = true;
      
      final insights = await _aiService.getReceiptInsights(receiptData);
      _currentInsights.value = insights;
      
      if (insights != null) {
        Get.snackbar(
          'AI Insights Ready',
          'Generated ${insights.insights.length} insights for your receipt',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting receipt insights: $e');
      }
      
      Get.snackbar(
        'Insights Error',
        'Failed to generate AI insights',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      _isLoading.value = false;
    }
  }

  /// Extract merchant from website URL
  Future<void> extractMerchantFromWebsite(String websiteUrl) async {
    if (websiteUrl.isEmpty) {
      Get.snackbar(
        'Invalid URL',
        'Please enter a valid website URL',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      _isLoading.value = true;
      _websiteUrl.value = websiteUrl;
      
      final merchantInfo = await _aiService.extractMerchantInfo(websiteUrl);
      
      if (merchantInfo != null) {
        _currentMerchantInfo.value = merchantInfo;
        _contactMethods.assignAll(merchantInfo.contactMethods);
        _searchQuery.value = merchantInfo.merchantName;
        
        Get.snackbar(
          'Extraction Complete',
          'Extracted information for ${merchantInfo.merchantName}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Extraction Failed',
          'Could not extract merchant information from the website',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error extracting merchant from website: $e');
      }
      
      Get.snackbar(
        'Extraction Error',
        'Failed to extract information from website',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      _isLoading.value = false;
    }
  }

  /// Launch contact method
  Future<void> launchContactMethod(ContactMethod contact) async {
    try {
      switch (contact.type.toLowerCase()) {
        case 'phone':
          final phoneNumber = contact.value.replaceAll(RegExp(r'[^\d+]'), '');
          await _launchUrl('tel:$phoneNumber');
          break;
          
        case 'email':
          await _launchUrl('mailto:${contact.value}');
          break;
          
        case 'chat':
        case 'form':
          if (_currentMerchantInfo.value?.website != null) {
            await _launchUrl(_currentMerchantInfo.value!.website);
          }
          break;
          
        default:
          Get.snackbar(
            'Unsupported',
            'Cannot launch contact method: ${contact.type}',
            snackPosition: SnackPosition.BOTTOM,
          );
          break;
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error launching contact method: $e');
      }
      
      Get.snackbar(
        'Launch Error',
        'Could not open ${contact.label}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Launch URL
  Future<void> _launchUrl(String url) async {
    try {
      // In a real app, you would use url_launcher package
      if (kDebugMode) {
        print('🚀 Would launch URL: $url');
      }
      
      // For now, just show a snackbar
      Get.snackbar(
        'Contact Info',
        'Contact: $url',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 5),
      );
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error launching URL: $e');
      }
      rethrow;
    }
  }

  /// Clear current data
  void clearData() {
    _currentMerchantInfo.value = null;
    _currentWarrantyInfo.value = null;
    _currentInsights.value = null;
    _contactMethods.clear();
    _searchQuery.value = '';
    _websiteUrl.value = '';
  }

  /// Set search query
  void setSearchQuery(String query) {
    _searchQuery.value = query;
  }

  /// Set website URL
  void setWebsiteUrl(String url) {
    _websiteUrl.value = url;
  }

  /// Check if AI features are available
  bool get isAIAvailable {
    return _isInitialized.value && 
           (AppConfig.firecrawlApiKey.isNotEmpty || AppConfig.openRouterApiKey.isNotEmpty);
  }

  /// Get AI availability status
  String get aiAvailabilityStatus {
    if (!_isInitialized.value) return 'Initializing AI services...';
    
    final hasFirecrawl = AppConfig.firecrawlApiKey.isNotEmpty;
    final hasOpenRouter = AppConfig.openRouterApiKey.isNotEmpty;
    
    if (hasFirecrawl && hasOpenRouter) {
      return 'All AI features available';
    } else if (hasFirecrawl) {
      return 'Website extraction available';
    } else if (hasOpenRouter) {
      return 'AI insights available';
    } else {
      return 'AI features require API keys configuration';
    }
  }

  /// Get formatted contact methods for display
  List<Map<String, dynamic>> getFormattedContactMethods() {
    return _contactMethods.map((contact) {
      return {
        'icon': contact.icon,
        'label': contact.label,
        'value': contact.value,
        'type': contact.type,
      };
    }).toList();
  }

  /// Get warranty claim steps
  List<String> getWarrantyClaimSteps() {
    return _currentWarrantyInfo.value?.claimProcess.steps ?? [];
  }

  /// Get required documents for warranty claim
  List<String> getRequiredDocuments() {
    return _currentWarrantyInfo.value?.claimProcess.requiredDocuments ?? [];
  }

  /// Get formatted insights
  List<Map<String, dynamic>> getFormattedInsights() {
    final insights = _currentInsights.value;
    if (insights == null) return [];

    return [
      {
        'title': 'Suggested Categories',
        'items': insights.categories,
        'icon': '📂',
      },
      {
        'title': 'Estimated Warranty',
        'items': ['${insights.estimatedWarrantyMonths} months'],
        'icon': '🛡️',
      },
      {
        'title': 'Tax Compliance',
        'items': insights.taxCompliance.suggestions.isNotEmpty 
            ? insights.taxCompliance.suggestions
            : ['Tax information appears complete'],
        'icon': insights.taxCompliance.isCompliant ? '✅' : '⚠️',
      },
      {
        'title': 'Savings Opportunities',
        'items': insights.savingsOpportunities.isNotEmpty 
            ? insights.savingsOpportunities 
            : ['No savings opportunities found'],
        'icon': '💰',
      },
      {
        'title': 'AI Insights',
        'items': insights.insights,
        'icon': '🤖',
      },
    ];
  }

  /// Get merchant reliability score color
  Color getMerchantReliabilityColor() {
    final score = _currentInsights.value?.merchantReliabilityScore ?? 5;
    
    if (score >= 8) return Colors.green;
    if (score >= 6) return Colors.orange;
    return Colors.red;
  }

  /// Get merchant reliability description
  String getMerchantReliabilityDescription() {
    final score = _currentInsights.value?.merchantReliabilityScore ?? 5;
    
    if (score >= 8) return 'Highly Reliable';
    if (score >= 6) return 'Moderately Reliable';
    if (score >= 4) return 'Average Reliability';
    return 'Low Reliability';
  }

  @override
  void onClose() {
    super.onClose();
    _aiService.dispose();
  }
}