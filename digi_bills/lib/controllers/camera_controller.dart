import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../services/ocr_service.dart';
import '../services/supabase_service.dart';

/// Camera Controller for receipt scanning
class CameraController extends GetxController {
  static CameraController get instance => Get.find();

  final _ocrService = OCRService.instance;
  final _supabaseService = SupabaseService.instance;
  final _imagePicker = ImagePicker();

  // Reactive variables
  final RxList<CameraDescription> _cameras = <CameraDescription>[].obs;
  final Rx<CameraDescription?> _selectedCamera = Rx<CameraDescription?>(null);
  final Rx<CameraController?> _cameraController = Rx<CameraController?>(null);
  final RxBool _isCameraInitialized = false.obs;
  final RxBool _isProcessing = false.obs;
  final RxBool _isFlashOn = false.obs;
  final Rx<String?> _capturedImagePath = Rx<String?>(null);
  final Rx<ReceiptOCRResult?> _ocrResult = Rx<ReceiptOCRResult?>(null);

  // Getters
  List<CameraDescription> get cameras => _cameras;
  CameraDescription? get selectedCamera => _selectedCamera.value;
  CameraController? get cameraController => _cameraController.value;
  bool get isCameraInitialized => _isCameraInitialized.value;
  bool get isProcessing => _isProcessing.value;
  bool get isFlashOn => _isFlashOn.value;
  String? get capturedImagePath => _capturedImagePath.value;
  ReceiptOCRResult? get ocrResult => _ocrResult.value;

  @override
  void onInit() {
    super.onInit();
    _initializeCameras();
  }

  /// Initialize available cameras
  Future<void> _initializeCameras() async {
    try {
      final availableCameras = await availableCameras();
      _cameras.assignAll(availableCameras);
      
      // Select back camera by default
      if (availableCameras.isNotEmpty) {
        _selectedCamera.value = availableCameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => availableCameras.first,
        );
      }
      
      if (kDebugMode) {
        print('📸 Found ${availableCameras.length} cameras');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing cameras: $e');
      }
    }
  }

  /// Initialize camera controller
  Future<bool> initializeCamera() async {
    if (_selectedCamera.value == null) return false;

    try {
      _isProcessing.value = true;
      
      // Dispose existing controller
      await _disposeCameraController();
      
      // Create new controller
      _cameraController.value = CameraController(
        _selectedCamera.value!,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      
      // Initialize controller
      await _cameraController.value!.initialize();
      
      _isCameraInitialized.value = true;
      
      if (kDebugMode) {
        print('✅ Camera initialized successfully');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing camera: $e');
      }
      return false;
    } finally {
      _isProcessing.value = false;
    }
  }

  /// Switch between front and back camera
  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;
    
    try {
      final currentDirection = _selectedCamera.value?.lensDirection;
      final newCamera = _cameras.firstWhere(
        (camera) => camera.lensDirection != currentDirection,
        orElse: () => _cameras.first,
      );
      
      _selectedCamera.value = newCamera;
      await initializeCamera();
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error switching camera: $e');
      }
    }
  }

  /// Toggle flash
  Future<void> toggleFlash() async {
    if (_cameraController.value == null || !_isCameraInitialized.value) return;
    
    try {
      final newFlashMode = _isFlashOn.value ? FlashMode.off : FlashMode.torch;
      await _cameraController.value!.setFlashMode(newFlashMode);
      _isFlashOn.value = !_isFlashOn.value;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error toggling flash: $e');
      }
    }
  }

  /// Capture photo from camera
  Future<String?> capturePhoto() async {
    if (_cameraController.value == null || !_isCameraInitialized.value) {
      return null;
    }

    try {
      _isProcessing.value = true;
      
      // Turn off flash if it was on
      if (_isFlashOn.value) {
        await _cameraController.value!.setFlashMode(FlashMode.off);
      }
      
      // Capture image
      final XFile image = await _cameraController.value!.takePicture();
      
      _capturedImagePath.value = image.path;
      
      if (kDebugMode) {
        print('📸 Photo captured: ${image.path}');
      }
      
      return image.path;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error capturing photo: $e');
      }
      
      Get.snackbar(
        'Camera Error',
        'Failed to capture photo. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
      
      return null;
    } finally {
      _isProcessing.value = false;
    }
  }

  /// Pick image from gallery
  Future<String?> pickImageFromGallery() async {
    try {
      _isProcessing.value = true;
      
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      
      if (image != null) {
        _capturedImagePath.value = image.path;
        
        if (kDebugMode) {
          print('🖼️ Image selected from gallery: ${image.path}');
        }
        
        return image.path;
      }
      
      return null;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error picking image from gallery: $e');
      }
      
      Get.snackbar(
        'Gallery Error',
        'Failed to pick image from gallery.',
        snackPosition: SnackPosition.BOTTOM,
      );
      
      return null;
    } finally {
      _isProcessing.value = false;
    }
  }

  /// Process captured image with OCR
  Future<ReceiptOCRResult?> processReceiptImage(String imagePath) async {
    try {
      _isProcessing.value = true;
      
      // Process image with OCR service
      final result = await _ocrService.processReceiptImage(imagePath);
      
      _ocrResult.value = result;
      
      if (kDebugMode) {
        print('🔍 OCR processing complete. Confidence: ${result.confidence}');
        print('📄 Extracted text: ${result.rawText}');
      }
      
      // Show processing result to user
      if (result.confidence >= 0.7) {
        Get.snackbar(
          'OCR Success',
          'Receipt processed successfully! Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'OCR Warning',
          'Receipt processed with low confidence: ${(result.confidence * 100).toStringAsFixed(1)}%',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
      
      return result;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error processing receipt image: $e');
      }
      
      Get.snackbar(
        'OCR Error',
        'Failed to process receipt. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      
      return null;
    } finally {
      _isProcessing.value = false;
    }
  }

  /// Upload image to Supabase Storage
  Future<String?> uploadReceiptImage(String imagePath) async {
    try {
      _isProcessing.value = true;
      
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      
      // Generate unique filename
      final fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = 'receipts/${_supabaseService.currentUser?.id}/$fileName';
      
      // Upload to Supabase Storage
      final publicUrl = await _supabaseService.uploadFile(
        bucket: 'receipts',
        filePath: filePath,
        fileBytes: bytes,
        metadata: {
          'contentType': 'image/jpeg',
        },
      );
      
      if (kDebugMode) {
        print('☁️ Image uploaded successfully: $publicUrl');
      }
      
      return publicUrl;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error uploading image: $e');
      }
      
      Get.snackbar(
        'Upload Error',
        'Failed to upload image. Please check your connection.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      
      return null;
    } finally {
      _isProcessing.value = false;
    }
  }

  /// Clear current capture and OCR result
  void clearCapture() {
    _capturedImagePath.value = null;
    _ocrResult.value = null;
    
    if (kDebugMode) {
      print('🗑️ Capture cleared');
    }
  }

  /// Reset camera state
  void resetCamera() {
    clearCapture();
    _isFlashOn.value = false;
  }

  /// Dispose camera controller
  Future<void> _disposeCameraController() async {
    try {
      if (_cameraController.value != null) {
        await _cameraController.value!.dispose();
        _cameraController.value = null;
      }
      _isCameraInitialized.value = false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error disposing camera controller: $e');
      }
    }
  }

  @override
  void onClose() {
    _disposeCameraController();
    super.onClose();
  }
}