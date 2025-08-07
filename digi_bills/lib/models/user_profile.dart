import 'package:intl/intl.dart';

/// User Profile Model
class UserProfile {
  final String id;
  final String email;
  final String? fullName;
  final String? avatarUrl;
  final String? phone;
  final String defaultCurrency;
  final String defaultCountry;
  final String timezone;
  final String language;
  
  // India specific fields
  final String? gstinNumber;
  final String? panNumber;
  
  // App preferences
  final NotificationSettings notificationSettings;
  final OCRPreferences ocrPreferences;
  
  // Audit fields
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    required this.email,
    this.fullName,
    this.avatarUrl,
    this.phone,
    this.defaultCurrency = 'USD',
    this.defaultCountry = 'US',
    this.timezone = 'UTC',
    this.language = 'en',
    this.gstinNumber,
    this.panNumber,
    required this.notificationSettings,
    required this.ocrPreferences,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create UserProfile from JSON
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      phone: json['phone'] as String?,
      defaultCurrency: json['default_currency'] as String? ?? 'USD',
      defaultCountry: json['default_country'] as String? ?? 'US',
      timezone: json['timezone'] as String? ?? 'UTC',
      language: json['language'] as String? ?? 'en',
      gstinNumber: json['gstin_number'] as String?,
      panNumber: json['pan_number'] as String?,
      notificationSettings: NotificationSettings.fromJson(
        json['notification_settings'] as Map<String, dynamic>? ?? {},
      ),
      ocrPreferences: OCRPreferences.fromJson(
        json['ocr_preferences'] as Map<String, dynamic>? ?? {},
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert UserProfile to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'phone': phone,
      'default_currency': defaultCurrency,
      'default_country': defaultCountry,
      'timezone': timezone,
      'language': language,
      'gstin_number': gstinNumber,
      'pan_number': panNumber,
      'notification_settings': notificationSettings.toJson(),
      'ocr_preferences': ocrPreferences.toJson(),
    };
  }

  /// Create a copy with updated values
  UserProfile copyWith({
    String? fullName,
    String? avatarUrl,
    String? phone,
    String? defaultCurrency,
    String? defaultCountry,
    String? timezone,
    String? language,
    String? gstinNumber,
    String? panNumber,
    NotificationSettings? notificationSettings,
    OCRPreferences? ocrPreferences,
  }) {
    return UserProfile(
      id: id,
      email: email,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phone: phone ?? this.phone,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      defaultCountry: defaultCountry ?? this.defaultCountry,
      timezone: timezone ?? this.timezone,
      language: language ?? this.language,
      gstinNumber: gstinNumber ?? this.gstinNumber,
      panNumber: panNumber ?? this.panNumber,
      notificationSettings: notificationSettings ?? this.notificationSettings,
      ocrPreferences: ocrPreferences ?? this.ocrPreferences,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Check if GSTIN number is valid
  bool get isGSTINValid {
    if (gstinNumber == null || gstinNumber!.isEmpty) return true;
    final gstinPattern = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$');
    return gstinPattern.hasMatch(gstinNumber!);
  }

  /// Check if PAN number is valid
  bool get isPANValid {
    if (panNumber == null || panNumber!.isEmpty) return true;
    final panPattern = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
    return panPattern.hasMatch(panNumber!);
  }

  /// Get formatted display name
  String get displayName {
    if (fullName != null && fullName!.isNotEmpty) {
      return fullName!;
    }
    return email.split('@')[0];
  }

  /// Get initials for avatar
  String get initials {
    if (fullName != null && fullName!.isNotEmpty) {
      final parts = fullName!.split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return fullName![0].toUpperCase();
    }
    return email[0].toUpperCase();
  }

  @override
  String toString() {
    return 'UserProfile(id: $id, email: $email, fullName: $fullName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Notification Settings Model
class NotificationSettings {
  final bool warrantyAlerts;
  final bool taxReminders;
  final bool aiInsights;
  final bool pushNotifications;
  final bool emailNotifications;

  NotificationSettings({
    this.warrantyAlerts = true,
    this.taxReminders = true,
    this.aiInsights = true,
    this.pushNotifications = true,
    this.emailNotifications = true,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      warrantyAlerts: json['warranty_alerts'] as bool? ?? true,
      taxReminders: json['tax_reminders'] as bool? ?? true,
      aiInsights: json['ai_insights'] as bool? ?? true,
      pushNotifications: json['push_notifications'] as bool? ?? true,
      emailNotifications: json['email_notifications'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'warranty_alerts': warrantyAlerts,
      'tax_reminders': taxReminders,
      'ai_insights': aiInsights,
      'push_notifications': pushNotifications,
      'email_notifications': emailNotifications,
    };
  }

  NotificationSettings copyWith({
    bool? warrantyAlerts,
    bool? taxReminders,
    bool? aiInsights,
    bool? pushNotifications,
    bool? emailNotifications,
  }) {
    return NotificationSettings(
      warrantyAlerts: warrantyAlerts ?? this.warrantyAlerts,
      taxReminders: taxReminders ?? this.taxReminders,
      aiInsights: aiInsights ?? this.aiInsights,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      emailNotifications: emailNotifications ?? this.emailNotifications,
    );
  }
}

/// OCR Preferences Model
class OCRPreferences {
  final bool autoCategorize;
  final bool extractMerchant;
  final double confidenceThreshold;
  final bool autoSave;
  final bool reviewBeforeSave;

  OCRPreferences({
    this.autoCategorize = true,
    this.extractMerchant = true,
    this.confidenceThreshold = 0.7,
    this.autoSave = false,
    this.reviewBeforeSave = true,
  });

  factory OCRPreferences.fromJson(Map<String, dynamic> json) {
    return OCRPreferences(
      autoCategorize: json['auto_categorize'] as bool? ?? true,
      extractMerchant: json['extract_merchant'] as bool? ?? true,
      confidenceThreshold: (json['confidence_threshold'] as num?)?.toDouble() ?? 0.7,
      autoSave: json['auto_save'] as bool? ?? false,
      reviewBeforeSave: json['review_before_save'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'auto_categorize': autoCategorize,
      'extract_merchant': extractMerchant,
      'confidence_threshold': confidenceThreshold,
      'auto_save': autoSave,
      'review_before_save': reviewBeforeSave,
    };
  }

  OCRPreferences copyWith({
    bool? autoCategorize,
    bool? extractMerchant,
    double? confidenceThreshold,
    bool? autoSave,
    bool? reviewBeforeSave,
  }) {
    return OCRPreferences(
      autoCategorize: autoCategorize ?? this.autoCategorize,
      extractMerchant: extractMerchant ?? this.extractMerchant,
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
      autoSave: autoSave ?? this.autoSave,
      reviewBeforeSave: reviewBeforeSave ?? this.reviewBeforeSave,
    );
  }
}