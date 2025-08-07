import 'package:flutter/material.dart';
import 'package:get/get.dart';

// Controllers
import '../../controllers/auth_controller.dart';

// Config
import '../../config/app_config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authController = Get.find<AuthController>();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    bool success;
    
    if (_isSignUp) {
      success = await _authController.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim().isNotEmpty 
            ? _nameController.text.trim() 
            : null,
        phone: _phoneController.text.trim().isNotEmpty 
            ? _phoneController.text.trim() 
            : null,
      );
    } else {
      success = await _authController.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }

    if (success && !_isSignUp) {
      Get.offAllNamed('/home');
    }
  }

  Future<void> _handleForgotPassword() async {
    if (_emailController.text.trim().isEmpty) {
      Get.snackbar(
        'Email Required',
        'Please enter your email address first',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    await _authController.resetPassword(_emailController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                
                // App Logo and Title
                _buildHeader(),
                
                const SizedBox(height: 48),
                
                // Form Fields
                _buildFormFields(),
                
                const SizedBox(height: 32),
                
                // Submit Button
                _buildSubmitButton(),
                
                const SizedBox(height: 16),
                
                // Forgot Password (only for sign in)
                if (!_isSignUp) _buildForgotPassword(),
                
                const SizedBox(height: 32),
                
                // Toggle Sign Up/Sign In
                _buildToggleAuth(),
                
                const SizedBox(height: 32),
                
                // Features Preview
                _buildFeaturesPreview(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.receipt_long,
            size: 40,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          AppConfig.appName,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isSignUp ? 'Create your account' : 'Welcome back',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        // Full Name (Sign Up only)
        if (_isSignUp) ...[
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              prefixIcon: Icon(Icons.person),
            ),
            textInputAction: TextInputAction.next,
            validator: _isSignUp ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your full name';
              }
              return null;
            } : null,
          ),
          const SizedBox(height: 16),
        ],
        
        // Phone (Sign Up only)
        if (_isSignUp) ...[
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone Number (Optional)',
              prefixIcon: Icon(Icons.phone),
            ),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
        ],
        
        // Email
        TextFormField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'Email Address',
            prefixIcon: Icon(Icons.email),
          ),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your email address';
            }
            if (!_authController.isValidEmail(value.trim())) {
              return 'Please enter a valid email address';
            }
            return null;
          },
        ),
        
        const SizedBox(height: 16),
        
        // Password
        TextFormField(
          controller: _passwordController,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _handleSubmit(),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your password';
            }
            if (_isSignUp && !_authController.isValidPassword(value)) {
              return 'Password must be at least 8 characters with uppercase, lowercase, and number';
            }
            return null;
          },
        ),
        
        // Password Strength Indicator (Sign Up only)
        if (_isSignUp) ...[
          const SizedBox(height: 8),
          Obx(() {
            final password = _passwordController.text;
            final strength = _authController.getPasswordStrength(password);
            Color strengthColor = Colors.red;
            if (strength == 'Strong') strengthColor = Colors.green;
            else if (strength == 'Medium') strengthColor = Colors.orange;
            
            return Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Password Strength: $strength',
                style: TextStyle(
                  color: strengthColor,
                  fontSize: 12,
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildSubmitButton() {
    return Obx(() {
      return ElevatedButton(
        onPressed: _authController.isLoading ? null : _handleSubmit,
        child: _authController.isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(_isSignUp ? 'Create Account' : 'Sign In'),
      );
    });
  }

  Widget _buildForgotPassword() {
    return TextButton(
      onPressed: _handleForgotPassword,
      child: const Text('Forgot Password?'),
    );
  }

  Widget _buildToggleAuth() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(_isSignUp 
            ? 'Already have an account? ' 
            : 'Don\'t have an account? '),
        TextButton(
          onPressed: () {
            setState(() {
              _isSignUp = !_isSignUp;
              // Clear form when switching
              _formKey.currentState?.reset();
            });
          },
          child: Text(_isSignUp ? 'Sign In' : 'Sign Up'),
        ),
      ],
    );
  }

  Widget _buildFeaturesPreview() {
    return Column(
      children: [
        Text(
          'Features',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildFeatureChip(Icons.camera_alt, 'OCR Scanning'),
            _buildFeatureChip(Icons.inventory, 'Warranty Tracking'),
            _buildFeatureChip(Icons.currency_exchange, 'Multi-Currency'),
            _buildFeatureChip(Icons.analytics, 'Tax Management'),
            _buildFeatureChip(Icons.smart_toy, 'AI Insights'),
            _buildFeatureChip(Icons.cloud_sync, 'Cloud Sync'),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: Theme.of(context).colorScheme.onPrimaryContainer,
        fontSize: 12,
      ),
    );
  }
}