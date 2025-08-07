import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'dart:convert';

import '../config/app_config.dart';
import '../services/supabase_service.dart';

/// AI Service for customer care lookup and intelligent data processing
class AIService {
  static AIService? _instance;
  static AIService get instance => _instance ??= AIService._internal();
  
  AIService._internal();

  final _dio = Dio();
  final _supabaseService = SupabaseService.instance;

  /// Initialize AI service
  Future<void> initialize() async {
    try {
      _dio.options = BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'Content-Type': 'application/json',
        },
      );
      
      // Add interceptor for logging in debug mode
      if (kDebugMode) {
        _dio.interceptors.add(LogInterceptor(
          requestBody: false,
          responseBody: false,
          logPrint: (object) => debugPrint(object.toString()),
        ));
      }
      
      if (kDebugMode) {
        print('🤖 AI Service initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing AI Service: $e');
      }
      rethrow;
    }
  }

  /// Extract merchant information from website using Firecrawl
  Future<MerchantInfo?> extractMerchantInfo(String websiteUrl) async {
    try {
      if (AppConfig.firecrawlApiKey.isEmpty) {
        throw Exception('Firecrawl API key not configured');
      }

      // Step 1: Crawl website with Firecrawl
      final crawlData = await _crawlWebsite(websiteUrl);
      
      if (crawlData == null) return null;

      // Step 2: Extract merchant information using AI
      final merchantInfo = await _extractMerchantWithAI(crawlData, websiteUrl);
      
      // Step 3: Cache the result in database
      if (merchantInfo != null) {
        await _cacheMerchantInfo(merchantInfo);
      }

      return merchantInfo;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error extracting merchant info: $e');
      }
      return null;
    }
  }

  /// Search for merchant contact information
  Future<List<ContactMethod>> findMerchantContactInfo({
    required String merchantName,
    String? websiteUrl,
    String? brand,
  }) async {
    try {
      // First check cache
      final cachedInfo = await _getCachedMerchantInfo(merchantName);
      if (cachedInfo != null) {
        return cachedInfo.contactMethods;
      }

      // If no cache, try to find website and extract info
      String? searchUrl = websiteUrl;
      
      if (searchUrl == null) {
        searchUrl = await _findMerchantWebsite(merchantName, brand);
      }

      if (searchUrl != null) {
        final merchantInfo = await extractMerchantInfo(searchUrl);
        return merchantInfo?.contactMethods ?? [];
      }

      return [];
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error finding merchant contact info: $e');
      }
      return [];
    }
  }

  /// Find warranty claim process for a merchant
  Future<WarrantyClaimInfo?> findWarrantyClaimProcess({
    required String merchantName,
    required String productName,
    String? websiteUrl,
  }) async {
    try {
      String? searchUrl = websiteUrl;
      
      if (searchUrl == null) {
        searchUrl = await _findMerchantWebsite(merchantName);
      }

      if (searchUrl == null) return null;

      // Search for warranty/support pages
      final warrantyUrl = await _findWarrantyPage(searchUrl);
      
      if (warrantyUrl != null) {
        final crawlData = await _crawlWebsite(warrantyUrl);
        if (crawlData != null) {
          return await _extractWarrantyInfo(crawlData, merchantName, productName);
        }
      }

      return null;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error finding warranty claim process: $e');
      }
      return null;
    }
  }

  /// Get AI insights for receipt data
  Future<ReceiptInsights?> getReceiptInsights(Map<String, dynamic> receiptData) async {
    try {
      if (AppConfig.openRouterApiKey.isEmpty) {
        throw Exception('OpenRouter API key not configured');
      }

      final prompt = '''
Analyze this receipt data and provide insights:

Receipt Data:
${json.encode(receiptData)}

Please provide:
1. Product categorization suggestions
2. Warranty period estimation
3. Tax compliance insights
4. Potential savings opportunities
5. Merchant reliability score (1-10)

Format the response as JSON with the following structure:
{
  "categories": ["category1", "category2"],
  "estimatedWarrantyMonths": 12,
  "taxCompliance": {
    "isCompliant": true,
    "suggestions": ["suggestion1"]
  },
  "savingsOpportunities": ["opportunity1"],
  "merchantReliabilityScore": 8,
  "insights": ["insight1", "insight2"]
}
''';

      final response = await _callOpenRouterAI(prompt);
      
      if (response != null) {
        return ReceiptInsights.fromJson(json.decode(response));
      }

      return null;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting receipt insights: $e');
      }
      return null;
    }
  }

  /// Crawl website using Firecrawl API
  Future<Map<String, dynamic>?> _crawlWebsite(String url) async {
    try {
      final response = await _dio.post(
        'https://api.firecrawl.dev/v0/scrape',
        data: {
          'url': url,
          'formats': ['markdown', 'html'],
          'onlyMainContent': true,
          'includeTags': ['contact', 'support', 'warranty', 'customer-service'],
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer ${AppConfig.firecrawlApiKey}',
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data;
      }

      return null;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error crawling website: $e');
      }
      return null;
    }
  }

  /// Extract merchant information using AI
  Future<MerchantInfo?> _extractMerchantWithAI(Map<String, dynamic> crawlData, String websiteUrl) async {
    try {
      final content = crawlData['data']?['markdown'] ?? crawlData['data']?['html'] ?? '';
      
      if (content.isEmpty) return null;

      final prompt = '''
Extract merchant contact information from this website content:

URL: $websiteUrl
Content: ${content.length > 8000 ? content.substring(0, 8000) + '...' : content}

Please extract and format as JSON:
{
  "merchantName": "Company Name",
  "website": "$websiteUrl",
  "contactMethods": [
    {
      "type": "phone",
      "value": "+1-xxx-xxx-xxxx",
      "label": "Customer Support"
    },
    {
      "type": "email",
      "value": "support@company.com",
      "label": "General Support"
    },
    {
      "type": "chat",
      "value": "Live Chat Available",
      "label": "Online Chat"
    }
  ],
  "supportHours": "Mon-Fri 9AM-5PM EST",
  "warrantySupport": true,
  "categories": ["electronics", "retail"]
}

Extract real contact information only. If not found, omit that field.
''';

      final response = await _callOpenRouterAI(prompt);
      
      if (response != null) {
        final data = json.decode(response);
        return MerchantInfo.fromJson(data);
      }

      return null;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error extracting merchant info with AI: $e');
      }
      return null;
    }
  }

  /// Extract warranty information using AI
  Future<WarrantyClaimInfo?> _extractWarrantyInfo(
    Map<String, dynamic> crawlData,
    String merchantName,
    String productName,
  ) async {
    try {
      final content = crawlData['data']?['markdown'] ?? crawlData['data']?['html'] ?? '';
      
      if (content.isEmpty) return null;

      final prompt = '''
Extract warranty claim process information for product "$productName" from merchant "$merchantName":

Content: ${content.length > 8000 ? content.substring(0, 8000) + '...' : content}

Please extract and format as JSON:
{
  "merchantName": "$merchantName",
  "claimProcess": {
    "steps": [
      "Step 1: Contact customer service",
      "Step 2: Provide proof of purchase",
      "Step 3: Describe the issue"
    ],
    "requiredDocuments": ["Receipt", "Product serial number"],
    "timeframe": "7-14 business days",
    "contactInfo": {
      "phone": "+1-xxx-xxx-xxxx",
      "email": "warranty@company.com",
      "website": "https://company.com/warranty"
    }
  },
  "warrantyPeriod": "12 months",
  "coverage": "Manufacturer defects only"
}

Extract actual warranty information only.
''';

      final response = await _callOpenRouterAI(prompt);
      
      if (response != null) {
        final data = json.decode(response);
        return WarrantyClaimInfo.fromJson(data);
      }

      return null;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error extracting warranty info: $e');
      }
      return null;
    }
  }

  /// Call OpenRouter AI API
  Future<String?> _callOpenRouterAI(String prompt) async {
    try {
      final response = await _dio.post(
        'https://openrouter.ai/api/v1/chat/completions',
        data: {
          'model': 'anthropic/claude-3-haiku',
          'messages': [
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'max_tokens': 2000,
          'temperature': 0.1,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer ${AppConfig.openRouterApiKey}',
            'HTTP-Referer': AppConfig.appName,
            'X-Title': AppConfig.appName,
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return data['choices']?[0]?['message']?['content'];
      }

      return null;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error calling OpenRouter AI: $e');
      }
      return null;
    }
  }

  /// Find merchant website using search
  Future<String?> _findMerchantWebsite(String merchantName, [String? brand]) async {
    try {
      // This would ideally use a search API like Google Custom Search
      // For now, we'll return null and require manual website input
      // In a real implementation, you'd integrate with a search API
      
      if (kDebugMode) {
        print('🔍 Would search for website of: $merchantName ${brand ?? ''}');
      }
      
      return null;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error finding merchant website: $e');
      }
      return null;
    }
  }

  /// Find warranty page on website
  Future<String?> _findWarrantyPage(String websiteUrl) async {
    try {
      // Common warranty page patterns
      final commonPaths = [
        '/warranty',
        '/support/warranty',
        '/customer-service/warranty',
        '/help/warranty',
        '/support',
        '/customer-service',
        '/contact/warranty',
      ];

      final baseUrl = Uri.parse(websiteUrl);
      
      for (final path in commonPaths) {
        final testUrl = '${baseUrl.scheme}://${baseUrl.host}$path';
        
        try {
          final response = await _dio.head(testUrl);
          if (response.statusCode == 200) {
            return testUrl;
          }
        } catch (e) {
          // Continue to next path
          continue;
        }
      }

      // If no specific warranty page found, return main website
      return websiteUrl;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error finding warranty page: $e');
      }
      return websiteUrl;
    }
  }

  /// Cache merchant information in database
  Future<void> _cacheMerchantInfo(MerchantInfo merchantInfo) async {
    try {
      await _supabaseService.client
          .from('ai_merchant_cache')
          .upsert({
            'merchant_name': merchantInfo.merchantName.toLowerCase(),
            'website': merchantInfo.website,
            'contact_methods': merchantInfo.contactMethods
                .map((c) => c.toJson())
                .toList(),
            'support_hours': merchantInfo.supportHours,
            'warranty_support': merchantInfo.warrantySupport,
            'categories': merchantInfo.categories,
            'cached_at': DateTime.now().toIso8601String(),
            'expires_at': DateTime.now()
                .add(const Duration(days: 30))
                .toIso8601String(),
          });

      if (kDebugMode) {
        print('✅ Cached merchant info for ${merchantInfo.merchantName}');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error caching merchant info: $e');
      }
    }
  }

  /// Get cached merchant information
  Future<MerchantInfo?> _getCachedMerchantInfo(String merchantName) async {
    try {
      final response = await _supabaseService.client
          .from('ai_merchant_cache')
          .select()
          .eq('merchant_name', merchantName.toLowerCase())
          .gt('expires_at', DateTime.now().toIso8601String())
          .limit(1);

      if (response.isNotEmpty) {
        final data = response.first;
        return MerchantInfo(
          merchantName: data['merchant_name'],
          website: data['website'],
          contactMethods: (data['contact_methods'] as List)
              .map((c) => ContactMethod.fromJson(c))
              .toList(),
          supportHours: data['support_hours'],
          warrantySupport: data['warranty_support'] ?? false,
          categories: List<String>.from(data['categories'] ?? []),
        );
      }

      return null;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting cached merchant info: $e');
      }
      return null;
    }
  }

  /// Log AI interaction for analytics
  Future<void> _logAIInteraction({
    required String action,
    required String merchantName,
    bool success = true,
    String? error,
  }) async {
    try {
      await _supabaseService.client
          .from('ai_interactions')
          .insert({
            'user_id': _supabaseService.currentUser?.id,
            'action': action,
            'merchant_name': merchantName,
            'success': success,
            'error_message': error,
            'created_at': DateTime.now().toIso8601String(),
          });
          
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error logging AI interaction: $e');
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _dio.close();
  }
}

