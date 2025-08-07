import 'package:flutter/foundation.dart';

/// App Configuration
class AppConfig {
  static const String appName = 'Digi Bills';
  static const String version = '1.0.0';
  static const String packageName = 'com.digibills.app';
  
  // Supabase Configuration
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
  
  // Firebase Configuration
  static const String firebaseProjectId = 'YOUR_FIREBASE_PROJECT_ID';
  
  // Sentry Configuration  
  static const String sentryDsn = 'YOUR_SENTRY_DSN';
  
  // OpenRouter AI Configuration
  static const String openRouterApiKey = 'YOUR_OPENROUTER_API_KEY';
  static const String openRouterBaseUrl = 'https://openrouter.ai/api/v1';
  
  // Firecrawl Configuration
  static const String firecrawlApiKey = 'YOUR_FIRECRAWL_API_KEY';
  static const String firecrawlBaseUrl = 'https://api.firecrawl.dev';
  
  // App Features
  static const bool enableOCR = true;
  static const bool enableMultiCurrency = true;
  static const bool enableWarrantyTracking = true;
  static const bool enableAIAssistant = true;
  static const bool enableTaxManagement = true;
  
  // Default Settings
  static const String defaultCurrency = 'USD';
  static const String defaultCountry = 'US';
  static const String defaultLanguage = 'en';
  
  // Tax Configuration
  static const List<String> supportedCountries = [
    'US', 'IN', 'GB', 'CA', 'AU', 'DE', 'FR', 'JP'
  ];
  
  // India Specific
  static const bool enableGSTIN = true;
  static const bool enableHSNCode = true;
  
  // Development/Production flags
  static bool get isDebug => kDebugMode;
  static bool get isProduction => kReleaseMode;
  
  // API Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(minutes: 5);
  
  // Cache Configuration
  static const Duration cacheExpiry = Duration(hours: 24);
  static const int maxCacheSize = 100; // MB
  
  // OCR Configuration
  static const double minConfidenceScore = 0.7;
  static const int maxOCRRetries = 3;
  
  // Warranty Alert Configuration
  static const List<int> warrantyAlertDays = [30, 7, 1]; // Days before expiry
}