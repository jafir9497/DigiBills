import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/warranty.dart';
import '../services/supabase_service.dart';

/// Warranty Service for managing warranties and alerts
class WarrantyService {
  static WarrantyService? _instance;
  static WarrantyService get instance => _instance ??= WarrantyService._internal();
  
  WarrantyService._internal();

  final _supabaseService = SupabaseService.instance;
  late SharedPreferences _prefs;
  late FlutterLocalNotificationsPlugin _notificationsPlugin;

  /// Initialize warranty service
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _initializeNotifications();
      
      if (kDebugMode) {
        print('🛡️ Warranty Service initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing Warranty Service: $e');
      }
      rethrow;
    }
  }

  /// Initialize local notifications
  Future<void> _initializeNotifications() async {
    _notificationsPlugin = FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(initSettings);

    // Request permissions for notifications
    await _requestNotificationPermissions();
  }

  /// Request notification permissions
  Future<void> _requestNotificationPermissions() async {
    final android = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (android != null) {
      await android.requestNotificationsPermission();
    }

    final iOS = _notificationsPlugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    
    if (iOS != null) {
      await iOS.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  /// Create or update warranty
  Future<Warranty> saveWarranty(Warranty warranty) async {
    try {
      final warrantyData = warranty.toJson();
      
      final response = await _supabaseService.client
          .from('warranties')
          .upsert(warrantyData)
          .select()
          .single();
      
      final savedWarranty = Warranty.fromJson(response);
      
      // Schedule alerts for this warranty
      await _scheduleWarrantyAlerts(savedWarranty);
      
      if (kDebugMode) {
        print('✅ Warranty saved: ${warranty.productName}');
      }
      
      return savedWarranty;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving warranty: $e');
      }
      rethrow;
    }
  }

  /// Get user's warranties
  Future<List<Warranty>> getUserWarranties({
    bool activeOnly = false,
    String? category,
    WarrantyStatus? status,
  }) async {
    try {
      var query = _supabaseService.client
          .from('warranties')
          .select()
          .eq('user_id', _supabaseService.currentUser!.id)
          .order('warranty_end_date');

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      if (category != null) {
        query = query.eq('category', category);
      }

      final response = await query;
      
      final warranties = (response as List)
          .map((item) => Warranty.fromJson(item as Map<String, dynamic>))
          .toList();

      // Filter by status if specified
      if (status != null) {
        return warranties.where((w) => w.status == status).toList();
      }

      return warranties;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting user warranties: $e');
      }
      rethrow;
    }
  }

  /// Get warranty by ID
  Future<Warranty?> getWarrantyById(String warrantyId) async {
    try {
      final response = await _supabaseService.client
          .from('warranties')
          .select()
          .eq('id', warrantyId)
          .single();
      
      return Warranty.fromJson(response);
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting warranty: $e');
      }
      return null;
    }
  }

  /// Delete warranty
  Future<void> deleteWarranty(String warrantyId) async {
    try {
      await _supabaseService.client
          .from('warranties')
          .delete()
          .eq('id', warrantyId);
      
      // Cancel scheduled alerts
      await _cancelWarrantyAlerts(warrantyId);
      
      if (kDebugMode) {
        print('✅ Warranty deleted: $warrantyId');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting warranty: $e');
      }
      rethrow;
    }
  }

  /// Get warranties expiring soon
  Future<List<Warranty>> getExpiringSoonWarranties({int days = 30}) async {
    try {
      final cutoffDate = DateTime.now().add(Duration(days: days));
      
      final response = await _supabaseService.client
          .from('warranties')
          .select()
          .eq('user_id', _supabaseService.currentUser!.id)
          .eq('is_active', true)
          .lte('warranty_end_date', cutoffDate.toIso8601String().split('T')[0])
          .gte('warranty_end_date', DateTime.now().toIso8601String().split('T')[0])
          .order('warranty_end_date');
      
      return (response as List)
          .map((item) => Warranty.fromJson(item as Map<String, dynamic>))
          .toList();
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting expiring warranties: $e');
      }
      rethrow;
    }
  }

  /// Get expired warranties
  Future<List<Warranty>> getExpiredWarranties() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      final response = await _supabaseService.client
          .from('warranties')
          .select()
          .eq('user_id', _supabaseService.currentUser!.id)
          .lt('warranty_end_date', today)
          .order('warranty_end_date', ascending: false);
      
      return (response as List)
          .map((item) => Warranty.fromJson(item as Map<String, dynamic>))
          .toList();
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting expired warranties: $e');
      }
      rethrow;
    }
  }

  /// Schedule warranty alerts
  Future<void> _scheduleWarrantyAlerts(Warranty warranty) async {
    if (!warranty.isActive || warranty.isExpired) return;

    try {
      // Cancel existing alerts for this warranty
      await _cancelWarrantyAlerts(warranty.id);
      
      for (final alertDay in warranty.alertDaysBefore) {
        final alertDate = warranty.warrantyEndDate.subtract(Duration(days: alertDay));
        
        // Only schedule future alerts
        if (alertDate.isAfter(DateTime.now())) {
          await _scheduleNotification(
            id: '${warranty.id}_$alertDay'.hashCode,
            title: 'Warranty Expiring Soon',
            body: '${warranty.productName} warranty expires in $alertDay ${alertDay == 1 ? 'day' : 'days'}',
            scheduledDate: alertDate,
            payload: json.encode({
              'type': 'warranty_alert',
              'warrantyId': warranty.id,
              'productName': warranty.productName,
              'daysLeft': alertDay,
            }),
          );
        }
      }
      
      if (kDebugMode) {
        print('✅ Scheduled ${warranty.alertDaysBefore.length} alerts for ${warranty.productName}');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error scheduling warranty alerts: $e');
      }
    }
  }

  /// Cancel warranty alerts
  Future<void> _cancelWarrantyAlerts(String warrantyId) async {
    try {
      // Cancel notifications for all possible alert days
      const possibleAlertDays = [1, 3, 7, 14, 30, 60, 90];
      
      for (final alertDay in possibleAlertDays) {
        final notificationId = '${warrantyId}_$alertDay'.hashCode;
        await _notificationsPlugin.cancel(notificationId);
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error cancelling warranty alerts: $e');
      }
    }
  }

  /// Schedule a notification
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'warranty_alerts',
        'Warranty Alerts',
        channelDescription: 'Notifications for warranty expiry alerts',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        categoryIdentifier: 'warranty_alert',
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error scheduling notification: $e');
      }
    }
  }

  /// Update warranty claim status
  Future<Warranty> updateWarrantyClaim({
    required String warrantyId,
    required ClaimStatus claimStatus,
    WarrantyClaim? claimDetails,
  }) async {
    try {
      final updateData = {
        'claim_status': claimStatus.name,
        'claim_details': claimDetails?.toJson(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      final response = await _supabaseService.client
          .from('warranties')
          .update(updateData)
          .eq('id', warrantyId)
          .select()
          .single();
      
      final updatedWarranty = Warranty.fromJson(response);
      
      if (kDebugMode) {
        print('✅ Warranty claim updated: $warrantyId');
      }
      
      return updatedWarranty;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating warranty claim: $e');
      }
      rethrow;
    }
  }

  /// Get warranty statistics
  Future<WarrantyStatistics> getWarrantyStatistics() async {
    try {
      final warranties = await getUserWarranties();
      
      final activeCount = warranties.where((w) => w.status == WarrantyStatus.active).length;
      final expiringSoonCount = warranties.where((w) => w.status == WarrantyStatus.expiringSoon).length;
      final expiredCount = warranties.where((w) => w.status == WarrantyStatus.expired).length;
      
      final totalValue = warranties
          .where((w) => w.purchasePrice != null)
          .fold<double>(0.0, (sum, w) => sum + w.purchasePrice!);
      
      final categoryBreakdown = <String, int>{};
      for (final warranty in warranties) {
        final category = warranty.category ?? 'Other';
        categoryBreakdown[category] = (categoryBreakdown[category] ?? 0) + 1;
      }
      
      return WarrantyStatistics(
        totalWarranties: warranties.length,
        activeWarranties: activeCount,
        expiringSoonWarranties: expiringSoonCount,
        expiredWarranties: expiredCount,
        totalProtectedValue: totalValue,
        categoryBreakdown: categoryBreakdown,
      );
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting warranty statistics: $e');
      }
      rethrow;
    }
  }

  /// Check and send due alerts
  Future<void> checkAndSendDueAlerts() async {
    try {
      final warranties = await getUserWarranties(activeOnly: true);
      
      for (final warranty in warranties) {
        if (warranty.shouldSendAlert()) {
          await _sendWarrantyAlert(warranty);
          
          // Update last alert sent timestamp
          await _supabaseService.client
              .from('warranties')
              .update({
                'last_alert_sent': DateTime.now().toIso8601String(),
              })
              .eq('id', warranty.id);
        }
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking due alerts: $e');
      }
    }
  }

  /// Send warranty alert
  Future<void> _sendWarrantyAlert(Warranty warranty) async {
    try {
      final daysLeft = warranty.daysUntilExpiry;
      
      await _notificationsPlugin.show(
        warranty.id.hashCode,
        'Warranty Expiring Soon',
        '${warranty.productName} warranty expires in $daysLeft ${daysLeft == 1 ? 'day' : 'days'}',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'warranty_alerts',
            'Warranty Alerts',
            channelDescription: 'Notifications for warranty expiry alerts',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            categoryIdentifier: 'warranty_alert',
          ),
        ),
        payload: json.encode({
          'type': 'warranty_alert',
          'warrantyId': warranty.id,
          'productName': warranty.productName,
          'daysLeft': daysLeft,
        }),
      );
      
      if (kDebugMode) {
        print('✅ Sent warranty alert for ${warranty.productName}');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending warranty alert: $e');
      }
    }
  }

  /// Get popular product categories
  List<String> getPopularCategories() {
    return [
      'Electronics',
      'Home Appliances',
      'Automotive',
      'Furniture',
      'Clothing',
      'Sports Equipment',
      'Tools',
      'Jewelry',
      'Books',
      'Other',
    ];
  }

  /// Calculate warranty end date
  DateTime calculateWarrantyEndDate(DateTime startDate, int months) {
    return DateTime(
      startDate.year,
      startDate.month + months,
      startDate.day,
    );
  }

  /// Parse warranty period from text
  int? parseWarrantyPeriod(String text) {
    final patterns = [
      RegExp(r'(\d+)\s*year[s]?', caseSensitive: false),
      RegExp(r'(\d+)\s*month[s]?', caseSensitive: false),
      RegExp(r'(\d+)\s*yr[s]?', caseSensitive: false),
      RegExp(r'(\d+)\s*mo[s]?', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final number = int.tryParse(match.group(1)!);
        if (number != null) {
          // Convert years to months
          if (text.toLowerCase().contains('year') || text.toLowerCase().contains('yr')) {
            return number * 12;
          }
          return number;
        }
      }
    }

    return null;
  }

  /// Dispose resources
  void dispose() {
    // Clean up resources
  }
}

/// Warranty Statistics Model
class WarrantyStatistics {
  final int totalWarranties;
  final int activeWarranties;
  final int expiringSoonWarranties;
  final int expiredWarranties;
  final double totalProtectedValue;
  final Map<String, int> categoryBreakdown;

  WarrantyStatistics({
    required this.totalWarranties,
    required this.activeWarranties,
    required this.expiringSoonWarranties,
    required this.expiredWarranties,
    required this.totalProtectedValue,
    required this.categoryBreakdown,
  });
}