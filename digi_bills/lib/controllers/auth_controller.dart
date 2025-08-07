import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/user_profile.dart';

/// Authentication Controller using GetX
class AuthController extends GetxController {
  static AuthController get instance => Get.find();
  
  final _supabaseService = SupabaseService.instance;
  
  // Reactive variables
  final Rx<User?> _user = Rx<User?>(null);
  final Rx<UserProfile?> _userProfile = Rx<UserProfile?>(null);
  final RxBool _isLoading = false.obs;
  final RxBool _isInitialized = false.obs;
  
  // Getters
  User? get user => _user.value;
  UserProfile? get userProfile => _userProfile.value;
  bool get isLoading => _isLoading.value;
  bool get isAuthenticated => user != null;
  bool get isInitialized => _isInitialized.value;
  
  @override
  void onInit() {
    super.onInit();
    _initAuthListener();
  }

  /// Initialize authentication state listener
  void _initAuthListener() {
    // Set initial user
    _user.value = _supabaseService.currentUser;
    
    // Listen to auth state changes
    _supabaseService.authStateStream.listen((AuthState state) async {
      _user.value = state.session?.user;
      
      if (_user.value != null) {
        await _loadUserProfile();
      } else {
        _userProfile.value = null;
      }
      
      if (!_isInitialized.value) {
        _isInitialized.value = true;
      }
    });
    
    // Load initial profile if user is already signed in
    if (_user.value != null) {
      _loadUserProfile().then((_) {
        _isInitialized.value = true;
      });
    } else {
      _isInitialized.value = true;
    }
  }

  /// Sign up with email and password
  Future<bool> signUp({
    required String email,
    required String password,
    String? fullName,
    String? phone,
  }) async {
    try {
      _isLoading.value = true;
      
      final response = await _supabaseService.signUp(
        email: email,
        password: password,
        metadata: {
          if (fullName != null) 'full_name': fullName,
          if (phone != null) 'phone': phone,
        },
      );
      
      if (response.user != null) {
        // Create initial user profile
        await _createInitialProfile(
          userId: response.user!.id,
          email: email,
          fullName: fullName,
          phone: phone,
        );
        
        Get.snackbar(
          'Success',
          'Account created successfully! Please check your email to verify your account.',
          snackPosition: SnackPosition.BOTTOM,
        );
        
        return true;
      }
      
      return false;
    } catch (e) {
      _handleError('Sign Up Failed', e);
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  /// Sign in with email and password
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading.value = true;
      
      final response = await _supabaseService.signIn(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        Get.snackbar(
          'Success',
          'Welcome back!',
          snackPosition: SnackPosition.BOTTOM,
        );
        return true;
      }
      
      return false;
    } catch (e) {
      _handleError('Sign In Failed', e);
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      _isLoading.value = true;
      await _supabaseService.signOut();
      
      Get.snackbar(
        'Success',
        'Signed out successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      _handleError('Sign Out Failed', e);
    } finally {
      _isLoading.value = false;
    }
  }

  /// Reset password
  Future<bool> resetPassword(String email) async {
    try {
      _isLoading.value = true;
      
      await _supabaseService.resetPassword(email);
      
      Get.snackbar(
        'Success',
        'Password reset email sent to $email',
        snackPosition: SnackPosition.BOTTOM,
      );
      
      return true;
    } catch (e) {
      _handleError('Password Reset Failed', e);
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  /// Update user password
  Future<bool> updatePassword(String newPassword) async {
    try {
      _isLoading.value = true;
      
      await _supabaseService.updatePassword(newPassword);
      
      Get.snackbar(
        'Success',
        'Password updated successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
      
      return true;
    } catch (e) {
      _handleError('Password Update Failed', e);
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  /// Update user profile
  Future<bool> updateProfile(UserProfile updatedProfile) async {
    try {
      _isLoading.value = true;
      
      final profileData = await _supabaseService.upsertUserProfile(
        updatedProfile.toJson(),
      );
      
      if (profileData != null) {
        _userProfile.value = UserProfile.fromJson(profileData);
        
        Get.snackbar(
          'Success',
          'Profile updated successfully',
          snackPosition: SnackPosition.BOTTOM,
        );
        
        return true;
      }
      
      return false;
    } catch (e) {
      _handleError('Profile Update Failed', e);
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  /// Load user profile from database
  Future<void> _loadUserProfile() async {
    try {
      final profileData = await _supabaseService.getUserProfile();
      
      if (profileData != null) {
        _userProfile.value = UserProfile.fromJson(profileData);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading user profile: $e');
      }
    }
  }

  /// Create initial user profile
  Future<void> _createInitialProfile({
    required String userId,
    required String email,
    String? fullName,
    String? phone,
  }) async {
    try {
      final initialProfile = UserProfile(
        id: userId,
        email: email,
        fullName: fullName,
        phone: phone,
        notificationSettings: NotificationSettings(),
        ocrPreferences: OCRPreferences(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await _supabaseService.upsertUserProfile(initialProfile.toJson());
    } catch (e) {
      if (kDebugMode) {
        print('Error creating initial profile: $e');
      }
    }
  }

  /// Handle authentication errors
  void _handleError(String title, dynamic error) {
    String message = 'An unexpected error occurred';
    
    if (error is AuthException) {
      message = error.message;
    } else if (error is PostgrestException) {
      message = error.message;
    } else {
      message = error.toString();
    }
    
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Get.theme.colorScheme.error,
      colorText: Get.theme.colorScheme.onError,
    );
    
    if (kDebugMode) {
      print('Auth Error: $title - $message');
    }
  }

  /// Validate email format
  bool isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email);
  }

  /// Validate password strength
  bool isValidPassword(String password) {
    // At least 8 characters, 1 uppercase, 1 lowercase, 1 number
    return RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[a-zA-Z\d@$!%*?&]{8,}$')
        .hasMatch(password);
  }

  /// Get password strength text
  String getPasswordStrength(String password) {
    if (password.length < 6) return 'Too Short';
    if (password.length < 8) return 'Weak';
    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(password)) {
      return 'Medium';
    }
    return 'Strong';
  }

  @override
  void onClose() {
    // Clean up resources
    super.onClose();
  }
}