import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

/// Supabase Service - Central service for all Supabase operations
class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._internal();
  
  SupabaseService._internal();
  
  /// Supabase client instance
  SupabaseClient get client => Supabase.instance.client;
  
  /// Current user
  User? get currentUser => client.auth.currentUser;
  
  /// Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  /// Initialize Supabase
  static Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
        debug: AppConfig.isDebug,
      );
      
      if (kDebugMode) {
        print('🚀 Supabase initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing Supabase: $e');
      }
      rethrow;
    }
  }

  /// Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await client.auth.signUp(
        email: email,
        password: password,
        data: metadata,
      );
      
      if (kDebugMode) {
        print('✅ User signed up: ${response.user?.email}');
      }
      
      return response;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Sign up error: $e');
      }
      rethrow;
    }
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (kDebugMode) {
        print('✅ User signed in: ${response.user?.email}');
      }
      
      return response;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Sign in error: $e');
      }
      rethrow;
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      await client.auth.signOut();
      
      if (kDebugMode) {
        print('✅ User signed out');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Sign out error: $e');
      }
      rethrow;
    }
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    try {
      await client.auth.resetPasswordForEmail(email);
      
      if (kDebugMode) {
        print('✅ Password reset email sent to: $email');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Password reset error: $e');
      }
      rethrow;
    }
  }

  /// Update user password
  Future<UserResponse> updatePassword(String newPassword) async {
    try {
      final response = await client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      
      if (kDebugMode) {
        print('✅ Password updated successfully');
      }
      
      return response;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Password update error: $e');
      }
      rethrow;
    }
  }

  /// Get user profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      if (!isAuthenticated) return null;
      
      final response = await client
          .from('user_profiles')
          .select()
          .eq('id', currentUser!.id)
          .single();
      
      return response;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Get user profile error: $e');
      }
      return null;
    }
  }

  /// Create or update user profile
  Future<Map<String, dynamic>?> upsertUserProfile(
    Map<String, dynamic> profileData,
  ) async {
    try {
      if (!isAuthenticated) return null;
      
      final data = {
        ...profileData,
        'id': currentUser!.id,
        'email': currentUser!.email,
      };
      
      final response = await client
          .from('user_profiles')
          .upsert(data)
          .select()
          .single();
      
      if (kDebugMode) {
        print('✅ User profile updated');
      }
      
      return response;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Update user profile error: $e');
      }
      rethrow;
    }
  }

  /// Upload file to Supabase Storage
  Future<String?> uploadFile({
    required String bucket,
    required String filePath,
    required List<int> fileBytes,
    Map<String, String>? metadata,
  }) async {
    try {
      final response = await client.storage
          .from(bucket)
          .uploadBinary(filePath, fileBytes, fileOptions: FileOptions(
            upsert: true,
            contentType: metadata?['contentType'],
          ));
      
      if (response.isEmpty) {
        throw Exception('Upload failed: No response from storage');
      }
      
      // Get public URL
      final publicUrl = client.storage
          .from(bucket)
          .getPublicUrl(filePath);
      
      if (kDebugMode) {
        print('✅ File uploaded successfully: $publicUrl');
      }
      
      return publicUrl;
    } catch (e) {
      if (kDebugMode) {
        print('❌ File upload error: $e');
      }
      rethrow;
    }
  }

  /// Delete file from Supabase Storage
  Future<void> deleteFile({
    required String bucket,
    required String filePath,
  }) async {
    try {
      await client.storage
          .from(bucket)
          .remove([filePath]);
      
      if (kDebugMode) {
        print('✅ File deleted successfully: $filePath');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ File delete error: $e');
      }
      rethrow;
    }
  }

  /// Listen to auth state changes
  Stream<AuthState> get authStateStream => client.auth.onAuthStateChange;

  /// Execute raw SQL query (for admin operations)
  Future<List<Map<String, dynamic>>> executeQuery(String query) async {
    try {
      final response = await client.rpc('execute_sql', params: {'query': query});
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Query execution error: $e');
      }
      rethrow;
    }
  }

  /// Get real-time subscription for a table
  RealtimeChannel subscribeToTable({
    required String table,
    String? filter,
    required void Function(PostgresChangePayload) callback,
  }) {
    return client
        .channel('table-$table')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          filter: filter != null ? PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: filter.split('=')[0],
            value: filter.split('=')[1],
          ) : null,
          callback: callback,
        )
        .subscribe();
  }

  /// Dispose resources
  void dispose() {
    // Clean up any subscriptions or resources
  }
}