/// Merchant Information Model
class MerchantInfo {
  final String merchantName;
  final String website;
  final List<ContactMethod> contactMethods;
  final String? supportHours;
  final bool warrantySupport;
  final List<String> categories;

  MerchantInfo({
    required this.merchantName,
    required this.website,
    required this.contactMethods,
    this.supportHours,
    this.warrantySupport = false,
    this.categories = const [],
  });

  factory MerchantInfo.fromJson(Map<String, dynamic> json) {
    return MerchantInfo(
      merchantName: json['merchantName'] as String,
      website: json['website'] as String,
      contactMethods: (json['contactMethods'] as List)
          .map((c) => ContactMethod.fromJson(c))
          .toList(),
      supportHours: json['supportHours'] as String?,
      warrantySupport: json['warrantySupport'] as bool? ?? false,
      categories: List<String>.from(json['categories'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'merchantName': merchantName,
      'website': website,
      'contactMethods': contactMethods.map((c) => c.toJson()).toList(),
      'supportHours': supportHours,
      'warrantySupport': warrantySupport,
      'categories': categories,
    };
  }
}

/// Contact Method Model
class ContactMethod {
  final String type; // phone, email, chat, form
  final String value;
  final String label;

  ContactMethod({
    required this.type,
    required this.value,
    required this.label,
  });

  factory ContactMethod.fromJson(Map<String, dynamic> json) {
    return ContactMethod(
      type: json['type'] as String,
      value: json['value'] as String,
      label: json['label'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'value': value,
      'label': label,
    };
  }

  /// Get icon for contact type
  String get icon {
    switch (type.toLowerCase()) {
      case 'phone':
        return '📞';
      case 'email':
        return '📧';
      case 'chat':
        return '💬';
      case 'form':
        return '📝';
      default:
        return '📞';
    }
  }
}

/// Warranty Claim Information Model
class WarrantyClaimInfo {
  final String merchantName;
  final ClaimProcess claimProcess;
  final String? warrantyPeriod;
  final String? coverage;

  WarrantyClaimInfo({
    required this.merchantName,
    required this.claimProcess,
    this.warrantyPeriod,
    this.coverage,
  });

  factory WarrantyClaimInfo.fromJson(Map<String, dynamic> json) {
    return WarrantyClaimInfo(
      merchantName: json['merchantName'] as String,
      claimProcess: ClaimProcess.fromJson(json['claimProcess']),
      warrantyPeriod: json['warrantyPeriod'] as String?,
      coverage: json['coverage'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'merchantName': merchantName,
      'claimProcess': claimProcess.toJson(),
      'warrantyPeriod': warrantyPeriod,
      'coverage': coverage,
    };
  }
}

/// Claim Process Model
class ClaimProcess {
  final List<String> steps;
  final List<String> requiredDocuments;
  final String? timeframe;
  final Map<String, String> contactInfo;

  ClaimProcess({
    required this.steps,
    required this.requiredDocuments,
    this.timeframe,
    this.contactInfo = const {},
  });

  factory ClaimProcess.fromJson(Map<String, dynamic> json) {
    return ClaimProcess(
      steps: List<String>.from(json['steps'] ?? []),
      requiredDocuments: List<String>.from(json['requiredDocuments'] ?? []),
      timeframe: json['timeframe'] as String?,
      contactInfo: Map<String, String>.from(json['contactInfo'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'steps': steps,
      'requiredDocuments': requiredDocuments,
      'timeframe': timeframe,
      'contactInfo': contactInfo,
    };
  }
}

/// Receipt Insights Model
class ReceiptInsights {
  final List<String> categories;
  final int estimatedWarrantyMonths;
  final TaxComplianceInfo taxCompliance;
  final List<String> savingsOpportunities;
  final int merchantReliabilityScore;
  final List<String> insights;

  ReceiptInsights({
    required this.categories,
    required this.estimatedWarrantyMonths,
    required this.taxCompliance,
    required this.savingsOpportunities,
    required this.merchantReliabilityScore,
    required this.insights,
  });

  factory ReceiptInsights.fromJson(Map<String, dynamic> json) {
    return ReceiptInsights(
      categories: List<String>.from(json['categories'] ?? []),
      estimatedWarrantyMonths: json['estimatedWarrantyMonths'] as int? ?? 12,
      taxCompliance: TaxComplianceInfo.fromJson(json['taxCompliance'] ?? {}),
      savingsOpportunities: List<String>.from(json['savingsOpportunities'] ?? []),
      merchantReliabilityScore: json['merchantReliabilityScore'] as int? ?? 5,
      insights: List<String>.from(json['insights'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'categories': categories,
      'estimatedWarrantyMonths': estimatedWarrantyMonths,
      'taxCompliance': taxCompliance.toJson(),
      'savingsOpportunities': savingsOpportunities,
      'merchantReliabilityScore': merchantReliabilityScore,
      'insights': insights,
    };
  }
}

/// Tax Compliance Information Model
class TaxComplianceInfo {
  final bool isCompliant;
  final List<String> suggestions;

  TaxComplianceInfo({
    required this.isCompliant,
    required this.suggestions,
  });

  factory TaxComplianceInfo.fromJson(Map<String, dynamic> json) {
    return TaxComplianceInfo(
      isCompliant: json['isCompliant'] as bool? ?? true,
      suggestions: List<String>.from(json['suggestions'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isCompliant': isCompliant,
      'suggestions': suggestions,
    };
  }
}